import Foundation
import Testing
@testable import Mozaic

@MainActor
@Suite struct UndoTests {
	@Test func undoRestoresAPreviousModule() {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		model.withUndo("Change Layout") { $0.setModule(.fourshort, row: 0) }
		#expect(model.board.rows[0].module == .fourshort)

		undo.undo()
		#expect(model.board.rows[0].module == .vlong2short)
	}

	@Test func redoReappliesTheChange() {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		model.withUndo("Change Layout") { $0.setModule(.twohlong, row: 2) }
		undo.undo()
		undo.redo()

		#expect(model.board.rows[2].module == .twohlong)
	}

	@Test func undoRestoresAClearedSlot() {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		let id = UUID()
		model.place(id, row: 0, slot: 0)
		model.withUndo("Clear Image") { $0.clearSlot(row: 0, slot: 0) }
		#expect(model.board.rows[0].slots[0] == nil)

		undo.undo()
		#expect(model.board.rows[0].slots[0] == id)
	}

	@Test func undoIsANoOpWithoutAnUndoManager() {
		let model = ProjectModel()
		model.undoManager = nil
		model.withUndo("Change Layout") { $0.setModule(.onecell, row: 1) }
		#expect(model.board.rows[1].module == .onecell)
	}

	/// `UndoManager.registerUndo(withTarget:handler:)` retains its target for
	/// as long as the registered action sits on the undo/redo stack, and
	/// `withUndo` always registers `self`. If `ProjectModel.undoManager` were
	/// a strong reference, that would close a cycle -- model retains
	/// undoManager, undoManager retains model via the stack entry -- so
	/// neither could ever deallocate while an action is unpopped, regardless
	/// of what else in the app still holds either one.
	///
	/// Both `model` and `undo` are scoped to the `do` block so their only
	/// external roots are the local `let`s. With `undoManager` correctly
	/// `weak`, dropping those roots lets both deallocate even though an
	/// action is still on the stack; with a strong `undoManager` this
	/// assertion fails, since the pair keeps each other alive forever.
	@Test func undoManagerDoesNotRetainTheModel() {
		weak var weakModel: ProjectModel?
		weak var weakUndo: UndoManager?

		do {
			let undo = UndoManager()
			undo.groupsByEvent = false
			let model = ProjectModel()
			model.undoManager = undo

			model.withUndo("Change Layout") { $0.setModule(.fourshort, row: 0) }

			weakModel = model
			weakUndo = undo
		}

		#expect(weakModel == nil)
		#expect(weakUndo == nil)
	}
}
