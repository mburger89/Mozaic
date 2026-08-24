import Foundation

/// How much fidelity a document keeps when importing images.
///
/// This governs import only. Changing it does not alter images already
/// stored — see the Reduce File Size command.
nonisolated enum ImageQuality: String, Codable, CaseIterable, Sendable {
	/// Downscale to `standardMaxPixel` on the longest edge, re-encoding to
	/// the image's own format.
	case standard
	/// Store original bytes verbatim.
	case full

	/// The largest module renders a 310pt slot, so this covers a 3x export
	/// of even the biggest cell with headroom. Any image can be dragged into
	/// any slot, so this targets the largest slot, not the one it landed in.
	///
	/// `nonisolated`: read by `ImageCoder`, which must itself be nonisolated
	/// so image encoding can run off the main actor.
	nonisolated static let standardMaxPixel = 1000
}
