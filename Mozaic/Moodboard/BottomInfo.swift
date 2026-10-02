//
//  BottomInfo.swift
//  Mozaic
//
//  Created by Anson Burger on 10/3/25.
//

import SwiftUI

struct BottomInfo: View {
	let name: String
	let createdBy: String
    var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text(name)
					.font(.title2)
					.padding(.leading, 10)
				Text(createdBy)
					.font(.subheadline)
					.padding(.leading, 10)
			}
			Spacer()
		}
		.frame(maxHeight: 75)
		.background(.regularMaterial)
		.clipShape(.rect(cornerRadius: 10))
    }
}

#Preview {
	BottomInfo(name: "Untitled Project", createdBy: "Anonymous").padding()
}
