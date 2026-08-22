import Foundation
import SwiftUI

/// The live, editable state of one board.
///
/// Holds image *identifiers*, never decoded images: `ImageStore` owns the
/// bytes and the decode cache.
@MainActor
@Observable
final class ProjectModel {
	/// Base width of a single cell before the grid gap is applied.
	///
	/// The module and grid frames in `ModuleWrapper` and `MoodBoardMain` derive
	/// from this; changing it alone will misalign the board.
	static let baseCellWidth: CGFloat = 155.0

	/// `private(set)` on purpose. Saving reads `mirror`, not this, so every
	/// board mutation has to refresh the mirror — and the only way to
	/// guarantee none is ever missed is to make the compiler reject writes
	/// that don't go through `mutateBoard(_:)`. Whole-board replacement has
	/// its own door: `restore(_:)`.
	private(set) var board: Board
	let images: ImageStore

	/// The thread-safe copy of what gets written to disk, kept in step with
	/// `board` and `images` by every mutating path below.
	nonisolated let mirror: BoardMirror

	/// `nonisolated`: `MozaicDocument.init(configuration:)` builds the model
	/// while reading a package, and SwiftUI does not contract that read to
	/// the main actor. Safe because this only places values into the new
	/// instance's own storage -- it touches no main-actor state. `BoardMirror`
	/// is `Sendable`, so passing one in composes with that.
	///
	/// Assigns `@Observable`'s backing storage rather than `self.board`
	/// because the macro turns the latter into a main-actor-isolated
	/// accessor, which a nonisolated initializer cannot call. This is what
	/// that accessor's `init` does anyway, and initialization publishes no
	/// change. `images` and `mirror` are `let`, so the macro leaves them
	/// untouched and a plain assignment is fine; `ImageStore.init` is
	/// nonisolated too.
	///
	/// Takes the stored images as a dictionary rather than a built
	/// `ImageStore` so the mirror can be seeded here, from the same values,
	/// instead of trusting a caller to seed it consistently.
	nonisolated init(board: Board = Board(),
					 storedImages: [UUID: StoredImage] = [:],
					 mirror: BoardMirror = BoardMirror()) {
		_board = board
		self.images = ImageStore(storedImages: storedImages)
		self.mirror = mirror
		mirror.update(board: board, images: storedImages)
		// `self` is fully initialized above this line: every stored property
		// has a value, so capturing it here (even weakly) is safe. Closes the
		// hole where a caller mutates `images` directly -- bypassing every
		// `ProjectModel` method -- without the mirror ever finding out.
		images.didChange = { [weak self] in self?.syncMirror() }
	}

	// MARK: Mirror

	/// Refreshes the mirror from the live model.
	///
	/// Every mutating method here does this already. Call it directly after
	/// mutating `images` from outside `ProjectModel` — `reduceFileSize()`,
	/// for instance — since that changes what must be written without
	/// touching `board`.
	func syncMirror() {
		mirror.update(board: board, images: images.storedImages)
	}

	/// The single write path to `board`. Mutates, then mirrors.
	private func mutateBoard(_ body: (inout Board) -> Void) {
		body(&board)
		syncMirror()
	}

	// MARK: Board settings passthroughs

	var projectName: String {
		get { board.projectName }
		set { mutateBoard { $0.projectName = newValue } }
	}
	var createdBy: String {
		get { board.createdBy }
		set { mutateBoard { $0.createdBy = newValue } }
	}
	var showBoardInfo: Bool {
		get { board.showBoardInfo }
		set { mutateBoard { $0.showBoardInfo = newValue } }
	}
	var gridGap: Double {
		get { board.gridGap }
		set { mutateBoard { $0.gridGap = newValue } }
	}
	var cellRadius: Double {
		get { board.cellRadius }
		set { mutateBoard { $0.cellRadius = newValue } }
	}
	var quality: ImageQuality {
		get { board.quality }
		set { mutateBoard { $0.quality = newValue } }
	}

	// MARK: Geometry

	/// Width of a single cell, inset by half the grid gap so adjacent cells
	/// keep a constant pitch as the gap changes.
	var cellWidth: CGFloat { Self.baseCellWidth - halfGridGap }
	var twoCellWidth: CGFloat { Self.baseCellWidth * 2.0 }
	var halfGridGap: CGFloat { CGFloat(gridGap) / 2.0 }

	// MARK: Editing

	func image(for id: UUID?) -> Image? {
		guard let id else { return nil }
		return images.image(for: id)
	}

	func place(_ id: UUID, row: Int, slot: Int) {
		guard board.rows.indices.contains(row),
			  board.rows[row].slots.indices.contains(slot) else { return }
		mutateBoard { $0.rows[row].slots[slot] = id }
	}

	func clearSlot(row: Int, slot: Int) {
		guard board.rows.indices.contains(row),
			  board.rows[row].slots.indices.contains(slot) else { return }
		mutateBoard { $0.rows[row].slots[slot] = nil }
	}

	func setModule(_ module: Module, row: Int) {
		guard board.rows.indices.contains(row) else { return }
		mutateBoard { $0.rows[row].module = module }
	}

	/// Replaces the whole board — undo, revert, or any other wholesale swap.
	///
	/// The one legitimate way past `private(set) var board`, so that such a
	/// swap still refreshes the mirror.
	func restore(_ board: Board) {
		mutateBoard { $0 = board }
	}

	/// Imports bytes into the store and puts the image in the tray.
	///
	/// The tray cap bounds tray membership only — never the store — so
	/// eviction can never remove an image that is placed on the board.
	@discardableResult
	func importImage(_ data: Data) throws -> UUID {
		let id = try images.add(data, quality: board.quality)
		mutateBoard {
			$0.tray.append(id)
			if $0.tray.count > Board.trayLimit {
				$0.tray.removeFirst($0.tray.count - Board.trayLimit)
			}
		}
		return id
	}

	// MARK: Undo

	/// Supplied by the document's environment. Nil in previews and tests that
	/// do not exercise undo.
	@ObservationIgnored var undoManager: UndoManager?

	/// Runs a change and registers its inverse with `undoManager`.
	///
	/// The whole `Board` is a value type, so capturing it before the change is
	/// a cheap and complete snapshot — no per-property undo bookkeeping.
	/// Restoring goes through `restore(_:)`, the one path past `private(set)
	/// var board`, so the disk mirror always stays in sync, undo included.
	///
	/// If `change` turns out not to have altered the board — a refused drop,
	/// say — nothing is registered, so the Edit menu never grows a
	/// do-nothing "Undo" entry.
	///
	/// Brackets the registration in its own `beginUndoGrouping`/
	/// `endUndoGrouping` pair. `UndoManager`'s automatic per-event grouping
	/// only fires while AppKit is dispatching a real event; call
	/// `registerUndo` outside that (as a plain, freshly-made `UndoManager()`
	/// does, and as any manager does when `groupsByEvent` is off) and it
	/// raises `NSInternalInconsistencyException: ... must begin a group
	/// before registering undo`. Opening the group ourselves makes every
	/// call site correct regardless of context. Nesting is harmless: during
	/// a real UI event this group nests inside AppKit's own per-event group,
	/// so a slider drag that calls `withUndo` many times still collapses
	/// into one ⌘Z, and during `undo()`/`redo()` the same bracket is exactly
	/// how the inverse action gets registered for the other direction.
	func withUndo(_ name: String, _ change: (ProjectModel) -> Void) {
		let before = board
		change(self)
		guard let undoManager, board != before else { return }

		undoManager.beginUndoGrouping()
		undoManager.setActionName(name)
		undoManager.registerUndo(withTarget: self) { model in
			model.withUndo(name) { $0.restore(before) }
		}
		undoManager.endUndoGrouping()
	}
}
