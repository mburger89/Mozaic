//
//  ModWrapper.swift
//  Mozaic
//
//  Created by Anson Burger on 10/3/25.
//

import SwiftUI

/// The fixed layouts a single moodboard row can take.
///
/// The raw values are the strings persisted in `MDataModel.module1...module6`,
/// so they must not change without migrating stored boards.
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

struct ModuleWrapper: View {
	@Environment(ProjectModel.self) private var pm
	var mbCell: MbCell
	@State private var isPickingModule: Bool = false

	var body: some View {
		VStack {
			switch pm.board.rows[mbCell.index].module {
				case .vlong2short:
					Vlong2Short(pm: pm, mbCell: mbCell)
				case .twoshorthlong:
					TwoShortHlong(pm: pm, mbCell: mbCell)
				case .twoshortvlong:
					TwoShortVlong(pm: pm, mbCell: mbCell)
				case .vlongtwoshort:
					VlongTwoShort(pm: pm, mbCell: mbCell)
				case .fourshort:
					FourShort(pm: pm, mbCell: mbCell)
				case .onecell:
					OneCell(pm: pm, mbCell: mbCell)
				case .twovlong:
					TwoVLong(pm: pm, mbCell: mbCell)
				case .twohlong:
					TwoHLong(pm: pm, mbCell: mbCell)
			}
		}
		.frame(width: 310, height: 310)
		.overlay {
			if isPickingModule {
				ModulePicker(selection: setModule, dismiss: { isPickingModule = false })
					.frame(width: 300, height: 300)
			}
		}
		.onLongPressGesture(minimumDuration: 0.50) {
			isPickingModule = true
		}
	}

	private func setModule(_ module: Module) {
		pm.withUndo("Change Layout") { $0.setModule(module, row: mbCell.index) }
		isPickingModule = false
	}
}

/// The long-press overlay that lets the user swap a row's layout.
struct ModulePicker: View {
	let selection: (Module) -> Void
	let dismiss: () -> Void

	private var rows: [[Module]] {
		let all = Module.allCases
		return stride(from: 0, to: all.count, by: 4).map { Array(all[$0..<min($0 + 4, all.count)]) }
	}

	var body: some View {
		ZStack {
			Button(action: dismiss) {
				Color.clear.contentShape(.rect)
			}
			.buttonStyle(.plain)
			.accessibilityLabel("Dismiss layout picker")

			Grid(horizontalSpacing: 20, verticalSpacing: 20) {
				ForEach(rows, id: \.first) { row in
					GridRow {
						ForEach(row) { module in
							ModuleButton(module: module, action: selection)
						}
					}
				}
			}
			.padding()
			.background(.ultraThinMaterial)
			.clipShape(.rect(cornerRadius: 10))
		}
	}
}

/// A single layout choice in `ModulePicker`.
struct ModuleButton: View {
	let module: Module
	let action: (Module) -> Void

	var body: some View {
		Button {
			action(module)
		} label: {
			Label(module.displayName, image: module.assetName)
		}
		.labelStyle(.iconOnly)
	}
}

#Preview {
	let cellWidth: CGFloat = 155
	let twoCellWidth: CGFloat = 155 * 2
	ModuleWrapper(
		mbCell: MbCell(
			cellSpacing: 10,
			cell: cellWidth,
			twoCell: (twoCellWidth + 10) ,
			slots: [nil, nil, nil, nil],
			index: 0
	)).environment(ProjectModel())
}
