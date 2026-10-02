import SwiftUI

/// Same discipline as `UndoableTextField`, for the numeric grid-gap entry
/// that sits beside its slider and is bound through a `FormatStyle` instead
/// of a plain string.
struct UndoableNumberField: View {
	var pm: ProjectModel
	let titleKey: String
	let name: String
	let keyPath: ReferenceWritableKeyPath<ProjectModel, Double>

	@State private var value: Double = 0
	@FocusState private var isFocused: Bool

	var body: some View {
		TextField(titleKey, value: $value, format: .number.precision(.fractionLength(0...1)))
			.focused($isFocused)
			.onChange(of: pm[keyPath: keyPath], initial: true) { _, newValue in
				// See UndoableTextField: don't clobber an in-progress edit.
				if !isFocused { value = newValue }
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused, !nowFocused { commit() }
			}
			.onSubmit { commit() }
			// See UndoableTextField: flush a pending edit on teardown too.
			.onDisappear { commit() }
	}

	private func commit() {
		guard value != pm[keyPath: keyPath] else { return }
		pm.withUndo(name) { $0[keyPath: keyPath] = value }
	}
}
