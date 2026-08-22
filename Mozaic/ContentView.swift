//
//  ContentView.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Already-rendered PNG bytes, wrapped for `fileExporter`.
///
/// Export needs a concrete `FileDocument`, so unlike `BoardShareItem` this
/// does hold the pixels — but it is now built in the Export button's action
/// rather than during `body`, so the render runs once per export instead of
/// twice per view update.
struct MoodBoardImage: FileDocument {
    let data: Data
    static var readableContentTypes: [UTType] { [.png] }
    init(data: Data) {
        self.data = data
    }
    init(configuration: FileDocumentReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: FileDocumentWriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct ContentView: View {
	let document: MozaicDocument
	private var pm: ProjectModel { document.model }
	@State private var selectedItems: [PhotosPickerItem] = []
	@State private var showSettings: Bool = false
	@State private var importing: Bool = false
	@State private var fileexporting: Bool = false
	/// Rendered by the Export button, not by `body`. Nil until the user asks
	/// for an export.
	@State private var exportImage: MoodBoardImage?
	@Environment(\.undoManager) private var undoManager
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
				.overlay(alignment: .bottom) {
					BoardNoticeView(pm: pm)
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
									guard file.startAccessingSecurityScopedResource() else {
										pm.postNotice("Couldn't open \(file.lastPathComponent): Mozaic wasn't granted access to it.")
										return
									}
									defer { file.stopAccessingSecurityScopedResource() }
									do {
										let data = try Data(contentsOf: file)
										var importError: Error?
										pm.withUndo("Import Image") { model in
											do {
												try model.importImage(data)
											} catch {
												importError = error
											}
										}
										if let importError {
											throw importError
										}
									} catch {
										pm.postNotice("Couldn't import \(file.lastPathComponent). It may be damaged or in a format Mozaic can't read.")
									}
								case .failure(let error):
									pm.postNotice("Import failed: \(error.localizedDescription)")
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
									do {
										guard let data = try await item.loadTransferable(type: Data.self) else {
											pm.postNotice("Couldn't read one of the selected photos.")
											continue
										}
										var importError: Error?
										pm.withUndo("Import Image") { model in
											do {
												try model.importImage(data)
											} catch {
												importError = error
											}
										}
										if let importError {
											throw importError
										}
									} catch {
										pm.postNotice("Couldn't import one of the selected photos. It may be damaged or in a format Mozaic can't read.")
									}
								}
							}
						}
						//				MARK: Render out Mood Board
						Button("Export Board", systemImage: "arrow.down.document.fill") {
							// Rendering here, rather than in `documents:`, is
							// the whole point: `body` runs on every edit, and
							// this is a full ImageRenderer pass over the board.
							guard let data = BoardRenderer.pngData(for: pm) else {
								pm.postNotice("Couldn't render the board for export.")
								return
							}
							exportImage = MoodBoardImage(data: data)
							fileexporting = true
						}
						.fileExporter(
							isPresented: $fileexporting,
							document: exportImage,
							contentType: .png,
							defaultFilename: pm.projectName,
							onCompletion: { result in
								switch result {
									case .success(let url):
										print("Saved to \(url)")
									case .failure(let error):
										pm.postNotice("Export failed: \(error.localizedDescription)")
									}
								fileexporting = false
								exportImage = nil
							}
						)

						ShareLink(
							item: BoardShareItem(model: pm),
							preview: SharePreview("MoodBoard", image: Image("mozaic")),
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
		.onChange(of: undoManager, initial: true) {
			pm.undoManager = undoManager
		}
	}
}

#Preview {
	ContentView(document: MozaicDocument())
}
