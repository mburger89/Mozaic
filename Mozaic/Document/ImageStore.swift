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

/// What `ImageStore.reduceFileSize()` accomplished, for the inspector to
/// report to the user instead of closing the confirmation dialog and saying
/// nothing.
struct ReductionOutcome: Sendable, Equatable {
	/// Bytes freed across every image that was actually reduced.
	var bytesSaved: Int
	/// Images left untouched because they could not be prepared -- most
	/// likely bytes that arrived corrupt via the document-read path, which
	/// tolerates them at open time. Not an error: the rest of the run still
	/// completed.
	var failedCount: Int
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

	/// Fires after `storedImages` changes, so `ProjectModel` can keep its
	/// disk-mirror in sync even when a caller mutates the store directly,
	/// bypassing every `ProjectModel` method entirely -- the shape of
	/// Task 10's `pm.images.reduceFileSize()` call from the settings
	/// inspector.
	///
	/// Must fire ONLY on changes to `storedImages`. It must NOT fire from
	/// `image(for:)` populating the decode cache or `decodeFailures`: those
	/// are not persisted state, and firing there would rebuild the mirror on
	/// every render pass -- a serious performance regression.
	///
	/// `nonisolated(unsafe)`: `ProjectModel` wires this from its own
	/// `nonisolated init`, a single-threaded moment before `self` (or this
	/// store) is reachable from anywhere else, so there is no real race to
	/// guard against. Every *call* still happens on the main actor, because
	/// the only call sites (`add`, `insert`, `remove` below) are themselves
	/// main-actor-isolated methods of this class.
	@ObservationIgnored nonisolated(unsafe) var didChange: (@MainActor () -> Void)?

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
		didChange?()
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
		didChange?()
	}

	func remove(_ id: UUID) {
		storedImages[id] = nil
		decoded[id] = nil
		decodeFailures.remove(id)
		didChange?()
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

	/// Bytes currently held, for showing document size in the inspector.
	var totalByteCount: Int {
		storedImages.values.reduce(0) { $0 + $1.data.count }
	}

	/// Re-encodes every stored image down to the Standard cap, each to its own
	/// format. Images already within the cap, and formats that cannot round
	/// trip, are left byte-identical.
	///
	/// Destructive and deliberately not undoable: the discarded detail is
	/// gone, so registering an inverse would be a lie.
	///
	/// Skip-and-continue, not all-or-nothing: an image that fails
	/// `ImageCoder.prepared` (reachable via corrupt bytes that arrived
	/// through the document-read path, which tolerates them at open time) is
	/// left exactly as it is, and every other image still gets reduced.
	/// `ReductionOutcome.failedCount` tells the caller how many were skipped,
	/// so a run that helps 49 images and skips one corrupt one is not
	/// reported to the user as if nothing happened.
	///
	/// `async`: re-encoding up to ~50 stored images -- some potentially
	/// multi-megapixel -- synchronously on the main actor would freeze the UI
	/// for seconds. The actual decode/downscale/re-encode work happens in
	/// `Self.reduced(from:)`, a `nonisolated async` function with no actor of
	/// its own, so calling it with `await` runs it on the background
	/// cooperative pool instead of the main actor. Only gathering
	/// `storedImages` beforehand and writing the results back afterward touch
	/// main-actor state, and both are cheap. `StoredImage` and `Data` are
	/// `Sendable`, so handing a snapshot of the dictionary across that hop is
	/// safe.
	@discardableResult
	func reduceFileSize() async -> ReductionOutcome {
		let before = totalByteCount
		let (reduced, failedCount) = await Self.reduced(from: storedImages)
		guard !reduced.isEmpty else {
			return ReductionOutcome(bytesSaved: 0, failedCount: failedCount)
		}

		for (id, image) in reduced {
			storedImages[id] = image
			// Both caches are keyed by ID, and `reduceFileSize` is the one
			// path that replaces bytes under an ID that already has an
			// entry. Leaving either stale would make a view keep rendering
			// the pre-reduction image (`decoded`), or keep refusing to
			// render an image that decodes just fine now (`decodeFailures`).
			decoded[id] = nil
			decodeFailures.remove(id)
		}
		didChange?()
		return ReductionOutcome(bytesSaved: before - totalByteCount, failedCount: failedCount)
	}

	/// The CPU-heavy half of `reduceFileSize()`, isolated to nothing so it
	/// runs off the main actor. Returns only the entries that actually got
	/// smaller, plus how many entries could not even be prepared; the caller
	/// applies the former back to `storedImages` and reports the latter.
	///
	/// Yields every few images: without a suspension point in the loop body,
	/// once scheduled this would monopolize one cooperative-pool thread for
	/// its entire duration. That never blocks the UI -- the actual
	/// requirement -- but yielding periodically is more cooperative toward
	/// other background work competing for the pool.
	nonisolated private static func reduced(
		from images: [UUID: StoredImage]
	) async -> (results: [UUID: StoredImage], failedCount: Int) {
		var result: [UUID: StoredImage] = [:]
		var failedCount = 0
		for (index, (id, image)) in images.enumerated() {
			if index > 0, index.isMultiple(of: 8) {
				await Task.yield()
			}
			do {
				let prepared = try ImageCoder.prepared(image.data, quality: .standard)
				guard prepared.data.count < image.data.count else { continue }
				result[id] = StoredImage(data: prepared.data,
										 contentType: prepared.contentType,
										 pixelWidth: prepared.pixelWidth,
										 pixelHeight: prepared.pixelHeight)
			} catch {
				failedCount += 1
			}
		}
		return (result, failedCount)
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
