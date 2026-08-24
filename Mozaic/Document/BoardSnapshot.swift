import Foundation

/// Everything needed to write a document, mirrored out of the live model and
/// handed to the background writer. `Sendable` because both
/// `snapshot(contentType:)` and `fileWrapper(snapshot:configuration:)` are
/// `nonisolated`.
struct BoardSnapshot: Sendable {
	var board: Board
	var images: [UUID: StoredImage]
}
