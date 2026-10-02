import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// What a drop can deliver.
///
/// In-app drags carry only an ID, so moving an image between slots moves a
/// UUID rather than pixels. Drops from outside carry bytes plus the content
/// type, so the image's original format survives the trip.
enum DroppedImage: Codable, Transferable, Sendable {
	case reference(UUID)
	/// Bytes only — `ImageCoder` sniffs the real content type from them, so no
	/// UTI identifier needs to travel alongside.
	case external(Data)

	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .mozaicImageReference)
		DataRepresentation(importedContentType: .png)  { .external($0) }
		DataRepresentation(importedContentType: .jpeg) { .external($0) }
		DataRepresentation(importedContentType: .heic) { .external($0) }
		DataRepresentation(importedContentType: .tiff) { .external($0) }
		DataRepresentation(importedContentType: .gif)  { .external($0) }
	}
}

extension ProjectModel {
	/// Resolves a drop into a slot.
	///
	/// Returns whether the drop was consumed, per SwiftUI's `dropDestination`
	/// contract: `false` tells SwiftUI to animate the drop as refused rather
	/// than accepted.
	///
	/// The declared content type is a hint only — `ImageCoder` sniffs the real
	/// format from the bytes.
	@discardableResult
	func accept(_ dropped: DroppedImage, row: Int, slot: Int) throws -> Bool {
		switch dropped {
		case .reference(let id):
			// Defence in depth: never write an ID the store does not know
			// about, whatever the payload claims.
			guard images.stored(for: id) != nil else { return false }
			place(id, row: row, slot: slot)
			return true
		case .external(let data):
			let id = try importImage(data)
			place(id, row: row, slot: slot)
			return true
		}
	}
}
