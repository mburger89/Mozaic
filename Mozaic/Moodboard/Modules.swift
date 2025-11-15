import SwiftUI

struct mbCell {
	let cellSpacing: CGFloat
	let cell: CGFloat
	let twoCell: CGFloat
	var img: [Image]
	var index: Int
}

struct Vlong2Short: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			MbImage(pm: pm,  imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 0])
			VStack(spacing: mbcell.cellSpacing) {
				MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
				MbImage(pm: pm, imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
			}
		}
	}
}

struct TwoShortHlong: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			HStack(spacing: mbcell.cellSpacing) {
				MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
			}
			MbImage(pm: pm, imgSlot: mbcell.img[2], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
		}
	}
}

struct TwoShortVlong: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		HStack() {
			VStack() {
				MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
            }
            MbImage(pm: pm, imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 2])
		}
	}
}

struct VlongTwoShort: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
			HStack(spacing: mbcell.cellSpacing) {
				MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
				MbImage(pm: pm, imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
			}
		}
	}
}

struct FourShort: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			VStack(spacing: mbcell.cellSpacing) {
				MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
			}
			VStack(spacing: mbcell.cellSpacing) {
				MbImage(pm: pm, imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
				MbImage(pm: pm, imgSlot: mbcell.img[3], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 3])
			}
		}
	}
}

struct OneCell: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.twoCell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 0])
	}
}

struct TwoVLong: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index,0])
			MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index,1])
		}
	}
}

struct TwoHLong: View {
	var pm: ProjectModel
	let mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			MbImage(pm: pm, imgSlot: mbcell.img[0], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index,0])
			MbImage(pm: pm, imgSlot: mbcell.img[1], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index,1])
		}
	}
}

#Preview {
	@Previewable var pm: ProjectModel = ProjectModel()
	ScrollView {
        HStack(alignment: .top) {
			VStack(){
				Vlong2Short(
					pm: pm,
					mbcell: mbCell(
                    cellSpacing: 10,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoShortHlong(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				OneCell(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoHLong(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				
			}
            VStack(){
				TwoShortVlong(
					pm: pm,
					mbcell: mbCell(
                    cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
                )
				VlongTwoShort(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				FourShort(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoVLong(
					pm: pm,
					mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				
			}
		}
	}.environment(ProjectModel())
}
