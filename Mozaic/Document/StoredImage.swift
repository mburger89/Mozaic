import Foundation
import UniformTypeIdentifiers

/// Image bytes plus the facts needed to write and lay them out.
///
/// Bytes are immutable once stored under an ID: any edit produces a new ID.
/// `MozaicDocument`'s incremental save relies on this.
struct StoredImage: Sendable, Equatable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}
