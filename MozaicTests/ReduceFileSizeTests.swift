import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ReduceFileSizeTests {
	private func largeJPEG() throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 2400, height: 1600, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
		for i in 0..<40 {                       // texture, so it does not compress to nothing
			ctx.setFillColor(CGColor(red: Double(i) / 40.0, green: 0.4, blue: 0.7, alpha: 1))
			ctx.fill(CGRect(x: i * 60, y: 0, width: 60, height: 1600))
		}
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func totalByteCountSumsStoredImages() throws {
		let store = ImageStore()
		let data = try largeJPEG()
		_ = try store.add(data, quality: .full)
		#expect(store.totalByteCount == data.count)
	}

	@Test func reducingShrinksFullQualityImagesAndPreservesFormat() async throws {
		let store = ImageStore()
		let id = try store.add(try largeJPEG(), quality: .full)
		let before = store.totalByteCount

		let outcome = await store.reduceFileSize()

		#expect(outcome.bytesSaved > 0)
		#expect(outcome.failedCount == 0)
		#expect(store.totalByteCount < before)
		let stored = try #require(store.stored(for: id))
		#expect(stored.contentType == .jpeg)                       // format preserved
		#expect(max(stored.pixelWidth, stored.pixelHeight) == ImageQuality.standardMaxPixel)
	}

	@Test func reducingIsANoOpForImagesAlreadyUnderTheCap() async throws {
		let store = ImageStore()
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))

		let id = try store.add(out as Data, quality: .standard)
		let before = try #require(store.stored(for: id)).data

		let outcome = await store.reduceFileSize()
		#expect(outcome.bytesSaved == 0)
		#expect(outcome.failedCount == 0)
		#expect(store.stored(for: id)?.data == before)   // byte-identical
	}

	/// A single corrupt image (reachable via `insert(_:for:)`, the
	/// document-read path, which tolerates bad bytes at open time) must not
	/// abort reduction for every other image in the document. The regression
	/// this guards: `reduceFileSize` used to propagate the first
	/// `ImageCoder.prepared` failure and abort the whole run, and the button
	/// that calls it swallowed the thrown error entirely -- so a board that
	/// had lost one image would silently do nothing, forever, when asked to
	/// shrink the rest.
	@Test func reducingSkipsUndecodableImagesAndStillReducesTheRest() async throws {
		let store = ImageStore()
		let goodA = try store.add(try largeJPEG(), quality: .full)
		let goodB = try store.add(try largeJPEG(), quality: .full)
		let corruptID = UUID()
		let corruptData = Data("not an image".utf8)
		store.insert(StoredImage(data: corruptData, contentType: .jpeg, pixelWidth: 2400, pixelHeight: 1600),
					for: corruptID)
		let before = store.totalByteCount

		let outcome = await store.reduceFileSize()

		#expect(outcome.bytesSaved > 0)
		#expect(outcome.failedCount == 1)
		#expect(store.totalByteCount < before)
		#expect(store.stored(for: corruptID)?.data == corruptData)   // left exactly as it was
		for id in [goodA, goodB] {
			let stored = try #require(store.stored(for: id))
			#expect(max(stored.pixelWidth, stored.pixelHeight) == ImageQuality.standardMaxPixel)
		}
	}

	/// `ImageStore.reduceFileSize()` mutates `storedImages` through the
	/// normal, direct assignment path -- the same path `add`/`insert`/
	/// `remove` use -- so `ProjectModel`'s `didChange` hook must fire and
	/// resync `BoardMirror` exactly the way it does for those. This is what
	/// actually gets written to disk on the next save, so a resync that
	/// silently didn't happen would mean Reduce File Size visibly shrinks
	/// `totalByteCount` in the UI while the saved file stays full size.
	@Test func reducingSyncsTheDocumentMirror() async throws {
		let pm = ProjectModel()
		pm.quality = .full   // otherwise import already downscales, making reduceFileSize a no-op
		let id = try pm.importImage(try largeJPEG())
		let beforeMirror = try #require(pm.mirror.snapshot.images[id]).data.count

		_ = await pm.images.reduceFileSize()

		let afterMirror = try #require(pm.mirror.snapshot.images[id]).data.count
		#expect(afterMirror < beforeMirror)
		#expect(afterMirror == pm.images.stored(for: id)?.data.count)
	}

	/// Both memoization caches are keyed by ID, and reduction replaces bytes
	/// under an existing ID -- the one place in the app that happens. If
	/// `decoded` were not invalidated, `image(for:)` would keep handing back
	/// the pre-reduction picture even though `stored(for:)` already reflects
	/// the smaller bytes. `decodeCountForTesting` proves a real re-decode
	/// happened rather than a cache hit.
	/// `ReferenceFileDocument` has no change-tracking channel other than the
	/// `UndoManager`: SwiftUI derives `updateChangeCount` entirely from undo
	/// registrations. Reduce File Size used to register nothing, so the
	/// inspector showed a smaller Document Size and the mirror held the
	/// reduced bytes while the document stayed *clean* -- close the window and
	/// there was no unsaved-changes prompt, and the file on disk kept its
	/// full-size images. A registered undo is therefore the dirty flag as much
	/// as it is an undo, which is what this asserts.
	@Test func reducingRegistersAnUndoSoTheDocumentIsDirty() async throws {
		let pm = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		pm.undoManager = undo
		pm.quality = .full
		undo.removeAllActions()          // the quality change is an edit of its own
		_ = try pm.importImage(try largeJPEG())
		#expect(undo.canUndo == false)   // importImage alone registers nothing

		let outcome = await pm.reduceImageFileSize()

		#expect(outcome.bytesSaved > 0)
		#expect(undo.canUndo)
		#expect(undo.undoActionName == "Reduce File Size")
	}

	/// Undo has to put the *bytes* back, not just the board -- reduction never
	/// touches `Board` at all -- and it has to put them back in the mirror
	/// too, since that is what a save actually writes.
	@Test func undoingAReductionRestoresTheOriginalBytesEverywhere() async throws {
		let pm = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		pm.undoManager = undo
		pm.quality = .full
		let id = try pm.importImage(try largeJPEG())
		let original = try #require(pm.images.stored(for: id))

		_ = await pm.reduceImageFileSize()
		let reducedCount = try #require(pm.images.stored(for: id)).data.count
		#expect(reducedCount < original.data.count)

		undo.undo()

		#expect(pm.images.stored(for: id) == original)
		#expect(pm.mirror.snapshot.images[id] == original)

		undo.redo()

		#expect(pm.images.stored(for: id)?.data.count == reducedCount)
		#expect(pm.mirror.snapshot.images[id]?.data.count == reducedCount)
	}

	/// A run that found nothing to shrink changed nothing, so it must not
	/// dirty the document or leave a do-nothing "Undo Reduce File Size" in the
	/// Edit menu -- the same rule `withUndo` follows for a change that did not
	/// alter the board.
	@Test func reducingNothingRegistersNoUndo() async throws {
		let pm = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		pm.undoManager = undo
		_ = try pm.importImage(try largeJPEG())   // already downscaled on import
		undo.removeAllActions()

		let outcome = await pm.reduceImageFileSize()

		#expect(outcome.bytesSaved == 0)
		#expect(outcome.previousImages.isEmpty)
		#expect(undo.canUndo == false)
	}

	/// Reduction without an `UndoManager` -- previews, tests, and the iOS
	/// document path before the environment supplies one -- must still reduce.
	@Test func reducingWorksWithoutAnUndoManager() async throws {
		let pm = ProjectModel()
		pm.quality = .full
		let id = try pm.importImage(try largeJPEG())
		let before = try #require(pm.images.stored(for: id)).data.count

		_ = await pm.reduceImageFileSize()

		#expect(try #require(pm.images.stored(for: id)).data.count < before)
	}

	/// `replaceImages` is the undo half of the one command that replaces bytes
	/// under an existing ID. It must never *insert*: an ID the store has since
	/// dropped (an image garbage-collected out of a save, say) coming back
	/// from an undo would resurrect bytes the document no longer references.
	@Test func replacingImagesIgnoresUnknownIDs() throws {
		let store = ImageStore()
		let ghost = StoredImage(data: Data("ghost".utf8), contentType: .png,
								pixelWidth: 1, pixelHeight: 1)

		let displaced = store.replaceImages([UUID(): ghost])

		#expect(displaced.isEmpty)
		#expect(store.storedImages.isEmpty)
	}

	@Test func reducingInvalidatesTheDecodedImageCache() async throws {
		let store = ImageStore()
		let id = try store.add(try largeJPEG(), quality: .full)
		_ = store.image(for: id)                      // populate the decode cache
		let decodesBeforeReduction = store.decodeCountForTesting

		_ = await store.reduceFileSize()
		_ = store.image(for: id)

		#expect(store.decodeCountForTesting == decodesBeforeReduction + 1)
	}
}
