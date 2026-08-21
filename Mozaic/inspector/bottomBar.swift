//
//  bottomBar.swift
//  Mozaic
//
//  Created by Anson Burger on 9/17/25.
//

import SwiftUI
import PhotosUI

struct BottomBar: View {
	var pm: ProjectModel
	let imageIDs: [UUID]
	let gridItemWidth = 225.0
	let gridItemHeight = 150.0

	var body: some View {
		ScrollView(.vertical) {
			LazyVGrid(columns: [GridItem(.fixed(gridItemWidth))], spacing: 10.0) {
				ForEach(imageIDs, id: \.self) { id in
					if let image = pm.images.image(for: id) {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: gridItemWidth, height: gridItemHeight)
							.background(Material.thin)
							.clipShape(.rect(cornerRadius: 10.0))
					}
				}
			}
		}
	}
}

#Preview {
	BottomBar(pm: ProjectModel(), imageIDs: [])
}
