import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct MozaicDocumentTests {
	private func makeImageData(width: Int = 20) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: 20, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: 20))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	private func snapshotWithOnePlacedImage() throws -> (BoardSnapshot, UUID) {
		let id = UUID()
		let stored = StoredImage(data: try makeImageData(), contentType: .png,
								 pixelWidth: 20, pixelHeight: 20)
		var board = Board()
		board.rows[0].slots[0] = id
		board.projectName = "Trip"
		return (BoardSnapshot(board: board, images: [id: stored]), id)
	}

	@Test func writesAPackageWithManifestAndImages() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		#expect(wrapper.isDirectory)
		let children = try #require(wrapper.fileWrappers)
		#expect(children["manifest.json"] != nil)

		let images = try #require(children["images"]?.fileWrappers)
		#expect(images["\(id.uuidString).png"] != nil)
	}

	@Test func roundTripsThroughAPackage() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let read = try MozaicDocument.read(wrapper)

		#expect(read.board.projectName == "Trip")
		#expect(read.board.rows[0].slots[0] == id)
		#expect(read.images[id]?.contentType == .png)
		#expect(read.images[id]?.data == snapshot.images[id]?.data)
	}

	@Test func unreferencedImagesAreNotWritten() throws {
		var (snapshot, _) = try snapshotWithOnePlacedImage()
		let orphan = UUID()
		snapshot.images[orphan] = StoredImage(data: try makeImageData(width: 30),
											  contentType: .png, pixelWidth: 30, pixelHeight: 20)

		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let images = try #require(wrapper.fileWrappers?["images"]?.fileWrappers)

		// Garbage collection: only IDs reachable from rows or tray are written.
		#expect(images["\(orphan.uuidString).png"] == nil)
		#expect(images.count == 1)
	}

	@Test func trayImagesAreWritten() throws {
		var (snapshot, _) = try snapshotWithOnePlacedImage()
		let trayID = UUID()
		snapshot.images[trayID] = StoredImage(data: try makeImageData(width: 30),
											  contentType: .png, pixelWidth: 30, pixelHeight: 20)
		snapshot.board.tray = [trayID]

		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let images = try #require(wrapper.fileWrappers?["images"]?.fileWrappers)
		#expect(images["\(trayID.uuidString).png"] != nil)
	}

	@Test func unchangedImagesAreReusedFromTheExistingPackage() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let first = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let originalChild = try #require(first.fileWrappers?["images"]?.fileWrappers?["\(id.uuidString).png"])

		// Save again with the board renamed but the image untouched.
		var changed = snapshot
		changed.board.projectName = "Renamed"
		let second = try MozaicDocument.makeFileWrapper(snapshot: changed, existing: first)
		let reusedChild = try #require(second.fileWrappers?["images"]?.fileWrappers?["\(id.uuidString).png"])

		// Same wrapper instance: the bytes were not rewritten.
		#expect(reusedChild === originalChild)
	}

	@Test func rejectsANewerFormatVersion() throws {
		let (snapshot, _) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		var file = try JSONDecoder().decode(
			BoardFile.self,
			from: #require(wrapper.fileWrappers?["manifest.json"]?.regularFileContents)
		)
		file.formatVersion = BoardFile.currentFormatVersion + 1

		let poisoned = FileWrapper(directoryWithFileWrappers: [
			"manifest.json": FileWrapper(regularFileWithContents: try JSONEncoder().encode(file)),
			"images": FileWrapper(directoryWithFileWrappers: [:]),
		])
		// The exact case, not just any DocumentError: a newer format version has
		// to be distinguishable so the app can say why it cannot open the file.
		#expect(throws: DocumentError.unsupportedVersion(BoardFile.currentFormatVersion + 1)) {
			try MozaicDocument.read(poisoned)
		}
	}

	@Test func missingManifestThrows() {
		let empty = FileWrapper(directoryWithFileWrappers: [:])
		#expect(throws: DocumentError.missingManifest) { try MozaicDocument.read(empty) }
	}

	@Test func aRegularFileIsNotAPackage() {
		let notADirectory = FileWrapper(regularFileWithContents: Data("not a package".utf8))
		#expect(throws: DocumentError.notAPackage) { try MozaicDocument.read(notADirectory) }
	}

	@Test func aMissingImageFileDoesNotPreventOpening() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		// Delete the image but leave the manifest referencing it.
		let images = try #require(wrapper.fileWrappers?["images"])
		images.removeFileWrapper(try #require(images.fileWrappers?["\(id.uuidString).png"]))

		// A board that lost one image should still open with the rest.
		let read = try MozaicDocument.read(wrapper)
		#expect(read.board.rows[0].slots[0] == id)   // slot reference survives
		#expect(read.images[id] == nil)              // bytes are simply absent
	}

	/// The views index slots 0...3 directly, so a manifest whose row carries
	/// the wrong number of slots must be rejected as corrupt rather than
	/// crashing the app the moment the board renders.
	@Test(arguments: [0, 3, 5])
	func aRowWithTheWrongNumberOfSlotsIsCorrupt(slotCount: Int) throws {
		var board = Board()
		board.rows[0].slots = Array(repeating: nil, count: slotCount)

		let wrapper = FileWrapper(directoryWithFileWrappers: [
			"manifest.json": FileWrapper(
				regularFileWithContents: try JSONEncoder().encode(BoardFile(board: board, images: []))
			),
			"images": FileWrapper(directoryWithFileWrappers: [:]),
		])

		let error = #expect(throws: CocoaError.self) { try MozaicDocument.read(wrapper) }
		#expect(error?.code == .fileReadCorruptFile)
	}

	// MARK: snapshot(contentType:) off the main actor
	//
	// AppKit calls this from `-[NSDocument writeToURL:...]` on
	// `com.apple.root.default-qos`. A main-actor-isolated version traps in
	// `_checkExpectedExecutor` the first time the user saves, so these tests
	// call it exactly the way AppKit does: from somewhere that is not the
	// main actor.

	@Test func snapshotIsCallableOffTheMainActor() async throws {
		let document = MozaicDocument()
		let id = try document.model.importImage(try makeImageData())
		document.model.place(id, row: 0, slot: 0)
		document.model.projectName = "Saved"

		let (snapshot, offMainActor) = try await Task.detached {
			(try document.snapshot(contentType: .mozaicBoard), isOffTheMainThread())
		}.value

		#expect(offMainActor)
		#expect(snapshot.board.projectName == "Saved")
		#expect(snapshot.board.rows[0].slots[0] == id)
		#expect(snapshot.images[id] != nil)
	}

	/// The full save path as AppKit runs it: snapshot off the main actor, then
	/// write the package from the value it returned.
	@Test func aDocumentEditedOnTheMainActorWritesOffIt() async throws {
		let document = MozaicDocument()
		let id = try document.model.importImage(try makeImageData())
		document.model.place(id, row: 1, slot: 2)

		// `FileWrapper` is not `Sendable`, so it never leaves the writer —
		// which is exactly how the real save path works too.
		let read = try await Task.detached {
			let snapshot = try document.snapshot(contentType: .mozaicBoard)
			let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
			return try MozaicDocument.read(wrapper)
		}.value

		#expect(read.board.rows[1].slots[2] == id)
		#expect(read.images[id] != nil)
	}
}

/// `Thread.isMainThread` is unavailable from async contexts, so the check
/// lives in a synchronous function the detached task can call.
private nonisolated func isOffTheMainThread() -> Bool { !Thread.isMainThread }
