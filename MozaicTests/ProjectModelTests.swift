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

	@Test func restoringSwapsTheWholeBoard() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)

		var replacement = Board()
		replacement.projectName = "Restored"
		model.restore(replacement)

		#expect(model.board.projectName == "Restored")
		#expect(model.board.rows[0].slots[0] == nil)
	}

	// MARK: The persisted-state mirror
	//
	// `MozaicDocument.snapshot(contentType:)` is `nonisolated` and returns the
	// mirror, never the live model, so a mutation that forgets to refresh the
	// mirror is a silent data-loss bug: the edit shows on screen and is absent
	// from the saved file. One test per mutating path, so adding a mutation
	// without syncing fails here rather than in someone's document.

	@Test func placingUpdatesTheMirror() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 2, slot: 1)

		#expect(model.mirror.snapshot.board.rows[2].slots[1] == id)
	}

	@Test func clearingASlotUpdatesTheMirror() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)
		model.clearSlot(row: 0, slot: 0)

		#expect(model.mirror.snapshot.board.rows[0].slots[0] == nil)
	}

	@Test func settingAModuleUpdatesTheMirror() {
		let model = ProjectModel()
		model.setModule(.fourshort, row: 3)

		#expect(model.mirror.snapshot.board.rows[3].module == .fourshort)
	}

	@Test func importingUpdatesTheMirrorsBoardAndImages() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())

		let mirrored = model.mirror.snapshot
		#expect(mirrored.board.tray == [id])
		#expect(mirrored.images[id] != nil)
		#expect(mirrored.images[id]?.data == model.images.stored(for: id)?.data)
	}

	@Test func aSettingsPassthroughUpdatesTheMirror() {
		let model = ProjectModel()
		model.gridGap = 42
		#expect(model.mirror.snapshot.board.gridGap == 42)

		model.projectName = "Kitchen"
		#expect(model.mirror.snapshot.board.projectName == "Kitchen")
	}

	@Test func restoringUpdatesTheMirror() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)

		var replacement = Board()
		replacement.projectName = "Restored"
		model.restore(replacement)

		let mirrored = model.mirror.snapshot
		#expect(mirrored.board.projectName == "Restored")
		#expect(mirrored.board.rows[0].slots[0] == nil)
	}

	@Test func aDirectImageStoreMutationReachesTheMirrorOnceSynced() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)

		// `pm.images` is reachable from outside `ProjectModel`, so a caller
		// that mutates it (Reduce File Size, for one) has to say so.
		model.images.remove(id)
		model.syncMirror()

		#expect(model.mirror.snapshot.images[id] == nil)
	}

	@Test func aDirectImageStoreMutationAutomaticallyReachesTheMirror() throws {
		// `pm.images` is a reference type reachable from outside `ProjectModel`
		// (Task 10's `pm.images.reduceFileSize()` is exactly this shape).
		// `ImageStore.didChange` closes that hole: it must sync the mirror on
		// its own, with no `model.syncMirror()` call from the test at all,
		// unlike `aDirectImageStoreMutationReachesTheMirrorOnceSynced` above.
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)
		#expect(model.mirror.snapshot.images[id] != nil)

		model.images.remove(id)

		#expect(model.mirror.snapshot.images[id] == nil)
	}

	@Test func theMirrorIsSeededByTheInitializer() throws {
		let id = UUID()
		let stored = StoredImage(data: try imageData(), contentType: .png,
								 pixelWidth: 8, pixelHeight: 8)
		var board = Board()
		board.projectName = "Seeded"
		board.rows[0].slots[0] = id

		let model = ProjectModel(board: board, storedImages: [id: stored])

		let mirrored = model.mirror.snapshot
		#expect(mirrored.board.projectName == "Seeded")
		#expect(mirrored.board.rows[0].slots[0] == id)
		#expect(mirrored.images[id] != nil)
	}

	/// The whole reason the mirror exists: AppKit reads the snapshot from a
	/// background dispatch queue during `NSDocument writeToURL:`.
	@Test func theMirrorIsReadableOffTheMainActor() async throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 1, slot: 1)

		let mirror = model.mirror
		let (mirrored, offMainActor) = await Task.detached {
			(mirror.snapshot, isOffTheMainThread())
		}.value

		#expect(offMainActor)
		#expect(mirrored.board.rows[1].slots[1] == id)
		#expect(mirrored.images[id] != nil)
	}
}

/// `Thread.isMainThread` is unavailable from async contexts, so the check
/// lives in a synchronous function the detached task can call.
private nonisolated func isOffTheMainThread() -> Bool { !Thread.isMainThread }
