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
				// Only re-seed while unfocused. While focused, `text` is the
				// user's in-progress edit; an external change to the same
				// property (a stray undo landing here, another view writing
				// it) must not silently clobber what they're typing. The
				// next focus loss re-reads the model anyway, so nothing is
				// lost — the re-seed is just deferred, not skipped.
				if !isFocused { text = newValue }
			}
			.onChange(of: isFocused) { wasFocused, nowFocused in
				if wasFocused, !nowFocused { commit() }
			}
			.onSubmit { commit() }
			// View teardown is also a commit boundary. Without this, closing
			// the window while this field still has focus drops the
			// in-progress edit silently — worse, since nothing ever wrote to
			// `pm`, no undo action registers and the document never learns
			// it's dirty, so the close-without-saving prompt might not even
			// appear.
			.onDisappear { commit() }
	}

	private func commit() {
		guard text != pm[keyPath: keyPath] else { return }
		pm.withUndo(name) { $0[keyPath: keyPath] = text }
	}
}
