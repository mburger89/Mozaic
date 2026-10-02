import Foundation

/// What `ImageStore.reduceFileSize()` accomplished, for the inspector to
/// report to the user instead of closing the confirmation dialog and saying
/// nothing.
struct ReductionOutcome: Sendable, Equatable {
	/// Bytes freed across every image that was actually reduced.
	var bytesSaved: Int
	/// Images left untouched because they could not be prepared -- most
	/// likely bytes that arrived corrupt via the document-read path, which
	/// tolerates them at open time. Not an error: the rest of the run still
	/// completed.
	var failedCount: Int
	/// The pre-reduction bytes of every image that was actually reduced,
	/// keyed by ID. Empty when nothing changed.
	///
	/// This is what `ProjectModel.reduceImageFileSize()` hands to
	/// `UndoManager` as the inverse of the reduction -- which is also the
	/// only reason the document gets marked dirty at all, since SwiftUI
	/// derives a `ReferenceFileDocument`'s change count entirely from undo
	/// registrations.
	var previousImages: [UUID: StoredImage] = [:]
}
