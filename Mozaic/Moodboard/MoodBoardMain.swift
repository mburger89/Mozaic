import SwiftUI

struct MoodBoardMain: View {
	@Environment(ProjectModel.self) private var pm
//	private let cellWidth: CGFloat = 150
//	private let twoCellWidth: CGFloat = 150 * 2
	
	var body: some View {
		VStack {
//			Grid(horizontalSpacing: 20) {
//				GridRow{
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap) , img: pm.imgC[0].image, index: 0))
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[1].image, index: 1))
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[2].image, index: 2))
//				}
//				GridRow {
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[3].image, index: 3))
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[4].image, index: 4))
//					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: cellWidth, twoCell: (twoCellWidth + pm.gridGap), img: pm.imgC[5].image, index: 5))
//				}
//			}
			LazyHGrid(rows: [GridItem(.fixed(300 + pm.gridGap)),
							 GridItem(.fixed(300 + pm.gridGap))], spacing: pm.gridGap) {
				ForEach(Array(pm.imgC.enumerated()), id: \.element.id) { index, imgC in
					Modulewrapper(mbcell: mbCell(cellSpacing: pm.gridGap, cell: pm.cellwidth(), twoCell: pm.twoCellWidth(), img: imgC.image, index: index))
				}
			}.padding(.bottom, pm.halfGridGap())
			if pm.showBoardInfo {
				BottomInfo(Name: pm.projectName, CreatedBy: pm.createdBy)
			}
		}.frame(maxWidth: (300 + pm.gridGap * 1.55 ) * 3)
	}
}

#Preview {
	MoodBoardMain()
		.environment(ProjectModel())
}
