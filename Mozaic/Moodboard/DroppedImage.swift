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
	/// Bytes plus a UTI identifier (`UTType` is not `Codable`).
	case external(Data, String)

	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .mozaicImageReference)
		DataRepresentation(importedContentType: .png)  { .external($0, UTType.png.identifier) }
		DataRepresentation(importedContentType: .jpeg) { .external($0, UTType.jpeg.identifier) }
		DataRepresentation(importedContentType: .heic) { .external($0, UTType.heic.identifier) }
		DataRepresentation(importedContentType: .tiff) { .external($0, UTType.tiff.identifier) }
		DataRepresentation(importedContentType: .gif)  { .external($0, UTType.gif.identifier) }
	}
}

extension ProjectModel {
	/// Resolves a drop into a slot.
	///
	/// The declared content type is a hint only — `ImageCoder` sniffs the real
	/// format from the bytes.
	func accept(_ dropped: DroppedImage, row: Int, slot: Int) throws {
		switch dropped {
		case .reference(let id):
			// Defence in depth: never write an ID the store does not know
			// about, whatever the payload claims.
			guard images.stored(for: id) != nil else { return }
			place(id, row: row, slot: slot)
		case .external(let data, _):
			let id = try importImage(data)
			place(id, row: row, slot: slot)
		}
	}
}
