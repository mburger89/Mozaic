//
//  bottomBar.swift
//  Mozaic
//
//  Created by Anson Burger on 9/17/25.
//

import SwiftUI
import PhotosUI

struct bottomBar: View {
	let images: [Image]
	let gridItemWith = 225.0
	let gridItemHeight = 150.0
	var body: some View {
		ScrollView(.vertical) {
			LazyVGrid(columns: [GridItem(.fixed(gridItemWith))], spacing: 10.0){
				ForEach(images.enumerated(), id: \.offset) { _, i in
					i
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame( width: gridItemWith, height: gridItemHeight)
					.background(Material.thin)
					.clipShape(RoundedRectangle(cornerRadius: 10.0))
					.draggable(i) {
						i
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: gridItemWith / 2.0, height: gridItemHeight / 2.0)
						.contentShape(.dragPreview, RoundedRectangle(cornerRadius: 10))
						}
				}
			}
		}
	}
}

#Preview {
	bottomBar(images: [Image]())
}
