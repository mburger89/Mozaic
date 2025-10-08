import SwiftUI

struct MoodBoardMain: View {
	@Environment(ProjectModel.self) private var pm
	private let cellWidth: CGFloat = 150
	private let twoCellWidth: CGFloat = 150 * 2
	
	var body: some View {
		VStack {
			Grid(horizontalSpacing: 20) {
				GridRow{
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap) , img: pm.imgC[0].image, index: 0))
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[1].image, index: 1))
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[2].image, index: 2))
				}
				GridRow {
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[3].image, index: 3))
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[4].image, index: 4))
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[5].image, index: 5))
				}
			}
			if pm.showBoardInfo {
				BottomInfo(Name: pm.projectName, CreatedBy: pm.createdBy)
			}
		}
	}
}

#Preview {
	MoodBoardMain()
		.environment(ProjectModel())
}
