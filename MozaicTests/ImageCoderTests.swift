import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@Suite struct ImageCoderTests {
	/// Builds a real encoded image of a given size and type, so tests exercise
	/// ImageIO rather than a stub.
	private func makeImage(width: Int, height: Int, type: UTType) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: height,
							bitsPerComponent: 8, bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
		let cg = ctx.makeImage()!

		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, cg, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	/// Builds a real encoded image with more than one frame, so tests can
	/// exercise the multi-frame exemption without an animated-GIF fixture.
	/// TIFF supports multiple pages and is otherwise round-trippable, which
	/// is exactly the case FIX 2 has to catch.
	private func makeMultiFrameImage(width: Int, height: Int, frameCount: Int, type: UTType) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: height,
							bitsPerComponent: 8, bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
		let frame = ctx.makeImage()!

		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, frameCount, nil)!
		for _ in 0..<frameCount {
			CGImageDestinationAddImage(dest, frame, nil)
		}
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func sniffsContentTypeFromBytesNotExtension() throws {
		let png = try makeImage(width: 10, height: 10, type: .png)
		let jpeg = try makeImage(width: 10, height: 10, type: .jpeg)

		#expect(ImageCoder.contentType(of: png) == .png)
		#expect(ImageCoder.contentType(of: jpeg) == .jpeg)
	}

	@Test func rejectsNonImageData() {
		#expect(ImageCoder.contentType(of: Data("not an image".utf8)) == nil)
	}

	@Test func readsPixelSize() throws {
		let data = try makeImage(width: 640, height: 480, type: .png)
		let size = try #require(ImageCoder.pixelSize(of: data))
		#expect(Int(size.width) == 640)
		#expect(Int(size.height) == 480)
	}

	@Test func standardQualityPreservesFormat() throws {
		let jpeg = try makeImage(width: 2000, height: 1000, type: .jpeg)
		let result = try ImageCoder.prepared(jpeg, quality: .standard)

		#expect(result.contentType == .jpeg)          // JPEG in, JPEG out
		#expect(result.pixelWidth == 1000)            // capped on longest edge
		#expect(result.pixelHeight == 500)            // aspect ratio preserved
	}

	@Test func standardQualityDoesNotUpscale() throws {
		let png = try makeImage(width: 300, height: 200, type: .png)
		let result = try ImageCoder.prepared(png, quality: .standard)

		#expect(result.pixelWidth == 300)
		#expect(result.pixelHeight == 200)
	}

	@Test func imageAlreadyUnderCapIsStoredVerbatim() throws {
		let png = try makeImage(width: 300, height: 200, type: .png)
		let result = try ImageCoder.prepared(png, quality: .standard)

		// Byte-identical: never re-encode an image that needs no resizing,
		// which would lose quality for nothing.
		#expect(result.data == png)
	}

	@Test func fullQualityStoresOriginalBytesVerbatim() throws {
		let jpeg = try makeImage(width: 2000, height: 1000, type: .jpeg)
		let result = try ImageCoder.prepared(jpeg, quality: .full)

		#expect(result.data == jpeg)
		#expect(result.pixelWidth == 2000)
	}

	@Test func nonRoundTrippableFormatIsStoredVerbatimAndExemptFromCap() throws {
		// GIF is accepted by the file importer but has no sensible
		// single-frame re-encode, so it bypasses downscaling entirely.
		#expect(ImageCoder.isRoundTrippable(.gif) == false)
		#expect(ImageCoder.isRoundTrippable(.png))
		#expect(ImageCoder.isRoundTrippable(.jpeg))
	}

	@Test func oversizedGifPassesThroughVerbatimAndExemptFromCap() throws {
		let gif = try makeImage(width: 1200, height: 800, type: .gif)
		let result = try ImageCoder.prepared(gif, quality: .standard)

		// Byte-identical, still a GIF, and still over the cap: GIF is
		// exempt from downscaling entirely, not merely resized poorly.
		#expect(result.data == gif)
		#expect(result.contentType == .gif)
		#expect(result.pixelWidth > ImageQuality.standardMaxPixel)
	}

	@Test func oversizedMultiFrameImagePassesThroughVerbatimAndExemptFromCap() throws {
		let tiff = try makeMultiFrameImage(width: 1200, height: 800, frameCount: 2, type: .tiff)
		let result = try ImageCoder.prepared(tiff, quality: .standard)

		// TIFF is otherwise round-trippable, but a multi-page source can't
		// be re-encoded faithfully with a single-frame thumbnail pass, so it
		// must pass through untouched exactly like GIF does.
		#expect(result.data == tiff)
		#expect(result.contentType == .tiff)
		#expect(result.pixelWidth > ImageQuality.standardMaxPixel)
	}

	@Test func unrecognizedFormatThrows() {
		#expect(throws: ImageCoderError.self) {
			try ImageCoder.prepared(Data("nope".utf8), quality: .standard)
		}
	}
}
