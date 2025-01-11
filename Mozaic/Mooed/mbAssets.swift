//
//  mbAssets.swift
//  Flo Ai
//
//  Created by Max Burger on 8/6/24.
//

import SwiftUI
import PhotosUI

struct mbAssets: View {
	let gridItemWith = 190.0
	@Bindable var mb: ProjectModel
	var body: some View {
		VStack(spacing: 10) {
			TextField("\(Image(systemName: "magnifyingglass")) Search Assets", text: $mb.searchText)
				.textFieldStyle(.roundedBorder).padding(.horizontal)
			ScrollView {
				LazyVGrid(columns: [GridItem(.fixed(gridItemWith))], spacing: 10.0){
					ForEach(0..<mb.filteredImages.count, id: \.self) {i in
						mb.filteredImages[i]
							.resizable()
							.scaledToFill()
							.frame( width: gridItemWith, height: gridItemWith)
							.background(Material.thin)
							.clipped()
							.mask{
								RoundedRectangle(cornerRadius: 10)
									.frame(
										minWidth: 90.0,
										maxWidth: gridItemWith,
										minHeight: 90.0,
										maxHeight: gridItemWith
									)
							}
							.draggable(mb.selectedPHImages[i], preview: {mb.selectedPHImages[i].frame(width: 100, height: 100).clipped()})
					}
				}
			}
		}
	}
}

#Preview {
    mbAssets(mb: ProjectModel())
}
