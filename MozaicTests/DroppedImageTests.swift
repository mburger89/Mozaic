import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct DroppedImageTests {
	private func pngData() throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 12, height: 12, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 1, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func referencePayloadRoundTrips() throws {
		let id = UUID()
		let data = try JSONEncoder().encode(DroppedImage.reference(id))
		let decoded = try JSONDecoder().decode(DroppedImage.self, from: data)

		guard case .reference(let decodedID) = decoded else {
			Issue.record("expected a reference payload"); return
		}
		#expect(decodedID == id)
	}

	@Test func acceptingAReferencePlacesWithoutCopyingBytes() throws {
		let model = ProjectModel()
		let id = try model.importImage(try pngData())
		let storedCount = model.images.storedImages.count

		let accepted = try model.accept(.reference(id), row: 1, slot: 2)

		#expect(accepted)
		#expect(model.board.rows[1].slots[2] == id)
		// An in-app drag moves an ID: no new image is created.
		#expect(model.images.storedImages.count == storedCount)
	}

	@Test func acceptingAnExternalDropImportsThenPlaces() throws {
		let model = ProjectModel()
		let accepted = try model.accept(.external(try pngData()), row: 0, slot: 3)

		#expect(accepted)
		let placed = try #require(model.board.rows[0].slots[3])
		#expect(model.images.stored(for: placed) != nil)
	}

	@Test func acceptingAReferenceToAnUnknownImageIsIgnored() throws {
		let model = ProjectModel()
		let accepted = try model.accept(.reference(UUID()), row: 0, slot: 0)

		// A dangling reference must never reach the board, or the manifest
		// would point at a file that was never written. SwiftUI must also be
		// told the drop was refused, not silently accepted.
		#expect(!accepted)
		#expect(model.board.rows[0].slots[0] == nil)
	}

	@Test func acceptingCorruptExternalDataThrowsAndLeavesTheBoardAlone() {
		let model = ProjectModel()
		#expect(throws: ImageCoderError.self) {
			try model.accept(.external(Data("nope".utf8)), row: 0, slot: 0)
		}
		#expect(model.board.rows[0].slots[0] == nil)
	}
}
