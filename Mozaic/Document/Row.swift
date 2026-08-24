import Foundation

/// One row of the board: a layout plus four slots referencing images by ID.
///
/// Layouts using fewer than four images ignore the trailing slots.
nonisolated struct Row: Codable, Hashable, Identifiable, Sendable {
	var id: UUID
	var module: Module
	/// Always four entries. `nil` is an empty slot.
	var slots: [UUID?]

	static func empty(module: Module = .vlong2short) -> Row {
		Row(id: UUID(), module: module, slots: [nil, nil, nil, nil])
	}
}
