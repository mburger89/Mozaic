import Foundation

/// How much fidelity a document keeps when importing images.
///
/// This governs import only. Changing it does not alter images already
/// stored — see the Reduce File Size command.
enum ImageQuality: String, Codable, CaseIterable, Sendable {
	/// Downscale to `standardMaxPixel` on the longest edge, re-encoding to
	/// the image's own format.
	case standard
	/// Store original bytes verbatim.
	case full

	/// The largest module renders a 310pt slot, so this covers a 3x export
	/// of even the biggest cell with headroom. Any image can be dragged into
	/// any slot, so this targets the largest slot, not the one it landed in.
	static let standardMaxPixel = 1000
}

/// What the manifest records about one stored image. The bytes live in the
/// package's `images/` directory, not here.
struct StoredImageMeta: Codable, Hashable, Sendable {
	var id: UUID
	/// UTI string, e.g. `public.jpeg`. Sniffed from the bytes, never from a
	/// filename extension.
	var contentType: String
	var pixelWidth: Int
	var pixelHeight: Int
}

/// One row of the board: a layout plus four slots referencing images by ID.
///
/// Layouts using fewer than four images ignore the trailing slots.
struct Row: Codable, Hashable, Identifiable, Sendable {
	var id: UUID
	var module: Module
	/// Always four entries. `nil` is an empty slot.
	var slots: [UUID?]

	static func empty(module: Module = .vlong2short) -> Row {
		Row(id: UUID(), module: module, slots: [nil, nil, nil, nil])
	}
}

/// Everything about a board except the image bytes.
struct Board: Codable, Hashable, Sendable {
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

/// The root object encoded to `manifest.json`.
struct BoardFile: Codable, Sendable {
	static let currentFormatVersion = 1

	var formatVersion: Int
	var board: Board
	var images: [StoredImageMeta]

	init(formatVersion: Int = BoardFile.currentFormatVersion,
		 board: Board,
		 images: [StoredImageMeta]) {
		self.formatVersion = formatVersion
		self.board = board
		self.images = images
	}
}
