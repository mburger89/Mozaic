import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DocumentError: Error, Equatable {
	case notAPackage
	case missingManifest
	case unsupportedVersion(Int)
}

/// Everything needed to write a document, captured on the main actor and
/// handed to the background writer. `Sendable` because
/// `fileWrapper(snapshot:configuration:)` is `nonisolated`.
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
@MainActor
final class MozaicDocument: @preconcurrency ReferenceFileDocument {
	typealias Snapshot = BoardSnapshot

	nonisolated static var readableContentTypes: [UTType] { [.mozaicBoard] }

	nonisolated static let manifestName = "manifest.json"
	nonisolated static let imagesDirectoryName = "images"

	/// Every row carries exactly this many slots. The board views index
	/// `slots[0...3]` directly, so this is a structural invariant of the
	/// format, enforced on read.
	nonisolated static let slotsPerRow = 4

	var board: Board
	let images: ImageStore

	init() {
		self.board = Board()
		self.images = ImageStore()
	}

	/// `nonisolated`: SwiftUI's iOS document path is `UIDocument`-backed and
	/// loads content off the main queue, and nothing in the SDK contracts
	/// this initializer to the main actor. Leaving it isolated would put a
	/// dynamic isolation check -- a crash on opening a file -- in the read
	/// path. Nothing here needs the main actor: `read` is nonisolated,
	/// `Board` is a nonisolated value type, and `ImageStore`'s initializer is
	/// nonisolated too.
	nonisolated init(configuration: ReadConfiguration) throws {
		let snapshot = try Self.read(configuration.file)
		self.board = snapshot.board
		self.images = ImageStore(storedImages: snapshot.images)
	}

	func snapshot(contentType: UTType) throws -> BoardSnapshot {
		BoardSnapshot(board: board, images: images.storedImages)
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

		var imageChildren: [String: FileWrapper] = [:]
		var metadata: [StoredImageMeta] = []

		for id in referenced.sorted(by: { $0.uuidString < $1.uuidString }) {
			guard let stored = snapshot.images[id] else { continue }
			let ext = stored.contentType.preferredFilenameExtension ?? "dat"
			let name = "\(id.uuidString).\(ext)"

			// Image bytes are immutable per ID — any edit mints a new ID — so
			// a matching filename guarantees matching contents. That makes
			// reuse safe and keeps saves from rewriting unchanged images.
			if let reusable = existingImages[name], reusable.isRegularFile {
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
