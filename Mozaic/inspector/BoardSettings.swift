//
//  BoardSettings.swift
//  Mozaic
//
//  Created by Anson Burger on 10/23/25.
//

import SwiftUI

struct BoardSettings: View {
	@Bindable var pm: ProjectModel

    var body: some View {
		VStack(alignment: .leading) {
			Label {
				Text("Cell Radius")
			} icon: {
				Image(systemName: "button.roundedtop.horizontal.fill")
			}
			HStack {
				Slider(value: $pm.cellRadius, in: 0...50)
				Text(pm.cellRadius.rounded(), format: .number)
			}
//
			Label {
				Text("Grid Gap")
			} icon: {
				Image(systemName: "square.grid.2x2.fill")
			}
			HStack{
				Slider(value: $pm.gridGap, in: 0...30)
				TextField("grid gap", value: $pm.gridGap, format: .number.precision(.fractionLength(0...1)))
					.frame(width:75)
					.textFieldStyle(.roundedBorder)
			}
			Section {
				Toggle(isOn: $pm.showBoardInfo) {
					Label("Board info", systemImage: "inset.filled.bottomhalf.tophalf.rectangle")
				}
				Text("Project Name")
				TextField("Project Name", text: $pm.projectName)
					.textFieldStyle(.roundedBorder)
					.border(Color.gray)
				Text("Created By")
				TextField("Created By", text: $pm.createdBy)
					.textFieldStyle(.roundedBorder)
					.border(Color.gray)
			}
			Spacer()
		}.padding()
    }
}

#Preview {
	BoardSettings(pm: ProjectModel())
}
