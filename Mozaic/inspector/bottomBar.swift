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
	let gridItemWith = 150.0
	var body: some View {
		ScrollView(.vertical) {
			LazyVGrid(columns: [GridItem(.fixed(gridItemWith))], spacing: 10.0){
				ForEach(0..<images.count, id: \.self) { i in
					images[i]
						.resizable()
						.scaledToFill()
						.frame( width: gridItemWith, height: gridItemWith)
						.background(Material.thin)
						.clipShape(RoundedRectangle(cornerRadius: 10.0))
					//								.mask{RoundedRectangle(cornerRadius: 10).frame(width: gridItemWith, height: gridItemWith)}
						.draggable(images[i], preview: {
							images[i]
								.frame(width: 100, height: 100)
								.clipShape(RoundedRectangle(cornerRadius: 10.0))
						})
				}
			}
		}
	}
}

#Preview {
	bottomBar(images: [Image]())
}
