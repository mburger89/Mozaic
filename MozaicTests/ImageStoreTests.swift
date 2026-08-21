import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ImageStoreTests {
	private func makeImage(width: Int = 40, height: Int = 30, type: UTType = .png) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: height,
							bitsPerComponent: 8, bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func addStoresAndReturnsAnID() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)

		let stored = try #require(store.stored(for: id))
		#expect(stored.contentType == .png)
		#expect(stored.pixelWidth == 40)
		#expect(stored.pixelHeight == 30)
	}

	@Test func decodesToAnImage() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)
		#expect(store.image(for: id) != nil)
	}

	@Test func unknownIDDecodesToNil() {
		#expect(ImageStore().image(for: UUID()) == nil)
	}

	@Test func decodingIsMemoized() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)

		#expect(store.decodeCountForTesting == 0)
		_ = store.image(for: id)
		#expect(store.decodeCountForTesting == 1)
		_ = store.image(for: id)
		_ = store.image(for: id)
		// Still 1: repeated access must not re-decode. This is the guard
		// against reintroducing the drag/drop lag of commit 6115747.
		#expect(store.decodeCountForTesting == 1)
	}

	@Test func filenameUsesTheImagesOwnExtension() throws {
		let store = ImageStore()
		let png = try store.add(try makeImage(type: .png), quality: .standard)
		let jpeg = try store.add(try makeImage(type: .jpeg), quality: .standard)

		#expect(try #require(store.filename(for: png)).hasSuffix(".png"))
		#expect(try #require(store.filename(for: jpeg)).hasSuffix(".jpeg"))
	}

	@Test func metadataCoversOnlyRequestedIDs() throws {
		let store = ImageStore()
		let kept = try store.add(try makeImage(), quality: .standard)
		let dropped = try store.add(try makeImage(width: 50), quality: .standard)

		let meta = store.metadata(for: [kept])
		#expect(meta.count == 1)
		#expect(meta[0].id == kept)
		#expect(store.stored(for: dropped) != nil)   // still in memory, just not requested
	}

	@Test func rejectsNonImageData() {
		let store = ImageStore()
		#expect(throws: ImageCoderError.self) {
			try store.add(Data("nope".utf8), quality: .standard)
		}
	}

	@Test func corruptStoredBytesDoNotReDecodeOnEveryCall() {
		// insert(_:for:) is the document-read path: it takes unvalidated
		// bytes straight from disk, so a corrupt image is reachable here in
		// a way add() (which validates through ImageCoder.prepared) cannot
		// produce. A failed decode must be memoized too, or a single
		// corrupt image in a shared board reintroduces per-render decoding.
		let store = ImageStore()
		let id = UUID()
		store.insert(StoredImage(data: Data("not an image".utf8),
								 contentType: .png,
								 pixelWidth: 40,
								 pixelHeight: 30),
					for: id)

		#expect(store.image(for: id) == nil)
		#expect(store.image(for: id) == nil)
		#expect(store.image(for: id) == nil)
		#expect(store.decodeCountForTesting <= 1)
	}

	@Test func insertDoesNotOverwriteExistingBytesForAnID() throws {
		// Bytes are immutable once stored under an ID: MozaicDocument's
		// incremental save reuses an existing file wrapper whenever the
		// filename matches, on the premise that a filename implies its
		// contents. insert(_:for:) must be insert-if-absent so that
		// invariant cannot be silently broken.
		let store = ImageStore()
		let id = UUID()
		let dataA = try makeImage(width: 40)
		let dataB = try makeImage(width: 50)

		store.insert(StoredImage(data: dataA, contentType: .png, pixelWidth: 40, pixelHeight: 30), for: id)
		store.insert(StoredImage(data: dataB, contentType: .png, pixelWidth: 50, pixelHeight: 30), for: id)

		#expect(store.stored(for: id)?.data == dataA)
	}
}
