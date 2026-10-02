import Foundation
import Testing
@testable import Mozaic

@Suite struct BoardManifestTests {
	private func sampleBoard() -> Board {
		let a = UUID(), b = UUID()
		return Board(
			projectName: "Studio",
			createdBy: "Max",
			projectDescription: "",
			showBoardInfo: true,
			gridGap: 12,
			cellRadius: 8,
			quality: .standard,
			rows: [Row(id: UUID(), module: .fourshort, slots: [a, nil, b, nil])],
			tray: [b]
		)
	}

	@Test func boardFileRoundTrips() throws {
		let file = BoardFile(board: sampleBoard(), images: [
			StoredImageMeta(id: UUID(), contentType: "public.jpeg", pixelWidth: 1000, pixelHeight: 750)
		])
		let data = try JSONEncoder().encode(file)
		let decoded = try JSONDecoder().decode(BoardFile.self, from: data)

		#expect(decoded.board.projectName == "Studio")
		#expect(decoded.board.rows.count == 1)
		#expect(decoded.board.rows[0].module == .fourshort)
		#expect(decoded.formatVersion == BoardFile.currentFormatVersion)
	}

	@Test func emptySlotsSurviveEncoding() throws {
		var board = sampleBoard()
		board.rows = [Row(id: UUID(), module: .onecell, slots: [nil, nil, nil, nil])]
		let data = try JSONEncoder().encode(BoardFile(board: board, images: []))
		let decoded = try JSONDecoder().decode(BoardFile.self, from: data)

		#expect(decoded.board.rows[0].slots.count == 4)
		#expect(decoded.board.rows[0].slots.allSatisfy { $0 == nil })
		#expect(decoded.board.tray.isEmpty == false)
	}

	@Test func moduleRawValuesArePinned() {
		// These strings are the on-disk format. Changing one silently breaks
		// every saved board. See AGENTS.md and the design doc.
		#expect(Module.vlong2short.rawValue == "vlong2short")
		#expect(Module.twoshorthlong.rawValue == "twoshorthlong")
		#expect(Module.twoshortvlong.rawValue == "twoshortvlong")
		#expect(Module.vlongtwoshort.rawValue == "vlongtwoshort")
		#expect(Module.fourshort.rawValue == "fourshort")
		#expect(Module.onecell.rawValue == "onecell")
		#expect(Module.twovlong.rawValue == "twovlong")
		#expect(Module.twohlong.rawValue == "twohlong")
		#expect(Module.allCases.count == 8)
	}

	@Test func unknownModuleFallsBackToDefault() {
		#expect(Module(storedValue: "not-a-real-module") == .vlong2short)
		#expect(Module(storedValue: "fourshort") == .fourshort)
	}
}
