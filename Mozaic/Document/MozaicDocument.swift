import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DocumentError: Error, Equatable {
	case notAPackage
	case missingManifest
	case unsupportedVersion(Int)
}

/// Everything needed to write a document, mirrored out of the live model and
/// handed to the background writer. `Sendable` because both
/// `snapshot(contentType:)` and `fileWrapper(snapshot:configuration:)` are
/// `nonisolated`.
struct BoardSnapshot: Sendable {
	var board: Board
	var images: [UUID: StoredImage]
}

/// A `.mozaic` package: a manifest plus one file per image, in the image's
/// own format.
///
/// `ReferenceFileDocument` rather than `FileDocument` because `ProjectModel`
/// is an `@Observable` class — the value-type `FileDocument` would force it to
/// become a struct — and because it supplies the `UndoManager`.
///
/// The class is `@MainActor` for the sake of the views that touch `model`, but
/// every `ReferenceFileDocument` requirement is `nonisolated`: the protocol
/// carries no actor annotation, and AppKit really does call
/// `snapshot(contentType:)` off the main actor. That is why the conformance
/// needs no `@preconcurrency` — there is no isolation mismatch left to
/// suppress, and so no dynamic executor check to trap.
@MainActor
final class MozaicDocument: ReferenceFileDocument {
	typealias Snapshot = BoardSnapshot

	nonisolated static var readableContentTypes: [UTType] { [.mozaicBoard] }

	nonisolated static let manifestName = "manifest.json"
	nonisolated static let imagesDirectoryName = "images"

	/// Every row carries exactly this many slots. The board views index
	/// `slots[0...3]` directly, so this is a structural invariant of the
	/// format, enforced on read.
	nonisolated static let slotsPerRow = 4

	let model: ProjectModel

	/// What `snapshot(contentType:)` returns. The document owns it; the model
	/// keeps it current. See `BoardMirror`.
	nonisolated let mirror: BoardMirror

	/// `nonisolated` for the same reason as `init(configuration:)`:
	/// `DocumentGroup(newDocument:editor:)` takes a plain, nonisolated
	/// closure, so a main-actor initializer here is another isolation
	/// mismatch waiting to become a dynamic executor check. Nothing in it
	/// needs the main actor — `BoardMirror.init` and `ProjectModel.init` are
	/// both nonisolated.
	nonisolated init() {
		let mirror = BoardMirror()
		self.mirror = mirror
		self.model = ProjectModel(mirror: mirror)
	}

	/// `nonisolated`: SwiftUI's iOS document path is `UIDocument`-backed and
	/// loads content off the main queue, and nothing in the SDK contracts
	/// this initializer to the main actor. Leaving it isolated would put a
	/// dynamic isolation check -- a crash on opening a file -- in the read
	/// path. Nothing here needs the main actor: `read` is nonisolated,
	/// `Board` is a nonisolated value type, and `ProjectModel`'s initializer
	/// is nonisolated too.
	nonisolated init(configuration: ReadConfiguration) throws {
		let snapshot = try Self.read(configuration.file)
		let mirror = BoardMirror(board: snapshot.board, images: snapshot.images)
		self.mirror = mirror
		self.model = ProjectModel(board: snapshot.board,
								  storedImages: snapshot.images,
								  mirror: mirror)
	}

	/// `nonisolated`: AppKit calls this from `-[NSDocument writeToURL:...]`,
	/// which runs on `com.apple.root.default-qos`, not the main actor. A
	/// main-actor-isolated version compiles only behind `@preconcurrency`, and
	/// then traps in `_checkExpectedExecutor` the first time the user presses
	/// Cmd+S. Reading the mirror instead makes the isolation honest: no hop,
	/// no `assumeIsolated`, no blocking, and no race — the mirror is under a
	/// `Mutex` and the main thread stays live throughout the save.
	nonisolated func snapshot(contentType: UTType) throws -> BoardSnapshot {
		mirror.snapshot
	}

	nonisolated func fileWrapper(snapshot: BoardSnapshot,
								 configuration: WriteConfiguration) throws -> FileWrapper {
		try Self.makeFileWrapper(snapshot: snapshot, existing: configuration.existingFile)
	}

	// MARK: Writing

	/// Builds the package. Static so it can be tested without a document.
	///
	/// Only images reachable from the board are written, which is how garbage
	/// collection happens — an unreferenced image is dropped by simply not
	/// being written, with no reference counting.
	nonisolated static func makeFileWrapper(snapshot: BoardSnapshot,
											existing: FileWrapper?) throws -> FileWrapper {
		let referenced = snapshot.board.referencedImageIDs
		let existingImages = existing?.fileWrappers?[imagesDirectoryName]?.fileWrappers ?? [:]
		let existingMeta = previousImageMeta(in: existing)

		var imageChildren: [String: FileWrapper] = [:]
		var metadata: [StoredImageMeta] = []

		for id in referenced.sorted(by: { $0.uuidString < $1.uuidString }) {
			guard let stored = snapshot.images[id] else { continue }
			let ext = stored.contentType.preferredFilenameExtension ?? "dat"
			let name = "\(id.uuidString).\(ext)"

			// Image bytes are immutable per ID under ordinary edits — any edit
			// mints a new ID — so a matching filename ordinarily guarantees
			// matching contents, and that's what makes reuse safe and keeps
			// saves from rewriting unchanged images. "Reduce File Size" is
			// the one deliberate exception: it replaces bytes under an
			// existing ID, and it always shrinks the pixel dimensions when it
			// does (see `ImageStore.reduceFileSize()`). So reuse also
			// requires this ID's dimensions to match what the previous save
			// recorded for it. That check reads the small manifest.json
			// already sitting in `existing`, never the image bytes
			// themselves, so an unrelated unchanged image is still never
			// read back off disk just to confirm it is unchanged.
			let dimensionsMatchPreviousSave = existingMeta[id]?.pixelWidth == stored.pixelWidth
				&& existingMeta[id]?.pixelHeight == stored.pixelHeight
			if dimensionsMatchPreviousSave, let reusable = existingImages[name], reusable.isRegularFile {
				imageChildren[name] = reusable
			} else {
				imageChildren[name] = FileWrapper(regularFileWithContents: stored.data)
			}

			metadata.append(StoredImageMeta(id: id,
											contentType: stored.contentType.identifier,
											pixelWidth: stored.pixelWidth,
											pixelHeight: stored.pixelHeight))
		}

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let manifest = try encoder.encode(BoardFile(board: snapshot.board, images: metadata))

		return FileWrapper(directoryWithFileWrappers: [
			manifestName: FileWrapper(regularFileWithContents: manifest),
			imagesDirectoryName: FileWrapper(directoryWithFileWrappers: imageChildren),
		])
	}

	/// Decodes the previous save's manifest, if any, keyed by image ID.
	///
	/// Used only to detect whether a same-ID, same-filename image had its
	/// bytes replaced in place since the last save — see the dimension check
	/// in `makeFileWrapper` above. Never used to read image bytes. A missing
	/// or unparsable manifest (the first save, or a hand-edited package)
	/// yields an empty dictionary, which makes every reuse check fail closed:
	/// everything gets rewritten rather than risking a stale reuse.
	nonisolated private static func previousImageMeta(in existing: FileWrapper?) -> [UUID: StoredImageMeta] {
		guard let data = existing?.fileWrappers?[manifestName]?.regularFileContents,
			  let file = try? JSONDecoder().decode(BoardFile.self, from: data) else {
			return [:]
		}
		return Dictionary(uniqueKeysWithValues: file.images.map { ($0.id, $0) })
	}

	// MARK: Reading

	/// Reads a package. Tolerant of missing image files: a board that lost one
	/// image still opens with the rest.
	nonisolated static func read(_ wrapper: FileWrapper) throws -> BoardSnapshot {
		guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
			throw DocumentError.notAPackage
		}
		guard let manifestData = children[manifestName]?.regularFileContents else {
			throw DocumentError.missingManifest
		}

		let file: BoardFile
		do {
			file = try JSONDecoder().decode(BoardFile.self, from: manifestData)
		} catch {
			throw CocoaError(.fileReadCorruptFile)
		}
		guard file.formatVersion <= BoardFile.currentFormatVersion else {
			throw DocumentError.unsupportedVersion(file.formatVersion)
		}

		// A row's slot count is structural, not decorative: the views subscript
		// slots 0...3 without checking. A hand-edited or truncated manifest
		// that disagrees would crash on the first render, so refuse it here.
		guard file.board.rows.allSatisfy({ $0.slots.count == slotsPerRow }) else {
			throw CocoaError(.fileReadCorruptFile)
		}

		let imageFiles = children[imagesDirectoryName]?.fileWrappers ?? [:]
		var images: [UUID: StoredImage] = [:]

		for meta in file.images {
			guard let type = UTType(meta.contentType) else { continue }
			let ext = type.preferredFilenameExtension ?? "dat"
			guard let data = imageFiles["\(meta.id.uuidString).\(ext)"]?.regularFileContents else {
				continue  // absent or unreadable: slot renders a placeholder
			}
			images[meta.id] = StoredImage(data: data,
										  contentType: type,
										  pixelWidth: meta.pixelWidth,
										  pixelHeight: meta.pixelHeight)
		}

		return BoardSnapshot(board: file.board, images: images)
	}
}
