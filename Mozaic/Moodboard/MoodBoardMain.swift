import SwiftUI

struct MoodBoardMain: View {
	@Environment(ProjectModel.self) private var pm
	
	var body: some View {
		VStack {
			LazyHGrid(rows: [
				GridItem(.fixed(300 + pm.gridGap)),
				GridItem(.fixed(300 + pm.gridGap))],
					  spacing: pm.gridGap) {
				ForEach(pm.imgC.enumerated(), id: \.element.id) { index, imgC in
					ModuleWrapper(mbCell: MbCell(cellSpacing: pm.gridGap, cell: pm.cellWidth, twoCell: pm.twoCellWidth, img: imgC.image, index: index))
				}
			}.padding(.bottom, pm.halfGridGap)
			if pm.showBoardInfo {
				BottomInfo(name: pm.projectName, createdBy: pm.createdBy)
			}
		}.frame(maxWidth: (300 + pm.gridGap * 1.55 ) * 3)
	}
}

#Preview {
	MoodBoardMain()
		.environment(ProjectModel())
}
