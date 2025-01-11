//
//  ProjectModel.swift
//  Flo Ai
//
//  Created by Max Burger on 8/13/24.
//

import Foundation
import SwiftUI
import Observation


//struct asyncMessage: Codable {
//	let base64: String?
//	let url: String
//	let seed: String
//	let finish_reason: String
//}

@Observable
class ProjectModel {
	var searchText: String = ""
	var selectedPHImages: [Image] = []
	var filteredImages: [Image] {
		if searchText.isEmpty {
			if selectedPHImages.isEmpty {
				return [Image]()
			}
			return selectedPHImages
		} else {
			return selectedPHImages.filter { Image in
				selectedPHImages.description.localizedStandardContains(searchText)
			}
		}
	}

//	MARK: image var
	var imgC: [mbRow] = [
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
	]
	
}
