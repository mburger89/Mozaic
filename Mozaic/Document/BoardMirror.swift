import Foundation
import Synchronization

/// A thread-safe mirror of exactly the state a `.mozaic` package persists.
///
/// AppKit drives `NSDocument writeToURL:` — and therefore
/// `ReferenceFileDocument.snapshot(contentType:)` — from a background dispatch
/// queue, and `ReferenceFileDocument` carries no actor annotation, so SwiftUI
/// never promised to call it on the main actor. `snapshot(contentType:)` must
/// therefore be `nonisolated`, which means it cannot reach into
/// `ProjectModel`'s main-actor state to build its value.
///
/// So `ProjectModel` pushes the persisted state here after every mutation, and
/// `MozaicDocument.snapshot(contentType:)` reads it back under the lock. The
/// stored value is replaced wholesale, never edited in place, so a save that
/// lands mid-edit always sees one internally consistent board.
nonisolated final class BoardMirror: Sendable {
	private let state: Mutex<BoardSnapshot>

	init(board: Board = Board(), images: [UUID: StoredImage] = [:]) {
		state = Mutex(BoardSnapshot(board: board, images: images))
	}

	/// The current persisted state. Safe from any thread or executor.
	var snapshot: BoardSnapshot {
		state.withLock { $0 }
	}

	func update(board: Board, images: [UUID: StoredImage]) {
		state.withLock { $0 = BoardSnapshot(board: board, images: images) }
	}
}
