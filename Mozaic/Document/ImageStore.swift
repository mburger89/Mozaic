import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Image bytes plus the facts needed to write and lay them out.
///
/// Bytes are immutable once stored under an ID: any edit produces a new ID.
/// `MozaicDocument`'s incremental save relies on this.
struct StoredImage: Sendable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}

/// Owns every image in a document and hands views decoded `Image` values.
///
/// Decoding is memoized. Views resolve images by ID on every render pass, so
/// decoding per call would put a full PNG decode in the render loop.
@MainActor
@Observable
final class ImageStore {
	private(set) var storedImages: [UUID: StoredImage]

	/// Not observed: filling the cache must not invalidate views.
	@ObservationIgnored private var decoded: [UUID: Image] = [:]
	/// Test-only counter proving memoization holds.
	@ObservationIgnored private(set) var decodeCountForTesting = 0

	init(storedImages: [UUID: StoredImage] = [:]) {
		self.storedImages = storedImages
	}

	func stored(for id: UUID) -> StoredImage? { storedImages[id] }

	/// Imports bytes under the document's quality setting and returns the new ID.
	@discardableResult
	func add(_ data: Data, quality: ImageQuality) throws -> UUID {
		let prepared = try ImageCoder.prepared(data, quality: quality)
		let id = UUID()
		storedImages[id] = StoredImage(data: prepared.data,
									   contentType: prepared.contentType,
									   pixelWidth: prepared.pixelWidth,
									   pixelHeight: prepared.pixelHeight)
		return id
	}

	/// Inserts an image whose ID is already known, used when reading a document.
	func insert(_ image: StoredImage, for id: UUID) {
		storedImages[id] = image
		decoded[id] = nil
	}

	func remove(_ id: UUID) {
		storedImages[id] = nil
		decoded[id] = nil
	}

	/// The decoded image, decoded at most once per ID per session.
	func image(for id: UUID) -> Image? {
		if let cached = decoded[id] { return cached }
		guard let stored = storedImages[id] else { return nil }

		decodeCountForTesting += 1
		#if os(macOS)
		guard let native = NSImage(data: stored.data) else { return nil }
		let image = Image(nsImage: native)
		#else
		guard let native = UIImage(data: stored.data) else { return nil }
		let image = Image(uiImage: native)
		#endif

		decoded[id] = image
		return image
	}

	/// Filename inside the package's `images/` directory, carrying the
	/// image's own extension.
	func filename(for id: UUID) -> String? {
		guard let stored = storedImages[id] else { return nil }
		let ext = stored.contentType.preferredFilenameExtension ?? "dat"
		return "\(id.uuidString).\(ext)"
	}

	func metadata(for ids: Set<UUID>) -> [StoredImageMeta] {
		ids.compactMap { id in
			guard let stored = storedImages[id] else { return nil }
			return StoredImageMeta(id: id,
								   contentType: stored.contentType.identifier,
								   pixelWidth: stored.pixelWidth,
								   pixelHeight: stored.pixelHeight)
		}
		.sorted { $0.id.uuidString < $1.id.uuidString }
	}
}
