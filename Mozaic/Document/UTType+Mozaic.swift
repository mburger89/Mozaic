import UniformTypeIdentifiers

extension UTType {
	/// The `.mozaic` document package. Declared in Info.plist.
	///
	/// `nonisolated`: the project defaults declarations to the main actor, but
	/// the document's reading and writing run off it.
	nonisolated static let mozaicBoard = UTType(exportedAs: "com.mb.unicorn.mozaic.board")

	/// In-process drag payload: a reference to an image already in the store,
	/// so dragging moves a UUID rather than pixels.
	nonisolated static let mozaicImageReference = UTType(exportedAs: "com.mb.unicorn.mozaic.image-reference")
}
