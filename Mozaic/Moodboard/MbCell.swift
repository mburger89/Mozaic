import SwiftUI

/// The geometry and slot contents one row's layout view needs.
struct MbCell {
	let cellSpacing: CGFloat
	let cell: CGFloat
	let twoCell: CGFloat
	var slots: [UUID?]
	var index: Int
}
