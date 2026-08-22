import SwiftUI

/// A single-line text field that stages edits in local state and commits
/// them to the model as one undo step on submit or on losing focus — never
/// per keystroke.
///
/// AppKit's field editor registers its own character-level undo on the same
/// `UndoManager` the document uses. Committing through `withUndo` on every
/// keystroke (a plain `Binding` over the model, as `BoardSettings` used to
/// do) interleaves two undo stacks: the first ⌘Z after typing reverts one
/// character instead of the whole edit. Staging locally and committing only
/// at the edit's natural boundary makes one ⌘Z undo the whole field change.
struct UndoableTextField: View {
	var pm: ProjectModel
	let titleKey: String
	let name: String
	let keyPath: ReferenceWritableKeyPath<ProjectModel, String>

	@State private var text: String = ""
	@FocusState private var isFocused: Bool

	var body: some View {
		TextField(titleKey, text: $text)
			.focused($isFocused)
			.onChange(of: pm[keyPath: keyPath], initial: true) { _, newValue in
				text = newValue
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused, !nowFocused { commit() }
			}
			.onSubmit { commit() }
	}

	private func commit() {
		guard text != pm[keyPath: keyPath] else { return }
		pm.withUndo(name) { $0[keyPath: keyPath] = text }
	}
}

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
				value = newValue
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused, !nowFocused { commit() }
			}
			.onSubmit { commit() }
	}

	private func commit() {
		guard value != pm[keyPath: keyPath] else { return }
		pm.withUndo(name) { $0[keyPath: keyPath] = value }
	}
}
