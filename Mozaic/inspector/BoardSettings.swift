//
//  BoardSettings.swift
//  Mozaic
//
//  Created by Anson Burger on 10/23/25.
//

import SwiftUI

struct BoardSettings: View {
	@Binding var pm : ProjectModel

	private let gridGapFormatter: NumberFormatter = {
		let formatter = NumberFormatter()
		formatter.numberStyle = .decimal
		formatter.maximumFractionDigits = 1
		return formatter
	}()

    var body: some View {
		VStack(alignment: .leading) {
			Label {
				Text("Cell Radius")
			} icon: {
				Image(systemName: "button.roundedtop.horizontal.fill")
			}
			HStack {
				Slider(value: $pm.cellRadius, in: 0...50)
				Text("\(pm.cellRadius.rounded().formatted())")
			}
//
			Label {
				Text("Grid Gap")
			} icon: {
				Image(systemName: "square.grid.2x2.fill")
			}
			HStack{
				Slider(value: $pm.gridGap, in: 0...30)
//				Text("\(pm.gridGap.rounded().formatted())")
				TextField("grid gap", value: $pm.gridGap, formatter: gridGapFormatter)
					.frame(width:100)
					.textFieldStyle(.roundedBorder)
			}
			Spacer()
		}.padding()
    }
}

#Preview {
	BoardSettings(pm: .constant(ProjectModel()))
}
