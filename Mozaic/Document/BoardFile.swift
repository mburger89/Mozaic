import Foundation

/// The root object encoded to `manifest.json`.
nonisolated struct BoardFile: Codable, Sendable {
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
