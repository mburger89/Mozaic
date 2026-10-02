import Foundation

/// One short, user-facing message about something the app did quietly or
/// refused to do: a tray eviction, a refused drop, an image it could not
/// decode.
///
/// The spec's error table promises the user is told about these, and before
/// this existed they were `print` statements and a silent `return`. One
/// mechanism covers all of them so there is a single place to look, and a
/// single presentation to keep consistent.
///
/// Never persisted and never part of `Board`, so posting one cannot dirty the
/// document or reach `BoardMirror`.
///
/// `id` is fresh per notice — including for two identical messages — so the
/// auto-dismiss in `BoardNoticeView`, which is keyed on it, restarts each
/// time rather than letting an old timer clear a new message.
nonisolated struct BoardNotice: Identifiable, Equatable, Sendable {
	let id = UUID()
	let message: String
}
