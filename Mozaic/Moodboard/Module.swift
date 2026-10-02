import SwiftUI

/// The fixed layouts a single moodboard row can take.
///
/// The raw values are the strings persisted as `Row.module` in a document's
/// `manifest.json`, so they must not change without migrating stored boards.
enum Module: String, CaseIterable, Identifiable, Codable {
	case vlong2short = "vlong2short"
	case twoshorthlong = "twoshorthlong"
	case twoshortvlong = "twoshortvlong"
	case vlongtwoshort = "vlongtwoshort"
	case fourshort = "fourshort"
	case onecell = "onecell"
	case twovlong = "twovlong"
	case twohlong = "twohlong"

	var id: Self { self }

	/// Creates a module from a persisted raw value, falling back to the default
	/// layout when the stored string is missing or unrecognised.
	init(storedValue: String) {
		self = Module(rawValue: storedValue) ?? .vlong2short
	}

	/// Name of the asset-catalog symbol used in the layout picker.
	var assetName: String {
		switch self {
			case .vlong2short: "module.vLongTwoShort"
			case .twoshorthlong: "module.twoShortHLong"
			case .twoshortvlong: "module.twoShortVLong"
			case .vlongtwoshort: "module.hLongTwoShort"
			case .fourshort: "module.fourShort"
			case .onecell: "module.square"
			case .twovlong: "module.twoVLong"
			case .twohlong: "module.twoHLong"
		}
	}

	/// Human-readable description of the layout, used as the picker button's
	/// accessibility label.
	var displayName: String {
		switch self {
			case .vlong2short: "Tall left, two short right"
			case .twoshorthlong: "Two short above, one wide below"
			case .twoshortvlong: "Two short left, tall right"
			case .vlongtwoshort: "One wide above, two short below"
			case .fourshort: "Four short"
			case .onecell: "Single square"
			case .twovlong: "Two tall side by side"
			case .twohlong: "Two wide stacked"
		}
	}
}
