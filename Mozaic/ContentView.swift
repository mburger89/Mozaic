//
//  ContentView.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct MoodBoardImage: Transferable, FileDocument {
    let data: Data
    static var readableContentTypes: [UTType] { [.png] }
    // MARK: FileDocument conformance
    init(data: Data) {
        self.data = data
    }
    init(configuration: FileDocumentReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: FileDocumentWriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
    // MARK: Transferable conformance
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { image in
            image.data
        }
    }
}

struct ContentView: View {
	@State var pm : ProjectModel = ProjectModel()
	@State private var selectedItems: [PhotosPickerItem] = []
	@State private var showSettings: Bool = false
	@State private var importing: Bool = false
	@State private var fileexporting: Bool = false
	var body: some View {
		NavigationSplitView {
			ScrollView(.vertical) {}
			.frame(minWidth: 225)
			.navigationTitle("MoodBoard Title")
		} detail: {
			ScrollView (.horizontal){
				MoodBoardMain()
					.environment(pm)
					.containerRelativeFrame(.horizontal)
			}
				.toolbar {
					ToolbarItemGroup(placement: .primaryAction) {
						Button(
							action: {importing = true},
							label: {Image(systemName: "square.and.arrow.down")}
						).fileImporter(
							isPresented: $importing,
							allowedContentTypes: [.jpeg,.png,.gif,.tiff,.heic]
						) { result in
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
#endif // os(iOS)
#if os(macOS)
											if let nsImage = NSImage(data: data) {
												pm.selectedPHImages.append(Image(nsImage: nsImage))
											}
#endif // os(macOS)
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
						}
						//				MARK: Render out Mood Board
						Button("\(Image(systemName: "arrow.down.document.fill"))") {
							fileexporting = true
						}.fileExporter(
							isPresented: $fileexporting,
							documents: [renderMoodBoard()],
							contentType: .png,
							onCompletion: { result in
								switch result {
									case .success(let url):
										print("Saved to \(url)")
									case .failure(let error):
										print(error.localizedDescription)
									}
								fileexporting = false
							}
						)
						
						ShareLink(
							items: [renderMoodBoard()],
							preview: {_ in SharePreview("MoodBoard", image: Image("mozaic"))},
							label: {Image(systemName: "square.and.arrow.up")}
						)
						Button(action: {showSettings.toggle()}, label: {
							Image(systemName: "sidebar.right")
						})
					}
				}
		}
		.inspector(isPresented: $showSettings) {
			TabView {
				Tab("images", systemImage: "photo") {
					bottomBar(images: pm.selectedPHImages)
				}
				Tab("Controls", systemImage: "gear") {
					BoardSettings(pm: $pm)
				}
			}.tabViewStyle(.grouped)
		}
	}
	
#if os(macOS)
	func renderMoodBoard() -> MoodBoardImage {
		let renderer = ImageRenderer(content: MoodBoardMain().environment(pm))
		if let cgImage = renderer.cgImage {
			let nImage = NSImage(cgImage: cgImage, size: .zero)
			if let tiffData = nImage.tiffRepresentation,
			   let bitmap = NSBitmapImageRep(data: tiffData),
			   let pngData = bitmap.representation(using: .png, properties: [:]) {
				return MoodBoardImage(data: pngData)
			}
		}
		return MoodBoardImage(data: Data())
	}
#endif // os(macOS)
#if os(iOS)
	func renderMoodBoard() -> MoodBoardImage {
		let renderer = ImageRenderer(content: MoodBoardMain().environment(pm))
		if let uiImage = renderer.uiImage, let pngData = uiImage.pngData() {
			return MoodBoardImage(data: pngData)
		}
		return MoodBoardImage(data: Data())
	}
#endif // os(iOS)
}

#Preview {
	ContentView().environment(ProjectModel())
}

