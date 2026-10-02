import Foundation
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

/// Covers the deferred render path behind Export and Share.
///
/// `ContentView.body` used to call `renderMoodBoard()` twice on every
/// evaluation -- once for `fileExporter`'s `documents:` and once for
/// `ShareLink`'s `items:` -- so every drop, slider tick and keystroke ran two
/// full `ImageRenderer` passes over the whole board on the main actor. Export
/// now renders in the button's action, and Share renders inside
/// `BoardShareItem`'s transfer representation. These check the render itself
/// still works from both entry points; that it is no longer called from
/// `body` is visible in `ContentView` and not observable from a test.
@MainActor
@Suite struct BoardExportTests {
	private let pngMagic: [UInt8] = [0x89, 0x50, 0x4E, 0x47]

	@Test func rendererProducesPNGBytes() throws {
		let data = try #require(BoardRenderer.pngData(for: ProjectModel()))
		#expect(Array(data.prefix(4)) == pngMagic)
	}

	@Test func shareItemRendersOnDemand() async throws {
		let data = try await BoardShareItem(model: ProjectModel()).exported(as: .png)
		#expect(Array(data.prefix(4)) == pngMagic)
	}
}
