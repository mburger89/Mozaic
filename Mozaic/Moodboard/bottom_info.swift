//
//  BottomInfo.swift
//  Mozaic
//
//  Created by Anson Burger on 10/3/25.
//

import SwiftUI

struct BottomInfo: View {
	let Name: String
	let CreatedBy: String
    var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text(Name)
					.font(.title2)
					.padding(.leading, 10)
				Text(CreatedBy)
					.font(.subheadline)
					.padding(.leading, 10)
			}
			Spacer()
		}
		.frame(maxHeight: 75)
		.background(.regularMaterial)
		.cornerRadius(10)
    }
}

#Preview {
	BottomInfo(Name: "Untitled Project", CreatedBy:"Ananomys").padding()
}
