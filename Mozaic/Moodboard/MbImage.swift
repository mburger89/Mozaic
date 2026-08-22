import SwiftUI

struct MbImage: View {
	var pm: ProjectModel
	@State private var isTarget: Bool = false
	var imageID: UUID?
	let imgWidth: CGFloat
	let imgHeight: CGFloat
	var indexes: [Int]

	var body: some View {
		Group {
			if let imageID, let image = pm.image(for: imageID) {
				image
					.resizable()
					.aspectRatio(contentMode: .fill)
					.draggable(DroppedImage.reference(imageID)) {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: imgWidth / 2, height: imgHeight / 2)
							.clipShape(.rect(cornerRadius: pm.cellRadius))
					}
			} else {
				Image("OGbgImg")
					.resizable()
					.aspectRatio(contentMode: .fill)
			}
		}
		.frame(width: imgWidth, height: imgHeight)
		.background(Material.thin)
		.dropDestination(for: DroppedImage.self) { items, _ in
			guard let first = items.first else { return false }
			do {
				return try pm.accept(first, row: indexes[0], slot: indexes[1])
			} catch {
				print("Drop rejected:", error)
				return false
			}
		} isTargeted: { isTarget = $0 }
		.contentShape(.rect(cornerRadius: pm.cellRadius).inset(by: 20))
		.overlay {
			RoundedRectangle(cornerRadius: pm.cellRadius)
				.stroke((isTarget ? .blue : .clear), lineWidth: 3.0)
				.frame(width: imgWidth, height: imgHeight)
		}
		.clipShape(.rect(cornerRadius: pm.cellRadius))
	}
}

#Preview {
	MbImage(pm: ProjectModel(), imageID: nil, imgWidth: 150.0, imgHeight: 300.0, indexes: [0, 0])
}
