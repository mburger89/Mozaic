import Foundation
import UniformTypeIdentifiers
import SwiftUI
import Observation




@Observable
class ProjectModel {
    var project_id: UUID?
	var projectDescription: String = "a description of the project"
	var projectName: String = "Untitled Project"
	var createdBy: String = "Anonymous"
	var showBoardInfo: Bool = true
	var isSideBarOpen = false
	var gridGap: CGFloat = 10.0
	var cellRadius: CGFloat = 10.0
	var selectedPHImages: [Image] = []
	
//	MARK: Mood var
	var imgC: [mbRow] = [
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
		mbRow(module: .vlong2short, image: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")]),
	]
	
// MARK: mood functions
    func writeToModel(items:[Image], indexs: [Int]) {
        self.imgC[indexs[0]].image[indexs[1]] = items[0]
    }
    
	#if os(iOS)
    @MainActor
    func imageToData(img: Image) -> Data {
        let uiImg = ImageRenderer(content: img).uiImage
        guard let data = uiImg?.pngData() else {
            print("[Warning] Failed to convert UIImage to Data in imageToData")
            return Data()
        }
        return data
    }
    
    @MainActor
    func multipleImgToData(img: [Image]) -> [Data] {
        var imgArr: [Data] = []
        for i in img {
            let uiImg = ImageRenderer(content: i).uiImage
            guard let data = uiImg?.pngData() else {
                print("[Warning] Failed to convert UIImage to Data for an image in multipleImgToData")
                imgArr.append(Data())
                continue
            }
            imgArr.append(data)
        }
        return imgArr
    }
	
    func multipleImgtoImage(img: [Data]) -> [Image] {
        var imgList: [Image] = []
        for i in img {
            if let uiImage = UIImage(data: i) {
                let img = Image(uiImage: uiImage)
                imgList.append(img)
            } else {
                print("[Warning] Failed to convert Data to UIImage in multipleImgtoImage")
            }
        }
        return imgList
    }

    func dataToImage(img: Data) -> Image {
        if let uiImage = UIImage(data: img) {
            return Image(uiImage: uiImage)
        } else {
            print("[Warning] Failed to convert Data to UIImage in dataToImage")
            return Image(systemName: "photo")
        }
    }
	#endif // os(iOS)
	#if os(macOS)
	@MainActor
	func imageToData(img: Image) async -> Data {
		let tempImg = ImageRenderer(content: img).nsImage
		return try! await tempImg?.exported(as: .png) ?? Data()
	}
	#endif // os(macOS)
}

