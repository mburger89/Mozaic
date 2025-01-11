//
//  MoodBoardMain.swift
//  Flo Ai
//
//  Created by Max Burger on 8/8/24.
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
}

struct mbRow {
	var module: modules
	var image: [Image]
}

struct Modulewrapper: View {
	@Environment(ProjectModel.self) var pm
	@Environment(\.dismiss) private var dismiss
	var mbcell: mbCell
	@State var psel: modules = .vlong2short
	@State var tapped: Bool = false
	
	var body: some View {
		ZStack {
			VStack{
				switch(pm.imgC[mbcell.index].module) {
					case .vlong2short:
						Vlong2Short(mbcell: mbcell)
					case .twoshorthlong:
						TwoShortHlong(mbcell: mbcell)
					case .twoshortvlong:
						TwoShortVlong(mbcell: mbcell)
					case .vlongtwoshort:
						VlongTwoShort(mbcell: mbcell)
					case .fourshort:
						FourShort(mbcell: mbcell)
					case .oncecell:
						OneCell(mbcell: mbcell)
					case .twovlong:
						TwoVLong(mbcell: mbcell)
					case .twohlong:
						TwoHLong(mbcell: mbcell)
					case _:
						Text("")
				}
			}.onLongPressGesture(minimumDuration: 0.20){
				tapped.toggle()
			}
			if tapped {
				VStack(){
					VStack {
						withAnimation {
							Picker("", selection: $psel) {
								Text("1").tag(modules.vlong2short)
								Text("2").tag(modules.twoshorthlong)
								Text("3").tag(modules.twoshortvlong)
								Text("4").tag(modules.vlongtwoshort)
								Text("5").tag(modules.fourshort)
								Text("6").tag(modules.oncecell)
								Text("7").tag(modules.twovlong)
								Text("8").tag(modules.twohlong)
							}
							#if os(iOS)
							.pickerStyle(.wheel)
							#endif
							.onChange(of: psel) {
								pm.imgC[mbcell.index].module = psel
							}
						}
						Button(action: {tapped.toggle()}) {
							Text("Dismiss")
						}.padding()
						.background(Material.ultraThick)
						.clipShape(RoundedRectangle(cornerRadius: 10)).padding(.bottom, 10)
					}.background(Material.ultraThin).clipShape(RoundedRectangle(cornerRadius: 10))
					Spacer()
				}.frame(width: 200, height: 310)
			} else {
				EmptyView()
			}
		}
	}
}

struct MoodBoardMain: View {
	@Environment(ProjectModel.self) var pm
	var cellWidth: CGFloat = 150
	var cellSpacing: CGFloat = 10.0
	var twoCellWidth: CGFloat = (150 * 2) + 10
    var body: some View {
		Grid(horizontalSpacing: cellSpacing, verticalSpacing: cellSpacing) {
			GridRow {
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[0].image, index: 0))
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[1].image, index: 1))
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[2].image, index: 2))
			}
			GridRow {
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[3].image, index: 3))
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[4].image, index: 4))
				Modulewrapper(mbcell: mbCell(cellSpacing: cellSpacing, cell: cellWidth, twoCell: twoCellWidth, img: pm.imgC[5].image, index: 5))
			}
		}
    }
}

#Preview {
	MoodBoardMain()
		.environment(ProjectModel())
}
