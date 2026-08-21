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

	var board: Board
	let images: ImageStore

	init(board: Board = Board(), images: ImageStore = ImageStore()) {
		self.board = board
		self.images = images
	}

	// MARK: Board settings passthroughs

	var projectName: String {
		get { board.projectName }
		set { board.projectName = newValue }
	}
	var createdBy: String {
		get { board.createdBy }
		set { board.createdBy = newValue }
	}
	var showBoardInfo: Bool {
		get { board.showBoardInfo }
		set { board.showBoardInfo = newValue }
	}
	var gridGap: Double {
		get { board.gridGap }
		set { board.gridGap = newValue }
	}
	var cellRadius: Double {
		get { board.cellRadius }
		set { board.cellRadius = newValue }
	}
	var quality: ImageQuality {
		get { board.quality }
		set { board.quality = newValue }
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
		board.rows[row].slots[slot] = id
	}

	func clearSlot(row: Int, slot: Int) {
		guard board.rows.indices.contains(row),
			  board.rows[row].slots.indices.contains(slot) else { return }
		board.rows[row].slots[slot] = nil
	}

	func setModule(_ module: Module, row: Int) {
		guard board.rows.indices.contains(row) else { return }
		board.rows[row].module = module
	}

	/// Imports bytes into the store and puts the image in the tray.
	///
	/// The tray cap bounds tray membership only — never the store — so
	/// eviction can never remove an image that is placed on the board.
	@discardableResult
	func importImage(_ data: Data) throws -> UUID {
		let id = try images.add(data, quality: board.quality)
		board.tray.append(id)
		if board.tray.count > Board.trayLimit {
			board.tray.removeFirst(board.tray.count - Board.trayLimit)
		}
		return id
	}
}
