import SwiftUI

struct TwoHLong: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		VStack(spacing: mbCell.cellSpacing) {
			MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.twoCell, imgHeight: mbCell.cell, indexes: [mbCell.index,0])
			MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.twoCell, imgHeight: mbCell.cell, indexes: [mbCell.index,1])
		}
	}
}

#Preview {
	TwoHLong(
		pm: ProjectModel(),
		mbCell: MbCell(
			cellSpacing: 10,
			cell: 150,
			twoCell: (150 * 2) + 10,
			slots: [nil, nil, nil, nil],
			index: 0
		)
	)
}
