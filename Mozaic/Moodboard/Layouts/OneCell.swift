import SwiftUI

struct OneCell: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.twoCell, imgHeight: mbCell.twoCell, indexes: [mbCell.index, 0])
	}
}

#Preview {
	OneCell(
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
