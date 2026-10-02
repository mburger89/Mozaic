import SwiftUI

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
