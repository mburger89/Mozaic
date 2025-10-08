//
//  ContentView.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ContentView: View {
	@State var pm : ProjectModel = ProjectModel()
	@State private var selectedItems: [PhotosPickerItem] = []
	@State private var showSettings: Bool = false
	@State private var importing: Bool = false
	var body: some View {
		NavigationSplitView {
			VStack {
				//				ScrollView {
				//					ForEach(0...50, id: \.self) { i in Text("Sidebar \(i)") }
				//				}
			}
			.frame(minWidth: 225)
			.navigationTitle("MoodBoard Title")
		} detail: {
			//			ScrollView(.horizontal) {
			MoodBoardMain()
				.environment(pm)
				.toolbar {
					ToolbarItemGroup(placement: .primaryAction) {
						Button(action: {importing = true}, label: {Image(systemName: "square.and.arrow.down")}).fileImporter(
							isPresented: $importing,
							allowedContentTypes: [.jpeg,.png,.gif,.tiff,.heic]
						) { result in
							print("file import called")
							switch result {
								case .success(let file):
									let access = file.startAccessingSecurityScopedResource()
									if access {
										do {
											let data = try Data(contentsOf: file)
										#if os(iOS)
											if let uiImage = UIImage(data: data) {
												pm.selectedPHImages.append(Image(uiImage: uiImage))
											}
										#endif
										#if os(macOS)
											if let nsImage = NSImage(data: data) {
												pm.selectedPHImages.append(Image(nsImage: nsImage))
											}
										#endif
											file.stopAccessingSecurityScopedResource()
										} catch {
											print("Failed to load image data:\n", error)
										}
									}
								case .failure(let error):
									print(error.localizedDescription)
							}
						}
						PhotosPicker(
							selection: $selectedItems,
							matching: .any(of: [.images]),
							label: {Image(systemName: "photo.badge.plus")}
						)
						.onChange(of: selectedItems) {
							Task {
								for item in selectedItems {
									if let image = try? await item.loadTransferable(type: Image.self) {
										pm.selectedPHImages.append(image)
									}
								}
							}
							print("selectedItems called")
						}
						//				MARK: Render out Mood Board
						Button(action: {
							renderMoodBoard()
						}, label: {Image(systemName: "square.and.arrow.up")})
						Button(action: {showSettings.toggle()}, label: {
							Image(systemName: "sidebar.right")
						})
					}
				}
				.frame(maxWidth: 1000)
			//			}
		}
		.inspector(isPresented: $showSettings) {
			bottomBar(images: pm.selectedPHImages)
		}
	}
	func renderMoodBoard() {
#if os(macOS)
		guard let image = ImageRenderer(content: MoodBoardMain().environment(pm)).nsImage else {return}
		if let tiffData = image.tiffRepresentation,
		   let data = NSBitmapImageRep(data: tiffData)?.representation(using:.png, properties: [:]) {
			PHPhotoLibrary.shared().performChanges({
				let creationRequest = PHAssetCreationRequest.forAsset()
				creationRequest.addResource(with: .photo, data: data, options: nil)
			}, completionHandler: { success, error in
				if success {
					print("image saved to photos")
				} else {
					print("image failed to save")
					print(error ?? " ")
				}
			})
		}
#endif // os(macOS)
#if os(iOS)
		guard let image = ImageRenderer(content: MoodBoardMain().environment(pm)).uiImage else {return}
		if let data = image.pngData() {
			// Save PNG image to Photos
			PHPhotoLibrary.shared().performChanges({
				let creationRequest = PHAssetCreationRequest.forAsset()
				creationRequest.addResource(with: .photo, data: data, options: nil)
			}, completionHandler: { success, error in
				if success {
					print("image saved to photos")
				} else {
					print("image failed to save")
					print(error ?? " ")
				}
			})
		}
#endif // os(iOS)
	}
}

#Preview {
	ContentView().environment(ProjectModel())
}
