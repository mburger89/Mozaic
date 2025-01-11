//
//  mooed.swift
//  Flo Ai
//
//  Created by Max Burger on 8/6/24.
//

import SwiftUI
import PhotosUI

enum sourceobj {
	case local
	case outside
}

struct mozaicMain: View {
//	@Environment(ProjectModel.self) var pm
    @State var pm = ProjectModel()
	@State var selectedItems: [PhotosPickerItem] = []
	@State var so: sourceobj = .local
	@State var isSideBarOpen = false
	@State var showDrawer : Bool = true
	@State var exportProgress: Bool = false
	let gridItemWith = 150.0
	
    var body: some View {
		NavigationStack {
			HStack(alignment: .center) {
				if isSideBarOpen {
					VStack(alignment: .leading) {
						Picker("Source Options", selection: $so) {
							Text("Local").tag(sourceobj.local)
							Text("Outside").tag(sourceobj.outside)
						}.pickerStyle(.segmented).padding()
						if so == .local {
							mbAssets(mb: pm)
						} else {
							VStack {
								Text("Google Search results")
								Spacer()
							}
						}
					}.frame(minWidth: 75, maxWidth: 250)
				} else {EmptyView()}
				ZStack(alignment: .center) {
					ScrollView {
                        MoodBoardMain().environment(pm).padding(isSideBarOpen ? .trailing : .horizontal)
						Spacer()
					}
					if showDrawer {
						VStack{
							Spacer()
								ScrollView(.horizontal) {
                                    LazyHStack(spacing: 10.0) {
										ForEach(0..<pm.filteredImages.count, id: \.self) {i in
											pm.filteredImages[i]
												.resizable()
												.scaledToFill()
												.frame( width: gridItemWith, height: gridItemWith)
												.background(Material.thin)
												.clipped()
												.mask{
													RoundedRectangle(cornerRadius: 10)
														.frame(width: gridItemWith, height: gridItemWith)
													}
												.draggable(pm.selectedPHImages[i], preview: {pm.selectedPHImages[i].frame(width: 100, height: 100).clipped()})
										}
                                    }
                                }.frame(height: 250)
						}
					}
				}
			}
		}
        #if os(iOS)
        .navigationTitle("MoodBoard Title").navigationBarTitleDisplayMode(.inline)
        #endif
		.toolbar(){
			ToolbarItemGroup(placement: .navigation) {
				PhotosPicker(selection: $selectedItems,matching: .any(of: [.images]), label: {Image(systemName: "photo.badge.plus")})
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
				Button(action: {
					exportProgress = true
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
#endif
					exportProgress = false
				}
				) {
					if !exportProgress {
						Image(systemName: "square.and.arrow.up")
					} else {
						ProgressView().controlSize(.mini).background(Material.thick)
					}
				}
				Button(action: {isSideBarOpen.toggle()}) {
					Image(systemName: "square.leftthird.inset.filled")
				}
				Button(action: {showDrawer.toggle()}) {
					Image(systemName: "square.bottomthird.inset.filled")
				}
			}
		}
    }
}

#Preview {
	mozaicMain()
		.environment(ProjectModel())
}
