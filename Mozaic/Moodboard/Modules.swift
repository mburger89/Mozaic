import SwiftUI

struct MbCell {
	let cellSpacing: CGFloat
	let cell: CGFloat
	let twoCell: CGFloat
	var slots: [UUID?]
	var index: Int
}

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

struct TwoShortHlong: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		VStack(spacing: mbCell.cellSpacing) {
			HStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 0])
				MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 1])
			}
			MbImage(pm: pm, imageID: mbCell.slots[2], imgWidth: mbCell.twoCell, imgHeight: mbCell.cell, indexes: [mbCell.index, 2])
		}
	}
}

struct TwoShortVlong: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		HStack(spacing: mbCell.cellSpacing) {
			VStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 0])
				MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 1])
            }
            MbImage(pm: pm, imageID: mbCell.slots[2], imgWidth: mbCell.cell, imgHeight: mbCell.twoCell, indexes: [mbCell.index, 2])
		}
	}
}

struct VlongTwoShort: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		VStack(spacing: mbCell.cellSpacing) {
			MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.twoCell, imgHeight: mbCell.cell, indexes: [mbCell.index, 0])
			HStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 1])
				MbImage(pm: pm, imageID: mbCell.slots[2], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 2])
			}
		}
	}
}

struct FourShort: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		HStack(spacing: mbCell.cellSpacing) {
			VStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 0])
				MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 1])
			}
			VStack(spacing: mbCell.cellSpacing) {
				MbImage(pm: pm, imageID: mbCell.slots[2], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 2])
				MbImage(pm: pm, imageID: mbCell.slots[3], imgWidth: mbCell.cell, imgHeight: mbCell.cell, indexes: [mbCell.index, 3])
			}
		}
	}
}

struct OneCell: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.twoCell, imgHeight: mbCell.twoCell, indexes: [mbCell.index, 0])
	}
}

struct TwoVLong: View {
	var pm: ProjectModel
	let mbCell: MbCell
	var body: some View {
		HStack(spacing: mbCell.cellSpacing) {
			MbImage(pm: pm, imageID: mbCell.slots[0], imgWidth: mbCell.cell, imgHeight: mbCell.twoCell, indexes: [mbCell.index,0])
			MbImage(pm: pm, imageID: mbCell.slots[1], imgWidth: mbCell.cell, imgHeight: mbCell.twoCell, indexes: [mbCell.index,1])
		}
	}
}

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
	@Previewable @State var pm: ProjectModel = ProjectModel()
	ScrollView {
        HStack(alignment: .top) {
			VStack(){
				Vlong2Short(
					pm: pm,
					mbCell: MbCell(
                    cellSpacing: 10,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)
				TwoShortHlong(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)
				OneCell(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)
				TwoHLong(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)

			}
            VStack(){
				TwoShortVlong(
					pm: pm,
					mbCell: MbCell(
                    cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
                )
				VlongTwoShort(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)
				FourShort(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)
				TwoVLong(
					pm: pm,
					mbCell: MbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					slots: [nil, nil, nil, nil],
					index: 0
					)
				)

			}
		}
	}.environment(ProjectModel())
}
