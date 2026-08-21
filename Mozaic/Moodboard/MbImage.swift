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
			if let image = pm.image(for: imageID) {
				image
					.resizable()
					.aspectRatio(contentMode: .fill)
			} else {
				Image("OGbgImg")
					.resizable()
					.aspectRatio(contentMode: .fill)
			}
		}
		.frame(width: imgWidth, height: imgHeight)
		.background(Material.thin)
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
