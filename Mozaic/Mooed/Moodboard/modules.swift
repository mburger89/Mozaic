//
//  modules.swift
//  Flo Ai
//
//  Created by Max Burger on 8/10/24.
//

import SwiftUI

struct mbCell {
	let cellSpacing: CGFloat
	let cell: CGFloat
	let twoCell: CGFloat
	var img: [Image]
	var index: Int
}


struct Vlong2Short: View {
	var mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 0])
			VStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
				mbImage(imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
			}
		}
	}
}

struct TwoShortHlong: View {
	var mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			HStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
			}
			mbImage(imgSlot: mbcell.img[2], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
		}
	}
}

struct TwoShortVlong: View {
	var mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			VStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
			}
			mbImage(imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 2])
		}
	}
}

struct VlongTwoShort: View {
	var mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			mbImage(imgSlot: mbcell.img[2], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
			HStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
				mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
			}
		}
	}
}

struct FourShort: View {
	var mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			VStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 0])
				mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 1])
			}
			VStack(spacing: mbcell.cellSpacing) {
				mbImage(imgSlot: mbcell.img[2], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 2])
				mbImage(imgSlot: mbcell.img[3], imgWidth: mbcell.cell, imgHeight: mbcell.cell, indexes: [mbcell.index, 3])
			}
		}
	}
}

struct OneCell: View {
	var mbcell: mbCell
	var body: some View {
		mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.twoCell, imgHeight: mbcell.twoCell, indexes: [mbcell.index, 0])
	}
}

struct TwoVLong: View {
	var mbcell: mbCell
	var body: some View {
		HStack(spacing: mbcell.cellSpacing) {
			mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index,0])
			mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.cell, imgHeight: mbcell.twoCell, indexes: [mbcell.index,1])
		}
	}
}

struct TwoHLong: View {
	var mbcell: mbCell
	var body: some View {
		VStack(spacing: mbcell.cellSpacing) {
			mbImage(imgSlot: mbcell.img[0], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index,0])
			mbImage(imgSlot: mbcell.img[1], imgWidth: mbcell.twoCell, imgHeight: mbcell.cell, indexes: [mbcell.index,1])
		}
	}
}

#Preview {
	ScrollView {
		HStack(spacing: 10.0) {
			VStack(spacing: 10.0){
				Vlong2Short(
					mbcell: mbCell(cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoShortHlong(mbcell:mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				OneCell(mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoHLong(mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				
			}
			VStack(spacing: 10.0){
				TwoShortVlong(mbcell: mbCell(cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				VlongTwoShort(mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				FourShort(mbcell: mbCell(
					cellSpacing: 10.0,
					cell: 150.0,
					twoCell: (150 * 2) + 10,
					img: [Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg"),Image("OGbgImg")],
					index: 0
					)
				)
				TwoVLong(mbcell: mbCell(
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
