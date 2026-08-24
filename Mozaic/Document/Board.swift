import Foundation

/// Everything about a board except the image bytes.
nonisolated struct Board: Codable, Hashable, Sendable {
	var projectName: String = "Untitled Project"
	var createdBy: String = "Anonymous"
	var projectDescription: String = ""
	var showBoardInfo: Bool = true
	var gridGap: Double = 10.0
	var cellRadius: Double = 10.0
	var quality: ImageQuality = .standard
	/// Variable-length by design, though the UI renders exactly `defaultRowCount`.
	var rows: [Row] = (0..<Board.defaultRowCount).map { _ in .empty() }
	var tray: [UUID] = []

	static let defaultRowCount = 6
	/// Bounds tray membership only, never the image store. Evicting an
	/// unplaced image can never remove one that is on the board.
	static let trayLimit = 30

	/// Every image ID reachable from this board. Anything absent from this
	/// set is garbage and is not written on save.
	var referencedImageIDs: Set<UUID> {
		Set(rows.flatMap { $0.slots.compactMap { $0 } }).union(tray)
	}
}
