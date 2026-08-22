import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Renders the whole board offscreen to PNG bytes.
///
/// Lives here rather than as a method on `ContentView` because of where it
/// used to be called from: `body` evaluated it twice on every pass — once for
/// `fileExporter`'s `documents:` and once for `ShareLink`'s `items:` — so a
/// single drop, slider tick, or committed keystroke ran two full
/// `ImageRenderer` passes over all 24 slots on the main actor before anything
/// could be drawn. Nothing about export needs that: the bytes are only ever
/// wanted at the moment the user actually exports or shares. So the export
/// button renders in its action, and `BoardShareItem` renders inside its
/// `Transferable` representation, when the share is resolved.
///
/// Because the render happens offscreen from a fresh view tree, anything that
/// depends on the on-screen environment or container size will not appear in
/// the result.
enum BoardRenderer {
	enum Failure: Error {
		/// `ImageRenderer` produced no image, or the platform could not turn
		/// what it produced into PNG bytes.
		case renderFailed
	}

	/// The board as PNG bytes, or `nil` if it could not be rendered.
	///
	/// `@MainActor` explicitly, even though this project defaults to it:
	/// `BoardShareItem`'s transfer representation is `nonisolated` and has to
	/// `await` this, so the isolation is load-bearing rather than incidental.
	@MainActor
	static func pngData(for pm: ProjectModel) -> Data? {
		let renderer = ImageRenderer(content: MoodBoardMain().environment(pm))
		#if os(macOS)
		guard let cgImage = renderer.cgImage else { return nil }
		let image = NSImage(cgImage: cgImage, size: .zero)
		guard let tiffData = image.tiffRepresentation,
			  let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
		return bitmap.representation(using: .png, properties: [:])
		#else
		return renderer.uiImage?.pngData()
		#endif
	}
}
