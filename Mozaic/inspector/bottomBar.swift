//
//  bottomBar.swift
//  Mozaic
//
//  Created by Anson Burger on 9/17/25.
//

import SwiftUI
import PhotosUI

struct BottomBar: View {
	let images: [Image]
	let gridItemWidth = 225.0
	let gridItemHeight = 150.0
	var body: some View {
		ScrollView(.vertical) {
			LazyVGrid(columns: [GridItem(.fixed(gridItemWidth))], spacing: 10.0){
				ForEach(images.enumerated(), id: \.offset) { _, i in
					i
					.resizable()
					.aspectRatio(contentMode: .fill)
					.frame( width: gridItemWidth, height: gridItemHeight)
					.background(Material.thin)
					.clipShape(.rect(cornerRadius: 10.0))
					.draggable(i) {
						i
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: gridItemWidth / 2.0, height: gridItemHeight / 2.0)
						.contentShape(.dragPreview, .rect(cornerRadius: 10))
						}
				}
			}
		}
	}
}

#Preview {
	BottomBar(images: [Image]())
}
