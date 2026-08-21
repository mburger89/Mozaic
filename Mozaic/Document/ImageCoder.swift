import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageCoderError: Error, Equatable {
	case unrecognizedFormat
	case decodeFailed
	case encodeFailed
}

/// An image ready to be stored: bytes, the format they are in, and dimensions.
struct PreparedImage: Sendable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}

/// Format-preserving image handling, built on ImageIO so one implementation
/// serves macOS and iPadOS.
///
/// The rule throughout: Mozaic never converts between formats. Re-encoding
/// happens only when downscaling requires it, and always to the source's own
/// content type.
enum ImageCoder {
	/// Lossy-compression quality used when a downscale forces a re-encode.
	static let recompressionQuality = 0.85

	/// Identifies format from the bytes themselves. A file whose extension
	/// disagrees with its contents must not be believed.
	static func contentType(of data: Data) -> UTType? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil),
			  let identifier = CGImageSourceGetType(source) as String? else { return nil }
		return UTType(identifier)
	}

	static func pixelSize(of data: Data) -> CGSize? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil),
			  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
			  let width = properties[kCGImagePropertyPixelWidth] as? Int,
			  let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
		return CGSize(width: width, height: height)
	}

	/// Whether this platform can write the given type, so a downscale can
	/// round-trip back into it.
	static func isRoundTrippable(_ type: UTType) -> Bool {
		guard let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] else { return false }
		// GIF is nominally writable but has no sensible single-frame
		// re-encode, so it is excluded deliberately.
		guard type != .gif else { return false }
		return writable.contains(type.identifier)
	}

	/// Prepares imported bytes for storage under the document's quality setting.
	///
	/// Returns the original bytes untouched whenever no resize is needed —
	/// in `.full` mode, when the image is already within the cap, or when the
	/// format cannot be round-tripped.
	static func prepared(_ data: Data, quality: ImageQuality) throws -> PreparedImage {
		guard let type = contentType(of: data), let size = pixelSize(of: data) else {
			throw ImageCoderError.unrecognizedFormat
		}

		let verbatim = PreparedImage(data: data,
									 contentType: type,
									 pixelWidth: Int(size.width),
									 pixelHeight: Int(size.height))

		let cap = ImageQuality.standardMaxPixel
		let longestEdge = Int(max(size.width, size.height))

		guard quality == .standard, longestEdge > cap, isRoundTrippable(type) else {
			return verbatim
		}

		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
			throw ImageCoderError.decodeFailed
		}
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: cap,
		]
		guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			throw ImageCoderError.decodeFailed
		}

		let output = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			output, type.identifier as CFString, 1, nil
		) else {
			throw ImageCoderError.encodeFailed
		}
		CGImageDestinationAddImage(destination, scaled, [
			kCGImageDestinationLossyCompressionQuality: recompressionQuality
		] as CFDictionary)

		// If re-encoding fails, keeping the original is better than losing
		// the image.
		guard CGImageDestinationFinalize(destination) else { return verbatim }

		return PreparedImage(data: output as Data,
							 contentType: type,
							 pixelWidth: scaled.width,
							 pixelHeight: scaled.height)
	}
}
