import SwiftUI

struct Vlong2Short: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		HStack(spacing: mbCell.cellSpacing) {
			MbImage(pm: pm,  imageID: mbCell.slots[0], imgWidth: mbCell.cell, imgHeight: mbCell.twoCell, indexes: [mbCell.index, 0])
			VStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 1])
				MbImage(pm: pm, imageID: mbCell.slots[2], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 2])
			}
		}
	}
}

#Preview {
	Vlong2Short(
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
