//
//  mbImage.swift
//  Flo Ai
//
//  Created by Max Burger on 8/10/24.
//

import SwiftUI

struct mbImage: View {
	@Environment(ProjectModel.self) var pm
	@State private var isTarget: Bool = false
	@State private var isLoading: Bool = false
	var imgSlot: Image
	var imgWidth: CGFloat
	var imgHeight: CGFloat
	var indexes: [Int]
    var body: some View {
		ZStack {
			imgSlot
				.resizable()
				.scaledToFill()
				.foregroundColor(.gray)
				.frame(width: imgWidth, height: imgHeight)
				.background(Material.thin)
				.clipShape(RoundedRectangle(cornerRadius: 10))
				.dropDestination(for: Image.self, action: {items, location in
	//				imgSlot = items[0]
					
					Task {
						await writeToModel(items: items)
					}
					
				return true
			}, isTargeted: { target in
				isTarget = target
			})
			.overlay{
				RoundedRectangle(cornerRadius: 10)
					.stroke((isTarget ? .blue : .clear), lineWidth: 3.0)
			}
			if isLoading {
				ProgressView().controlSize(.extraLarge)
			}
		}
    }
	func writeToModel(items:[Image]) async {
		isLoading = true
		pm.imgC[indexes[0]].image[indexes[1]] = items[0]
		isLoading = false
	}
}

#Preview {
	mbImage(imgSlot: Image("OGbgImg"), imgWidth: 200.0, imgHeight: 200.0, indexes: [0,0]).environment(ProjectModel())
}
