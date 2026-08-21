import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ProjectModelTests {
	private func imageData(_ seed: Int = 0) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 8 + seed, height: 8, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 8 + seed, height: 8))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func startsWithSixEmptyRows() {
		let model = ProjectModel()
		#expect(model.board.rows.count == Board.defaultRowCount)
		#expect(model.board.rows.allSatisfy { $0.slots.allSatisfy { $0 == nil } })
	}

	@Test func importingAddsToStoreAndTray() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())

		#expect(model.images.stored(for: id) != nil)
		#expect(model.board.tray == [id])
	}

	@Test func placingWritesTheSlot() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 2, slot: 1)

		#expect(model.board.rows[2].slots[1] == id)
	}

	@Test func clearingEmptiesTheSlot() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)
		model.clearSlot(row: 0, slot: 0)

		#expect(model.board.rows[0].slots[0] == nil)
	}

	@Test func trayEvictsOldestBeyondTheCap() throws {
		let model = ProjectModel()
		var ids: [UUID] = []
		for seed in 0...Board.trayLimit {          // one more than the cap
			ids.append(try model.importImage(try imageData(seed)))
		}

		#expect(model.board.tray.count == Board.trayLimit)
		#expect(model.board.tray.contains(ids.first!) == false)  // oldest evicted
		#expect(model.board.tray.contains(ids.last!))            // newest kept
	}

	@Test func trayEvictionNeverRemovesAPlacedImage() throws {
		let model = ProjectModel()
		let placed = try model.importImage(try imageData(0))
		model.place(placed, row: 0, slot: 0)

		for seed in 1...(Board.trayLimit + 5) {
			_ = try model.importImage(try imageData(seed))
		}

		// The cap bounds tray membership only. The placed image may leave the
		// tray, but its bytes and its slot must survive.
		#expect(model.board.rows[0].slots[0] == placed)
		#expect(model.images.stored(for: placed) != nil)
	}

	@Test func settingAModuleChangesOnlyThatRow() {
		let model = ProjectModel()
		model.setModule(.fourshort, row: 3)

		#expect(model.board.rows[3].module == .fourshort)
		#expect(model.board.rows[0].module == .vlong2short)
	}

	@Test func cellGeometryTracksGridGap() {
		let model = ProjectModel()
		model.gridGap = 20
		#expect(model.halfGridGap == 10)
		#expect(model.cellWidth == ProjectModel.baseCellWidth - 10)
	}
}
