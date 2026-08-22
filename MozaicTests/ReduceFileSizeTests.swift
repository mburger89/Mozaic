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

		let saved = try await store.reduceFileSize()

		#expect(saved > 0)
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

		#expect(try await store.reduceFileSize() == 0)
		#expect(store.stored(for: id)?.data == before)   // byte-identical
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

		_ = try await pm.images.reduceFileSize()

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
	@Test func reducingInvalidatesTheDecodedImageCache() async throws {
		let store = ImageStore()
		let id = try store.add(try largeJPEG(), quality: .full)
		_ = store.image(for: id)                      // populate the decode cache
		let decodesBeforeReduction = store.decodeCountForTesting

		_ = try await store.reduceFileSize()
		_ = store.image(for: id)

		#expect(store.decodeCountForTesting == decodesBeforeReduction + 1)
	}
}
