import SwiftUI

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
