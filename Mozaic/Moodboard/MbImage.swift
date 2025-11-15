import SwiftUI

struct MbImage: View {
//	@Environment(ProjectModel.self) private var pm
	var pm: ProjectModel
	@State private var isTarget: Bool = false
	var imgSlot: Image
	let imgWidth: CGFloat
	let imgHeight: CGFloat
	var indexes: [Int]
	var body: some View {
		imgSlot
			.resizable()
			.aspectRatio(contentMode: .fill)
			.frame(width: imgWidth, height: imgHeight)
			.background(Material.thin)
			.contentShape(RoundedRectangle(cornerRadius: pm.cellRadius).inset(by: 20))
			.dropDestination(for: Image.self, action: {items, location in
				pm.writeToModel(items: items, indexs: indexes)
				return true
			}, isTargeted: { target in
				isTarget = target
			})
			.draggable(imgSlot) {
					imgSlot
						.resizable()
						.aspectRatio(contentMode: .fill)
						.frame(width: imgWidth / 2, height: imgHeight / 2)
						.contentShape(.dragPreview, RoundedRectangle(cornerRadius: pm.cellRadius))
						.mask(RoundedRectangle(cornerRadius: pm.cellRadius))
			}
			.overlay {
				RoundedRectangle(cornerRadius: pm.cellRadius)
					.stroke((isTarget ? .blue : .clear), lineWidth: 3.0)
					.frame(width: imgWidth, height: imgHeight)
			}
			.clipShape(RoundedRectangle(cornerRadius: pm.cellRadius))
			.mask(RoundedRectangle(cornerRadius: pm.cellRadius))
	}
}

#Preview {
	MbImage(
		pm: ProjectModel(),
		imgSlot: Image("OGbgImg"),
		imgWidth: 150.0,
		imgHeight: (150.0 * 2),
		indexes: [0,0]
	).environment(ProjectModel())
}
