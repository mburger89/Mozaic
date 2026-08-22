import SwiftUI

/// Shows the model's current `BoardNotice`, if there is one.
///
/// Deliberately not an alert, a sheet, or a badge: the inspector already tells
/// the user things in plain secondary text (the Reduce File Size summary), and
/// the failures this surfaces — a refused drop, an unreadable file, a tray
/// eviction — do not warrant stealing focus or a dismiss button. This sits
/// over the board rather than inside the inspector only because the inspector
/// is usually closed while the user is dropping images, and a message the user
/// cannot see is the bug being fixed.
///
/// Clears itself after a few seconds, keyed on the notice's identity, so a
/// newer notice restarts the clock rather than inheriting the old one's.
struct BoardNoticeView: View {
	var pm: ProjectModel

	var body: some View {
		if let notice = pm.notice {
			Text(notice.message)
				.font(.callout)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding()
				.background(.regularMaterial, in: .rect(cornerRadius: 10.0))
				.padding()
				.task(id: notice.id) {
					try? await Task.sleep(for: .seconds(6))
					pm.clearNotice(notice.id)
				}
		}
	}
}

#Preview {
	BoardNoticeView(pm: ProjectModel())
}
