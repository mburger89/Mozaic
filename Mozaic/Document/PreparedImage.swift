import Foundation
import UniformTypeIdentifiers

/// An image ready to be stored: bytes, the format they are in, and dimensions.
struct PreparedImage: Sendable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}
