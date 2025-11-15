//
//  ModWrapper.swift
//  Mozaic
//
//  Created by Anson Burger on 10/3/25.
//

import SwiftUI

enum modules {
	case vlong2short
	case twoshorthlong
	case twoshortvlong
	case vlongtwoshort
	case fourshort
	case oncecell
	case twovlong
	case twohlong
	
	func toString() -> String {
		switch self {
			case .vlong2short:
				return "vlong2short"
			case .twoshorthlong:
				return "twoshorthlong"
			case .twoshortvlong:
				return "twoshortvlong"
			case .vlongtwoshort:
				return "vlongtwoshort"
			case .fourshort:
				return "fourshort"
			case .oncecell:
				return "onecell"
			case .twovlong:
				return "twovlong"
			case .twohlong:
				return "twohlong"
		}
	}
	static func fromString(_ string: String) -> modules {
		switch string {
			case "vlong2short":
				return .vlong2short
			case "twoshorthlong":
				return .twoshorthlong
			case "twoshortvlong":
				return .twoshortvlong
			case "vlongtwoshort":
				return .vlongtwoshort
			case "fourshort":
				return .fourshort
			case "onecell":
				return .oncecell
			case "twovlong":
				return .twovlong
			case "twohlong":
				return .twohlong
			default:
				return .vlong2short
		}
	}
}

struct Modulewrapper: View {
	@Environment(ProjectModel.self) private var pm
	@Environment(\.dismiss) private var dismiss
	var mbcell: mbCell
	@State private var tapped: Bool = false
	
	var body: some View {
		VStack {
			// Main module content
			switch(pm.imgC[mbcell.index].module) {
				case .vlong2short:
					Vlong2Short(pm: pm, mbcell: mbcell)
				case .twoshorthlong:
					TwoShortHlong(pm: pm, mbcell: mbcell)
				case .twoshortvlong:
					TwoShortVlong(pm: pm, mbcell: mbcell)
				case .vlongtwoshort:
					VlongTwoShort(pm: pm, mbcell: mbcell)
				case .fourshort:
					FourShort(pm: pm, mbcell: mbcell)
				case .oncecell:
					OneCell(pm: pm, mbcell: mbcell)
				case .twovlong:
					TwoVLong(pm: pm, mbcell: mbcell)
				case .twohlong:
					TwoHLong(pm: pm, mbcell: mbcell)
				case _:
					EmptyView()
			}
		}
		.frame(width: 310, height: 310)
		.overlay(
			ZStack {
				if tapped {
					// Module selection overlay
					Grid(horizontalSpacing: 20, verticalSpacing: 20) {
						GridRow {
							Button(action: { setModule(mod: .vlong2short) }, label: { Image("module.vLongTwoShort") })
							Button(action: { setModule(mod: .twoshorthlong) }, label: { Image("module.twoShortHLong") })
							Button(action: { setModule(mod: .twoshortvlong) }, label: { Image("module.twoShortVLong") })
							Button(action: { setModule(mod: .vlongtwoshort) }, label: { Image("module.hLongTwoShort") })
						}
						GridRow {
							Button(action: { setModule(mod: .fourshort) }, label: { Image("module.fourShort") })
							Button(action: { setModule(mod: .oncecell) }, label: { Image("module.square") })
							Button(action: { setModule(mod: .twovlong) }, label: { Image("module.twoVLong") })
							Button(action: { setModule(mod: .twohlong) }, label: { Image("module.twoHLong") })
						}
					}
					.padding()
					.background(.ultraThinMaterial)
					.clipShape(RoundedRectangle(cornerRadius: 10))
					
				} else {
					EmptyView().frame(width: 200, height: 310)
				}
			}
			.onTapGesture { tapped = false }
			.frame(width: 300, height: 300)
			
		)
		.onLongPressGesture(minimumDuration: 0.50) {
			tapped = true
		}
	}
	
	func setModule(mod: modules) {
		pm.imgC[mbcell.index].module = mod
		tapped = false
	}
}

#Preview {
	let cellWidth: CGFloat = 155
	let twoCellWidth: CGFloat = 155 * 2
	let image: Image = Image("OGbgImg")
	Modulewrapper(
		mbcell: mbCell(
			cellSpacing: 10,
			cell: cellWidth,
			twoCell: (twoCellWidth + 10) ,
			img: [image,image,image,image],
			index: 0
	)).environment(ProjectModel())
}
