import Foundation

/// What the manifest records about one stored image. The bytes live in the
/// package's `images/` directory, not here.
nonisolated struct StoredImageMeta: Codable, Hashable, Sendable {
	var id: UUID
	/// UTI string, e.g. `public.jpeg`. Sniffed from the bytes, never from a
	/// filename extension.
	var contentType: String
	var pixelWidth: Int
	var pixelHeight: Int
}
