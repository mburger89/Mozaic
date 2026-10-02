import SwiftUI
import UniformTypeIdentifiers

/// Already-rendered PNG bytes, wrapped for `fileExporter`.
///
/// Export needs a concrete `FileDocument`, so unlike `BoardShareItem` this
/// does hold the pixels — but it is now built in the Export button's action
/// rather than during `body`, so the render runs once per export instead of
/// twice per view update.
struct MoodBoardImage: FileDocument {
    let data: Data
    static var readableContentTypes: [UTType] { [.png] }
    init(data: Data) {
        self.data = data
    }
    init(configuration: FileDocumentReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: FileDocumentWriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}
