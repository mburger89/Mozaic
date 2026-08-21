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
	/// IDs whose bytes failed to decode, so a corrupt image is not retried
	/// on every render pass. See `image(for:)`.
	@ObservationIgnored private var decodeFailures: Set<UUID> = []
	/// Test-only counter proving memoization holds.
	@ObservationIgnored private(set) var decodeCountForTesting = 0

	/// `nonisolated`: `MozaicDocument.init(configuration:)` builds the store
	/// while reading a package, and SwiftUI does not contract that read to
	/// the main actor. Safe because this only places a `Sendable` dictionary
	/// into the new instance's own storage -- it touches no main-actor state.
	///
	/// Assigns `@Observable`'s backing storage rather than `self.storedImages`
	/// because the macro turns the latter into a main-actor-isolated accessor,
	/// which a nonisolated initializer cannot call. This is what that
	/// accessor's `init` does anyway, and initialization publishes no change.
	nonisolated init(storedImages: [UUID: StoredImage] = [:]) {
		_storedImages = storedImages
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
	///
	/// Bytes are immutable once stored under an ID: `MozaicDocument`'s
	/// incremental save reuses an existing file wrapper whenever the
	/// filename matches, on the premise that a filename implies its
	/// contents. So this is insert-if-absent — if `id` is already present,
	/// the existing entry wins and the new bytes are discarded. Reaching
	/// that branch is a programming error, not a user-facing one; a debug
	/// build logs it instead of trapping, so a single bad call can't take
	/// down a document-read pass (or, here, a test run) entirely.
	func insert(_ image: StoredImage, for id: UUID) {
		guard storedImages[id] == nil else {
			#if DEBUG
			print("ImageStore.insert(_:for:) called for an ID that already has stored bytes (\(id)). Bytes are immutable once stored under an ID -- keeping the existing entry.")
			#endif
			return
		}
		storedImages[id] = image
		decoded[id] = nil
		decodeFailures.remove(id)
	}

	func remove(_ id: UUID) {
		storedImages[id] = nil
		decoded[id] = nil
		decodeFailures.remove(id)
	}

	/// The decoded image, decoded at most once per ID per session.
	///
	/// A decode failure is memoized too: `insert(_:for:)` is the
	/// document-read path and takes unvalidated bytes straight from disk,
	/// so a single corrupt image must not be retried on every render pass.
	func image(for id: UUID) -> Image? {
		if let cached = decoded[id] { return cached }
		guard let stored = storedImages[id] else { return nil }
		guard !decodeFailures.contains(id) else { return nil }

		decodeCountForTesting += 1
		#if os(macOS)
		guard let native = NSImage(data: stored.data) else {
			decodeFailures.insert(id)
			return nil
		}
		let image = Image(nsImage: native)
		#else
		guard let native = UIImage(data: stored.data) else {
			decodeFailures.insert(id)
			return nil
		}
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
