import Foundation
import SwiftUI

/// One row of the moodboard: a layout plus the images filling its slots.
///
/// Every row carries four images regardless of layout; layouts that use fewer
/// slots simply ignore the trailing entries.
struct MbRow: Identifiable {
	let id: UUID = UUID()
	var module: Module
	var image: [Image]
}

@MainActor
@Observable
class ProjectModel {
	/// Base width of a single moodboard cell before the grid gap is applied.
	///
	/// The module and grid frames in `ModuleWrapper` and `MoodBoardMain` are
	/// derived from this value; changing it alone will misalign the board.
	static let baseCellWidth: CGFloat = 155.0

	var projectID: UUID?
	var projectDescription: String = "a description of the project"
	var projectName: String = "Untitled Project"
	var createdBy: String = "Anonymous"
	var showBoardInfo: Bool = true
	var isSideBarOpen = false
	var gridGap: Double = 10.0
	var cellRadius: Double = 10.0
	var selectedPHImages: [Image] = []

//	MARK: Mood var
	var imgC: [MbRow] = [
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		MbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
	]

// MARK: mood functions

	/// Width of a single cell, inset by half the grid gap so adjacent cells
	/// keep a constant pitch as the gap changes.
	var cellWidth: CGFloat {
		Self.baseCellWidth - halfGridGap
	}

	/// Width of a cell spanning two columns.
	var twoCellWidth: CGFloat {
		Self.baseCellWidth * 2.0
	}

	var halfGridGap: CGFloat {
		CGFloat(gridGap) / 2.0
	}

	func writeToModel(items: [Image], indexs: [Int]) {
		self.imgC[indexs[0]].image[indexs[1]] = items[0]
	}

	#if os(iOS)
	func imageToData(img: Image) -> Data {
		guard let data = ImageRenderer(content: img).uiImage?.pngData() else {
			print("[Warning] Failed to convert UIImage to Data in imageToData")
			return Data()
		}
		return data
	}

	func multipleImgToData(img: [Image]) -> [Data] {
		img.map { imageToData(img: $0) }
	}

	func multipleImgtoImage(img: [Data]) -> [Image] {
		img.compactMap { data in
			guard let uiImage = UIImage(data: data) else {
				print("[Warning] Failed to convert Data to UIImage in multipleImgtoImage")
				return nil
			}
			return Image(uiImage: uiImage)
		}
	}

	func dataToImage(img: Data) -> Image {
		guard let uiImage = UIImage(data: img) else {
			print("[Warning] Failed to convert Data to UIImage in dataToImage")
			return Image(systemName: "photo")
		}
		return Image(uiImage: uiImage)
	}
	#endif // os(iOS)
	#if os(macOS)
	func imageToData(img: Image) async -> Data {
		guard let nsImage = ImageRenderer(content: img).nsImage,
			  let data = try? await nsImage.exported(as: .png) else {
			print("[Warning] Failed to export NSImage to Data in imageToData")
			return Data()
		}
		return data
	}
	#endif // os(macOS)
}
