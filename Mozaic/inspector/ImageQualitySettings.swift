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
				Task { try? await pm.images.reduceFileSize() }
			}
			Button("Cancel", role: .cancel) { }
		} message: {
			Text("Discarded detail cannot be recovered, and this cannot be undone.")
		}
	}
}

#Preview {
	ImageQualitySettings(pm: ProjectModel(), qualityBinding: .constant(.standard))
}
