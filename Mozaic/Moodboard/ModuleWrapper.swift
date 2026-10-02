import SwiftUI

struct ModuleWrapper: View {
	@Environment(ProjectModel.self) private var pm
	var mbCell: MbCell
	@State private var isPickingModule: Bool = false

	var body: some View {
		VStack {
			switch pm.board.rows[mbCell.index].module {
				case .vlong2short:
					Vlong2Short(pm: pm, mbCell: mbCell)
				case .twoshorthlong:
					TwoShortHlong(pm: pm, mbCell: mbCell)
				case .twoshortvlong:
					TwoShortVlong(pm: pm, mbCell: mbCell)
				case .vlongtwoshort:
					VlongTwoShort(pm: pm, mbCell: mbCell)
				case .fourshort:
					FourShort(pm: pm, mbCell: mbCell)
				case .onecell:
					OneCell(pm: pm, mbCell: mbCell)
				case .twovlong:
					TwoVLong(pm: pm, mbCell: mbCell)
				case .twohlong:
					TwoHLong(pm: pm, mbCell: mbCell)
			}
		}
		.frame(width: 310, height: 310)
		.overlay {
			if isPickingModule {
				ModulePicker(selection: setModule, dismiss: { isPickingModule = false })
					.frame(width: 300, height: 300)
			}
		}
		.onLongPressGesture(minimumDuration: 0.50) {
			isPickingModule = true
		}
	}

	private func setModule(_ module: Module) {
		pm.withUndo("Change Layout") { $0.setModule(module, row: mbCell.index) }
		isPickingModule = false
	}
}

#Preview {
	let cellWidth: CGFloat = 155
	let twoCellWidth: CGFloat = 155 * 2
	ModuleWrapper(
		mbCell: MbCell(
			cellSpacing: 10,
			cell: cellWidth,
			twoCell: (twoCellWidth + 10) ,
			slots: [nil, nil, nil, nil],
			index: 0
	)).environment(ProjectModel())
}
