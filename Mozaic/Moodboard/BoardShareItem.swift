import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// The board as a shareable PNG, rendered only when the share is actually
/// resolved.
///
/// `ShareLink` evaluates its `items:` argument during `body`, so handing it
/// already-rendered bytes meant re-rendering the entire board on every single
/// view update. This carries the model instead of the pixels, and
/// `DataRepresentation`'s export closure — which runs when something asks for
/// the transfer's data, not when the link is drawn — does the render.
///
/// `nonisolated` for the same reason as `DroppedImage`: `Transferable`'s
/// `transferRepresentation` requirement is nonisolated, and this project
/// defaults every declaration to the main actor. Holding a `ProjectModel` is
/// still safe from there — a `@MainActor` class is `Sendable`, and the only
/// thing done with it is `await`ing a main-actor render.
nonisolated struct BoardShareItem: Transferable, Sendable {
	let model: ProjectModel

	static var transferRepresentation: some TransferRepresentation {
		DataRepresentation(exportedContentType: .png) { item in
			guard let data = await BoardRenderer.pngData(for: item.model) else {
				throw BoardRenderer.Failure.renderFailed
			}
			return data
		}
	}
}
