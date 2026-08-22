//
//  BoardSettings.swift
//  Mozaic
//
//  Created by Anson Burger on 10/23/25.
//

import SwiftUI

struct BoardSettings: View {
	var pm: ProjectModel

	/// Routes every settings edit through `withUndo` instead of writing the
	/// model property directly, so a slider drag or a keystroke registers an
	/// undo step rather than bypassing the document's `UndoManager`.
	private func undoableBinding<Value>(
		_ name: String,
		_ keyPath: ReferenceWritableKeyPath<ProjectModel, Value>
	) -> Binding<Value> {
		Binding(
			get: { pm[keyPath: keyPath] },
			set: { newValue in pm.withUndo(name) { $0[keyPath: keyPath] = newValue } }
		)
	}

    var body: some View {
		VStack(alignment: .leading) {
			Label {
				Text("Cell Radius")
			} icon: {
				Image(systemName: "button.roundedtop.horizontal.fill")
			}
			HStack {
				Slider(value: undoableBinding("Change Cell Radius", \.cellRadius), in: 0...50)
				Text(pm.cellRadius.rounded(), format: .number)
			}
//
			Label {
				Text("Grid Gap")
			} icon: {
				Image(systemName: "square.grid.2x2.fill")
			}
			HStack{
				Slider(value: undoableBinding("Change Grid Gap", \.gridGap), in: 0...30)
				TextField("grid gap", value: undoableBinding("Change Grid Gap", \.gridGap), format: .number.precision(.fractionLength(0...1)))
					.frame(width:75)
					.textFieldStyle(.roundedBorder)
			}
			Section {
				Toggle(isOn: undoableBinding("Toggle Board Info", \.showBoardInfo)) {
					Label("Board info", systemImage: "inset.filled.bottomhalf.tophalf.rectangle")
				}
				Text("Project Name")
				TextField("Project Name", text: undoableBinding("Change Project Name", \.projectName))
					.textFieldStyle(.roundedBorder)
					.border(Color.gray)
				Text("Created By")
				TextField("Created By", text: undoableBinding("Change Created By", \.createdBy))
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
