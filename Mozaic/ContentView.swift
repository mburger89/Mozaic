//
//  ContentView.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
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
	let document: MozaicDocument
	private var pm: ProjectModel { document.model }
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
						Button("Import Image", systemImage: "square.and.arrow.down") {
							importing = true
						}
						.fileImporter(
							isPresented: $importing,
							allowedContentTypes: [.jpeg,.png,.gif,.tiff,.heic]
						) { result in
							switch result {
								case .success(let file):
									guard file.startAccessingSecurityScopedResource() else { return }
									defer { file.stopAccessingSecurityScopedResource() }
									do {
										try pm.importImage(try Data(contentsOf: file))
									} catch {
										print("Failed to import image:", error)
									}
								case .failure(let error):
									print(error.localizedDescription)
							}
						}
						PhotosPicker(
							selection: $selectedItems,
							matching: .any(of: [.images]),
							label: {Label("Add from Photos", systemImage: "photo.badge.plus")}
						)
						.onChange(of: selectedItems) {
							Task {
								for item in selectedItems {
									guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
									try? pm.importImage(data)
								}
							}
						}
						//				MARK: Render out Mood Board
						Button("Export Board", systemImage: "arrow.down.document.fill") {
							fileexporting = true
						}
						.fileExporter(
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
							label: {Label("Share Board", systemImage: "square.and.arrow.up")}
						)
						Button("Toggle Inspector", systemImage: "sidebar.right") {
							showSettings.toggle()
						}
					}
				}
		}
		.inspector(isPresented: $showSettings) {
			TabView {
				Tab("Images", systemImage: "photo") {
					BottomBar(pm: pm, imageIDs: pm.board.tray)
				}
				Tab("Controls", systemImage: "gear") {
					BoardSettings(pm: pm)
				}
			}
			#if os(macOS)
			.tabViewStyle(.grouped)
			#endif
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
	ContentView(document: MozaicDocument())
}

