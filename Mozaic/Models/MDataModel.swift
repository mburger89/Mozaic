import Foundation
import SwiftData
import SwiftUI

@Model
class MDataModel {
	var projectID: UUID
	@Attribute(.unique) var projectName: String
	var createdBy: String = ""
	var projectDescription: String
	var projectDate: Date
	var gridGap: Double = 10.0
	
	init(projectName: String,
		 projectDescription: String,
		 projectid: UUID
	){
		self.projectName = projectName
		self.projectDescription = projectDescription
		self.projectID = projectid
		self.projectDate = Date()
	}
	
	@Attribute(.externalStorage)
	var selectedPHImages: [Data]?
	
	//  MARK: MoodBoard
	@Attribute(.externalStorage)
	var mbRowImgData1: [Data]?
	var module1: String = ""
	@Attribute(.externalStorage)
	var mbRowImgData2: [Data]?
	var module2: String = ""
	@Attribute(.externalStorage)
	var mbRowImgData3: [Data]?
	var module3: String = ""
	@Attribute(.externalStorage)
	var mbRowImgData4: [Data]?
	var module4: String = ""
	@Attribute(.externalStorage)
	var mbRowImgData5: [Data]?
	var module5: String = ""
	@Attribute(.externalStorage)
	var mbRowImgData6: [Data]?
	var module6: String = ""
}
