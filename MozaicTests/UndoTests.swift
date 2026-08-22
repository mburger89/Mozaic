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
}
