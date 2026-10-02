//
//  ImageQualitySettings.swift
//  Mozaic
//

import SwiftUI

/// The image-quality picker, live document-size figure, and the destructive
/// "Reduce File Size" command -- broken out of `BoardSettings` into its own
/// `View` rather than a computed property, per AGENTS.md.
struct ImageQualitySettings: View {
	var pm: ProjectModel
	var qualityBinding: Binding<ImageQuality>

	@State private var isConfirmingReduce = false
	/// The last run's outcome, so the confirmation dialog closing is never
	/// the last the user hears from this command -- especially when nothing
	/// could be reduced, which would otherwise look identical to the button
	/// silently doing nothing at all.
	@State private var lastReduction: ReductionOutcome?

	var body: some View {
		Picker("Image Quality", selection: qualityBinding) {
			Text("Standard").tag(ImageQuality.standard)
			Text("Full").tag(ImageQuality.full)
		}
		LabeledContent("Document Size") {
			// `Int64`: `ByteCountFormatStyle`'s `FormatInput` is `Int64`, and
			// leaving `totalByteCount` (an `Int`) for the compiler to convert
			// implicitly here crashes the type checker on this toolchain
			// instead of producing an ordinary mismatch diagnostic.
			Text(Int64(pm.images.totalByteCount), format: .byteCount(style: .file))
		}
		Button("Reduce File Size", systemImage: "arrow.down.circle") {
			isConfirmingReduce = true
		}
		.confirmationDialog(
			"Reduce every image to \(ImageQuality.standardMaxPixel)px?",
			isPresented: $isConfirmingReduce,
			titleVisibility: .visible
		) {
			Button("Reduce", role: .destructive) {
				// Goes through the model, not `pm.images`, so the reduction
				// registers an undo -- which is also the only thing that
				// marks the document as needing a save. See
				// `ProjectModel.reduceImageFileSize()`.
				Task { lastReduction = await pm.reduceImageFileSize() }
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Undo puts the original images back while this document stays open. Once it is saved and closed, the discarded detail is gone.")
		}
		if let lastReduction {
			Text(reductionSummary(lastReduction))
				.foregroundStyle(.secondary)
		}
	}

	private func reductionSummary(_ outcome: ReductionOutcome) -> String {
		let saved = Int64(outcome.bytesSaved).formatted(.byteCount(style: .file))
		let images = outcome.failedCount == 1 ? "image" : "images"
		switch (outcome.bytesSaved > 0, outcome.failedCount > 0) {
		case (true, false):
			return "Reduced by \(saved)."
		case (true, true):
			return "Reduced by \(saved); couldn't reduce \(outcome.failedCount) \(images)."
		case (false, true):
			return "Couldn't reduce \(outcome.failedCount) \(images)."
		case (false, false):
			return "Nothing to reduce -- every image is already within the cap."
		}
	}
}

#Preview {
	ImageQualitySettings(pm: ProjectModel(), qualityBinding: .constant(.standard))
}
