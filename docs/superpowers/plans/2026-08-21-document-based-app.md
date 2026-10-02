# Document-Based Mozaic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn Mozaic into a document-based app so a moodboard can be saved as a `.mozaic` file, handed to someone else, and edited by them.

**Architecture:** A `.mozaic` package (a `FileWrapper` directory) holds a small JSON manifest plus one image file per stored image, in the image's own format. `ProjectModel` stops holding decoded `Image` values and holds `UUID`s instead, resolved through an `ImageStore` that owns the bytes and memoizes decoding. `MozaicDocument: ReferenceFileDocument` bridges the two, and `MozaicApp` swaps `WindowGroup` for `DocumentGroup`.

**Tech Stack:** Swift 6 language mode with `MainActor` default isolation, SwiftUI, Swift Testing, ImageIO (for format-preserving encode/decode), `xcodeproj` Ruby gem (for project file edits). No third-party Swift dependencies.

**Spec:** `docs/superpowers/specs/2026-08-21-document-based-app-design.md`

## Global Constraints

- **Style rules are mandatory:** `AGENTS.md` in the repo root. The codebase is currently clean of its "Never/Always" API violations — keep it that way.
- **Swift 6 language mode**, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, `SWIFT_APPROACHABLE_CONCURRENCY = YES`. Almost nothing needs an explicit `@MainActor`; anything moved *off* the main actor must carry `Sendable` values across the boundary.
- **Deployment targets:** iOS 26.0 / macOS 26.0 (app target). Test targets are on 17.5 / 14.5.
- **The app target is iPad-only** (`TARGETED_DEVICE_FAMILY = 2`). An iPhone destination fails with "doesn't match any of Mozaic.app's targeted device families".
- **Avoid UIKit/AppKit** where a cross-platform API exists. Image work goes through **ImageIO** (`CGImageSource`/`CGImageDestination`), which is available on both platforms — not `UIImage`/`NSImage` — except at the final hop into SwiftUI `Image`, where a platform type is unavoidable.
- **Every new `.swift` file must be added to its target** via `Scripts/add_sources.rb` (built in Task 1). `project.pbxproj` is `objectVersion = 56` with an explicit file list and no synchronized folders: **a file that is not wired in compiles nowhere and fails silently.** This is not hypothetical — it is exactly why the test suite has never run.
- **`Module` raw values are a persistence contract.** `vlong2short`, `twoshorthlong`, `twoshortvlong`, `vlongtwoshort`, `fourshort`, `onecell`, `twovlong`, `twohlong`. Never change them.
- **Image bytes are immutable per ID.** Once stored under a UUID, an image's bytes never change; any edit produces a new UUID. Task 5's incremental save depends on this invariant.

**Build commands:**

```bash
# macOS
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' build

# iPad
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build

# Unit tests
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test

# One test
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test \
  -only-testing:MozaicTests/BoardManifestTests/boardFileRoundTrips
```

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Scripts/add_sources.rb` | Adds source files to Xcode targets. Used by every later task. |
| `Mozaic/Document/BoardManifest.swift` | The persisted value types: `BoardFile`, `Board`, `Row`, `StoredImageMeta`, `ImageQuality`. No behaviour beyond `Codable`. |
| `Mozaic/Document/ImageCoder.swift` | Content-type sniffing, downscaling, same-format re-encode. Pure functions over `Data`. |
| `Mozaic/Document/ImageStore.swift` | Owns image bytes; memoizes decoded `Image`s. The only type views ask for images. |
| `Mozaic/Document/UTType+Mozaic.swift` | `.mozaicBoard` and `.mozaicImageReference` type declarations. |
| `Mozaic/Document/MozaicDocument.swift` | `ReferenceFileDocument`: package read/write, incremental save, garbage collection. |
| `Mozaic/Moodboard/DroppedImage.swift` | The `Transferable` drag payload replacing bare `Image`. |

**Modified:** `MozaicApp.swift`, `ContentView.swift`, `ProjectModel.swift`, `MbImage.swift`, `Modules.swift`, `ModWrapper.swift`, `MoodBoardMain.swift`, `bottomBar.swift`, `BoardSettings.swift`, `Info.plist`, `Mozaic.xctestplan`, `project.pbxproj`.

**Deleted:** `Mozaic/Models/MDataModel.swift`.

---

### Task 1: Make the test suite runnable

Nothing in this plan is verifiable until tests run. They currently do not, on either platform — not because of signing, but because `MozaicTests.swift`, `MozaicUITests.swift`, and `MozaicUITestsLaunchTests.swift` have no `PBXFileReference` and no build-phase entry. Both test targets compile zero files and produce bundles with no executable. macOS reports this as `Command CodeSign failed` (signing an empty bundle), which is why it looked like a provisioning problem.

**Files:**
- Create: `Scripts/add_sources.rb`
- Create: `MozaicTests/SmokeTests.swift`
- Delete: `MozaicTests/MozaicTests.swift`
- Modify: `Mozaic.xctestplan`
- Modify: `Mozaic.xcodeproj/project.pbxproj` (via script)

**Interfaces:**
- Produces: `Scripts/add_sources.rb`, invoked as
  `ruby Scripts/add_sources.rb <TargetName> <group/path> <file.swift> [more.swift...]`
  Every later task uses it. It is idempotent — re-adding an existing file is a no-op.

- [x] **Step 1: Write the file-adding script**

Create `Scripts/add_sources.rb`:

```ruby
#!/usr/bin/env ruby
# Adds Swift source files to an Xcode target's compile phase.
#
#   ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/SmokeTests.swift
#
# Args: <target> <group path, slash separated> <file paths...>
# Idempotent: a file already in the target is skipped.
require "xcodeproj"

target_name, group_path, *files = ARGV
abort "usage: add_sources.rb <target> <group> <files...>" if files.empty?

project = Xcodeproj::Project.open("Mozaic.xcodeproj")
target  = project.targets.find { |t| t.name == target_name }
abort "no such target: #{target_name}" unless target

# Walk/create the group chain, e.g. "Mozaic/Document"
group = project.main_group
group_path.split("/").each do |name|
  group = group.find_subpath(name, true).tap { |g| g.set_source_tree("<group>") }
end

added = []
files.each do |path|
  abort "missing file: #{path}" unless File.exist?(path)
  basename = File.basename(path)

  existing = group.files.find { |f| f.display_name == basename }
  ref = existing || group.new_reference(File.expand_path(path))

  if target.source_build_phase.files_references.include?(ref)
    puts "  = #{basename} (already in #{target_name})"
    next
  end
  target.add_file_references([ref])
  added << basename
end

project.save
puts added.empty? ? "no changes" : "added to #{target_name}: #{added.join(', ')}"
```

This script was validated against a throwaway copy of the project while the
plan was written: it adds correctly, is idempotent on a second run, leaves
`plutil -lint` clean, and writes a *relative* path (`sourceTree = "<group>"`)
rather than an absolute one, so the project stays portable.

- [x] **Step 2: Confirm the tests really are absent before changing anything**

Run:
```bash
ruby -e 'require "xcodeproj"; Xcodeproj::Project.open("Mozaic.xcodeproj").targets.each { |t| puts "#{t.name}: #{t.source_build_phase.files.count} sources" }'
```
Expected: `Mozaic: 11 sources`, `MozaicTests: 0 sources`, `MozaicUITests: 0 sources`.

- [x] **Step 3: Replace the XCTest boilerplate with a Swift Testing smoke test**

`MozaicTests/MozaicTests.swift` is empty XCTest scaffolding with no assertions. Delete it and create `MozaicTests/SmokeTests.swift`:

```swift
import Testing
@testable import Mozaic

/// Proves the test target compiles, links against Mozaic, and runs.
/// If this fails, nothing else in the suite can be trusted.
@Suite struct SmokeTests {
	@Test func testTargetCanSeeTheAppModule() {
		#expect(Module.vlong2short.rawValue == "vlong2short")
	}
}
```

```bash
rm MozaicTests/MozaicTests.swift
```

- [x] **Step 4: Wire the test files into their targets**

```bash
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/SmokeTests.swift
ruby Scripts/add_sources.rb MozaicUITests MozaicUITests \
  MozaicUITests/MozaicUITests.swift MozaicUITests/MozaicUITestsLaunchTests.swift
plutil -lint Mozaic.xcodeproj/project.pbxproj
```
Expected: files added, and `project.pbxproj: OK`.

- [x] **Step 5: Drop UI tests from the default test plan**

The UI tests are unmodified boilerplate and their runner is what trips macOS signing. Keeping them in the default plan makes every TDD cycle slow and flaky. Remove that entry from `Mozaic.xctestplan`'s `testTargets` array, leaving only `MozaicTests`. Leave the target and its files in place so UI tests can be re-enabled later.

- [x] **Step 6: Run the suite**

Run: `xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test 2>&1 | grep -E "Executed|TEST (SUCCEEDED|FAILED)|error:"`

Expected: **TEST SUCCEEDED**, with the smoke test executed. This is the first time the suite has ever run — if it still fails, stop and diagnose before proceeding. Do not work around it by skipping tests.

- [x] **Step 7: Confirm the app still builds on both platforms**

Run both `build` commands from Global Constraints. Expected: `** BUILD SUCCEEDED **` twice.

- [x] **Step 8: Commit**

```bash
git add Scripts/ MozaicTests/ Mozaic.xctestplan Mozaic.xcodeproj/project.pbxproj
git commit -m "test: wire test files into their targets so the suite can run

The three test source files existed on disk but had no PBXFileReference and
no PBXSourcesBuildPhase entry, so both test targets compiled zero files and
produced bundles with no executable. iPadOS reported a missing test-bundle
executable; macOS reported CodeSign failure while signing the empty bundle,
which is why this read as a provisioning problem. The suite had never run.

Adds Scripts/add_sources.rb so later work cannot repeat the mistake, moves
the empty XCTest boilerplate to a Swift Testing smoke test, and drops the
boilerplate UI tests from the default test plan to keep the cycle fast."
```

---

### Task 2: The persisted format types

**Files:**
- Create: `Mozaic/Document/BoardManifest.swift`
- Create: `MozaicTests/BoardManifestTests.swift`

**Interfaces:**
- Produces: `ImageQuality`, `StoredImageMeta`, `Row`, `Board`, `BoardFile`, and `BoardFile.currentFormatVersion`. Task 5 encodes/decodes `BoardFile`; Task 6 holds a `Board` inside `ProjectModel`.

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/BoardManifestTests.swift`:

```swift
import Foundation
import Testing
@testable import Mozaic

@Suite struct BoardManifestTests {
	private func sampleBoard() -> Board {
		let a = UUID(), b = UUID()
		return Board(
			projectName: "Studio",
			createdBy: "Max",
			projectDescription: "",
			showBoardInfo: true,
			gridGap: 12,
			cellRadius: 8,
			quality: .standard,
			rows: [Row(id: UUID(), module: .fourshort, slots: [a, nil, b, nil])],
			tray: [b]
		)
	}

	@Test func boardFileRoundTrips() throws {
		let file = BoardFile(board: sampleBoard(), images: [
			StoredImageMeta(id: UUID(), contentType: "public.jpeg", pixelWidth: 1000, pixelHeight: 750)
		])
		let data = try JSONEncoder().encode(file)
		let decoded = try JSONDecoder().decode(BoardFile.self, from: data)

		#expect(decoded.board.projectName == "Studio")
		#expect(decoded.board.rows.count == 1)
		#expect(decoded.board.rows[0].module == .fourshort)
		#expect(decoded.formatVersion == BoardFile.currentFormatVersion)
	}

	@Test func emptySlotsSurviveEncoding() throws {
		var board = sampleBoard()
		board.rows = [Row(id: UUID(), module: .onecell, slots: [nil, nil, nil, nil])]
		let data = try JSONEncoder().encode(BoardFile(board: board, images: []))
		let decoded = try JSONDecoder().decode(BoardFile.self, from: data)

		#expect(decoded.board.rows[0].slots.count == 4)
		#expect(decoded.board.rows[0].slots.allSatisfy { $0 == nil })
		#expect(decoded.board.tray.isEmpty == false)
	}

	@Test func moduleRawValuesArePinned() {
		// These strings are the on-disk format. Changing one silently breaks
		// every saved board. See AGENTS.md and the design doc.
		#expect(Module.vlong2short.rawValue == "vlong2short")
		#expect(Module.twoshorthlong.rawValue == "twoshorthlong")
		#expect(Module.twoshortvlong.rawValue == "twoshortvlong")
		#expect(Module.vlongtwoshort.rawValue == "vlongtwoshort")
		#expect(Module.fourshort.rawValue == "fourshort")
		#expect(Module.onecell.rawValue == "onecell")
		#expect(Module.twovlong.rawValue == "twovlong")
		#expect(Module.twohlong.rawValue == "twohlong")
		#expect(Module.allCases.count == 8)
	}

	@Test func unknownModuleFallsBackToDefault() {
		#expect(Module(storedValue: "not-a-real-module") == .vlong2short)
		#expect(Module(storedValue: "fourshort") == .fourshort)
	}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test -only-testing:MozaicTests/BoardManifestTests 2>&1 | grep -E "error:|TEST"`

Expected: compile failure — `cannot find 'Board' in scope`.

- [x] **Step 3: Write the types**

Create `Mozaic/Document/BoardManifest.swift`:

```swift
import Foundation

/// How much fidelity a document keeps when importing images.
///
/// This governs import only. Changing it does not alter images already
/// stored — see the Reduce File Size command.
enum ImageQuality: String, Codable, CaseIterable, Sendable {
	/// Downscale to `standardMaxPixel` on the longest edge, re-encoding to
	/// the image's own format.
	case standard
	/// Store original bytes verbatim.
	case full

	/// The largest module renders a 310pt slot, so this covers a 3x export
	/// of even the biggest cell with headroom. Any image can be dragged into
	/// any slot, so this targets the largest slot, not the one it landed in.
	static let standardMaxPixel = 1000
}

/// What the manifest records about one stored image. The bytes live in the
/// package's `images/` directory, not here.
struct StoredImageMeta: Codable, Hashable, Sendable {
	var id: UUID
	/// UTI string, e.g. `public.jpeg`. Sniffed from the bytes, never from a
	/// filename extension.
	var contentType: String
	var pixelWidth: Int
	var pixelHeight: Int
}

/// One row of the board: a layout plus four slots referencing images by ID.
///
/// Layouts using fewer than four images ignore the trailing slots.
struct Row: Codable, Hashable, Identifiable, Sendable {
	var id: UUID
	var module: Module
	/// Always four entries. `nil` is an empty slot.
	var slots: [UUID?]

	static func empty(module: Module = .vlong2short) -> Row {
		Row(id: UUID(), module: module, slots: [nil, nil, nil, nil])
	}
}

/// Everything about a board except the image bytes.
struct Board: Codable, Hashable, Sendable {
	var projectName: String = "Untitled Project"
	var createdBy: String = "Anonymous"
	var projectDescription: String = ""
	var showBoardInfo: Bool = true
	var gridGap: Double = 10.0
	var cellRadius: Double = 10.0
	var quality: ImageQuality = .standard
	/// Variable-length by design, though the UI renders exactly `defaultRowCount`.
	var rows: [Row] = (0..<Board.defaultRowCount).map { _ in .empty() }
	var tray: [UUID] = []

	static let defaultRowCount = 6
	/// Bounds tray membership only, never the image store. Evicting an
	/// unplaced image can never remove one that is on the board.
	static let trayLimit = 30

	/// Every image ID reachable from this board. Anything absent from this
	/// set is garbage and is not written on save.
	var referencedImageIDs: Set<UUID> {
		Set(rows.flatMap { $0.slots.compactMap { $0 } }).union(tray)
	}
}

/// The root object encoded to `manifest.json`.
struct BoardFile: Codable, Sendable {
	static let currentFormatVersion = 1

	var formatVersion: Int
	var board: Board
	var images: [StoredImageMeta]

	init(formatVersion: Int = BoardFile.currentFormatVersion,
		 board: Board,
		 images: [StoredImageMeta]) {
		self.formatVersion = formatVersion
		self.board = board
		self.images = images
	}
}
```

- [x] **Step 4: Wire the files into their targets and run the tests**

```bash
ruby Scripts/add_sources.rb Mozaic Mozaic/Document Mozaic/Document/BoardManifest.swift
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/BoardManifestTests.swift
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test \
  -only-testing:MozaicTests/BoardManifestTests 2>&1 | grep -E "Executed|TEST|error:"
```
Expected: PASS, 4 tests executed.

- [x] **Step 5: Commit**

```bash
git add Mozaic/Document/BoardManifest.swift MozaicTests/BoardManifestTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add persisted board format types

Board, Row, StoredImageMeta, ImageQuality and the BoardFile root, with
rows and tray referencing images by UUID rather than embedding bytes.
Pins Module's raw values under test, since they are now the on-disk format."
```

---

### Task 3: Format-preserving image coder

Mozaic never converts between formats. A JPEG stays a JPEG. Re-encoding happens only as a side effect of downscaling, and always back to the source's own type. Everything here goes through ImageIO so one implementation serves both platforms.

**Files:**
- Create: `Mozaic/Document/ImageCoder.swift`
- Create: `MozaicTests/ImageCoderTests.swift`

**Interfaces:**
- Produces:
  - `ImageCoder.contentType(of: Data) -> UTType?`
  - `ImageCoder.pixelSize(of: Data) -> CGSize?`
  - `ImageCoder.isRoundTrippable(_ type: UTType) -> Bool`
  - `ImageCoder.prepared(_ data: Data, quality: ImageQuality) throws -> PreparedImage`
  - `struct PreparedImage { var data: Data; var contentType: UTType; var pixelWidth: Int; var pixelHeight: Int }`
  - `enum ImageCoderError: Error { case unrecognizedFormat, decodeFailed, encodeFailed }`
- Task 4 calls `prepared(_:quality:)` on every import.

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/ImageCoderTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@Suite struct ImageCoderTests {
	/// Builds a real encoded image of a given size and type, so tests exercise
	/// ImageIO rather than a stub.
	private func makeImage(width: Int, height: Int, type: UTType) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: height,
							bitsPerComponent: 8, bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
		let cg = ctx.makeImage()!

		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, cg, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func sniffsContentTypeFromBytesNotExtension() throws {
		let png = try makeImage(width: 10, height: 10, type: .png)
		let jpeg = try makeImage(width: 10, height: 10, type: .jpeg)

		#expect(ImageCoder.contentType(of: png) == .png)
		#expect(ImageCoder.contentType(of: jpeg) == .jpeg)
	}

	@Test func rejectsNonImageData() {
		#expect(ImageCoder.contentType(of: Data("not an image".utf8)) == nil)
	}

	@Test func readsPixelSize() throws {
		let data = try makeImage(width: 640, height: 480, type: .png)
		let size = try #require(ImageCoder.pixelSize(of: data))
		#expect(Int(size.width) == 640)
		#expect(Int(size.height) == 480)
	}

	@Test func standardQualityPreservesFormat() throws {
		let jpeg = try makeImage(width: 2000, height: 1000, type: .jpeg)
		let result = try ImageCoder.prepared(jpeg, quality: .standard)

		#expect(result.contentType == .jpeg)          // JPEG in, JPEG out
		#expect(result.pixelWidth == 1000)            // capped on longest edge
		#expect(result.pixelHeight == 500)            // aspect ratio preserved
	}

	@Test func standardQualityDoesNotUpscale() throws {
		let png = try makeImage(width: 300, height: 200, type: .png)
		let result = try ImageCoder.prepared(png, quality: .standard)

		#expect(result.pixelWidth == 300)
		#expect(result.pixelHeight == 200)
	}

	@Test func imageAlreadyUnderCapIsStoredVerbatim() throws {
		let png = try makeImage(width: 300, height: 200, type: .png)
		let result = try ImageCoder.prepared(png, quality: .standard)

		// Byte-identical: never re-encode an image that needs no resizing,
		// which would lose quality for nothing.
		#expect(result.data == png)
	}

	@Test func fullQualityStoresOriginalBytesVerbatim() throws {
		let jpeg = try makeImage(width: 2000, height: 1000, type: .jpeg)
		let result = try ImageCoder.prepared(jpeg, quality: .full)

		#expect(result.data == jpeg)
		#expect(result.pixelWidth == 2000)
	}

	@Test func nonRoundTrippableFormatIsStoredVerbatimAndExemptFromCap() throws {
		// GIF is accepted by the file importer but has no sensible
		// single-frame re-encode, so it bypasses downscaling entirely.
		#expect(ImageCoder.isRoundTrippable(.gif) == false)
		#expect(ImageCoder.isRoundTrippable(.png))
		#expect(ImageCoder.isRoundTrippable(.jpeg))
	}

	@Test func unrecognizedFormatThrows() {
		#expect(throws: ImageCoderError.self) {
			try ImageCoder.prepared(Data("nope".utf8), quality: .standard)
		}
	}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:MozaicTests/ImageCoderTests`
Expected: compile failure — `cannot find 'ImageCoder' in scope`.

- [x] **Step 3: Write the coder**

Create `Mozaic/Document/ImageCoder.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageCoderError: Error, Equatable {
	case unrecognizedFormat
	case decodeFailed
	case encodeFailed
}

/// An image ready to be stored: bytes, the format they are in, and dimensions.
struct PreparedImage: Sendable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}

/// Format-preserving image handling, built on ImageIO so one implementation
/// serves macOS and iPadOS.
///
/// The rule throughout: Mozaic never converts between formats. Re-encoding
/// happens only when downscaling requires it, and always to the source's own
/// content type.
enum ImageCoder {
	/// Lossy-compression quality used when a downscale forces a re-encode.
	static let recompressionQuality = 0.85

	/// Identifies format from the bytes themselves. A file whose extension
	/// disagrees with its contents must not be believed.
	static func contentType(of data: Data) -> UTType? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil),
			  let identifier = CGImageSourceGetType(source) as String? else { return nil }
		return UTType(identifier)
	}

	static func pixelSize(of data: Data) -> CGSize? {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil),
			  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
			  let width = properties[kCGImagePropertyPixelWidth] as? Int,
			  let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
		return CGSize(width: width, height: height)
	}

	/// Whether this platform can write the given type, so a downscale can
	/// round-trip back into it.
	static func isRoundTrippable(_ type: UTType) -> Bool {
		guard let writable = CGImageDestinationCopyTypeIdentifiers() as? [String] else { return false }
		// GIF is nominally writable but has no sensible single-frame
		// re-encode, so it is excluded deliberately.
		guard type != .gif else { return false }
		return writable.contains(type.identifier)
	}

	/// Prepares imported bytes for storage under the document's quality setting.
	///
	/// Returns the original bytes untouched whenever no resize is needed —
	/// in `.full` mode, when the image is already within the cap, or when the
	/// format cannot be round-tripped.
	static func prepared(_ data: Data, quality: ImageQuality) throws -> PreparedImage {
		guard let type = contentType(of: data), let size = pixelSize(of: data) else {
			throw ImageCoderError.unrecognizedFormat
		}

		let verbatim = PreparedImage(data: data,
									 contentType: type,
									 pixelWidth: Int(size.width),
									 pixelHeight: Int(size.height))

		let cap = ImageQuality.standardMaxPixel
		let longestEdge = Int(max(size.width, size.height))

		guard quality == .standard, longestEdge > cap, isRoundTrippable(type) else {
			return verbatim
		}

		guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
			throw ImageCoderError.decodeFailed
		}
		let options: [CFString: Any] = [
			kCGImageSourceCreateThumbnailFromImageAlways: true,
			kCGImageSourceCreateThumbnailWithTransform: true,
			kCGImageSourceThumbnailMaxPixelSize: cap,
		]
		guard let scaled = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
			throw ImageCoderError.decodeFailed
		}

		let output = NSMutableData()
		guard let destination = CGImageDestinationCreateWithData(
			output, type.identifier as CFString, 1, nil
		) else {
			throw ImageCoderError.encodeFailed
		}
		CGImageDestinationAddImage(destination, scaled, [
			kCGImageDestinationLossyCompressionQuality: recompressionQuality
		] as CFDictionary)

		// If re-encoding fails, keeping the original is better than losing
		// the image.
		guard CGImageDestinationFinalize(destination) else { return verbatim }

		return PreparedImage(data: output as Data,
							 contentType: type,
							 pixelWidth: scaled.width,
							 pixelHeight: scaled.height)
	}
}
```

- [x] **Step 4: Wire up and run**

```bash
ruby Scripts/add_sources.rb Mozaic Mozaic/Document Mozaic/Document/ImageCoder.swift
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/ImageCoderTests.swift
xcodebuild ... test -only-testing:MozaicTests/ImageCoderTests
```
Expected: PASS, 9 tests.

- [x] **Step 5: Commit**

```bash
git add Mozaic/Document/ImageCoder.swift MozaicTests/ImageCoderTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add format-preserving image coder

Sniffs content type from bytes rather than filename, downscales to the
Standard cap only when needed, and re-encodes to the source's own format.
Returns original bytes verbatim in Full mode, when already under the cap,
and for formats like GIF that cannot round-trip. Built on ImageIO so one
implementation covers macOS and iPadOS."
```

---

### Task 4: ImageStore

The single owner of image bytes, and the only thing views ask for images. **The memoized decode cache is the most important part of this task.** `ProjectModel` currently holds decoded `Image`s, which is why rendering is cheap; commit 6115747 ("Optomization to fix langyness…") shows this path has already caused problems once. Decoding per frame instead of per session would reintroduce that lag in a worse form.

**Files:**
- Create: `Mozaic/Document/ImageStore.swift`
- Create: `MozaicTests/ImageStoreTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor @Observable final class ImageStore`
  - `init(storedImages: [UUID: StoredImage] = [:])`
  - `struct StoredImage: Sendable { var data: Data; var contentType: UTType; var pixelWidth: Int; var pixelHeight: Int }`
  - `func add(_ data: Data, quality: ImageQuality) throws -> UUID`
  - `func image(for: UUID) -> Image?` — memoized
  - `func stored(for: UUID) -> StoredImage?`
  - `var storedImages: [UUID: StoredImage]` (read-only outside the store)
  - `func metadata(for ids: Set<UUID>) -> [StoredImageMeta]`
  - `func filename(for id: UUID) -> String?`
- Task 5 reads `storedImages` for the snapshot; Task 6's views call `image(for:)`.

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/ImageStoreTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ImageStoreTests {
	private func makeImage(width: Int = 40, height: Int = 30, type: UTType = .png) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: height,
							bitsPerComponent: 8, bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func addStoresAndReturnsAnID() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)

		let stored = try #require(store.stored(for: id))
		#expect(stored.contentType == .png)
		#expect(stored.pixelWidth == 40)
		#expect(stored.pixelHeight == 30)
	}

	@Test func decodesToAnImage() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)
		#expect(store.image(for: id) != nil)
	}

	@Test func unknownIDDecodesToNil() {
		#expect(ImageStore().image(for: UUID()) == nil)
	}

	@Test func decodingIsMemoized() throws {
		let store = ImageStore()
		let id = try store.add(try makeImage(), quality: .standard)

		#expect(store.decodeCountForTesting == 0)
		_ = store.image(for: id)
		#expect(store.decodeCountForTesting == 1)
		_ = store.image(for: id)
		_ = store.image(for: id)
		// Still 1: repeated access must not re-decode. This is the guard
		// against reintroducing the drag/drop lag of commit 6115747.
		#expect(store.decodeCountForTesting == 1)
	}

	@Test func filenameUsesTheImagesOwnExtension() throws {
		let store = ImageStore()
		let png = try store.add(try makeImage(type: .png), quality: .standard)
		let jpeg = try store.add(try makeImage(type: .jpeg), quality: .standard)

		#expect(try #require(store.filename(for: png)).hasSuffix(".png"))
		#expect(try #require(store.filename(for: jpeg)).hasSuffix(".jpeg"))
	}

	@Test func metadataCoversOnlyRequestedIDs() throws {
		let store = ImageStore()
		let kept = try store.add(try makeImage(), quality: .standard)
		let dropped = try store.add(try makeImage(width: 50), quality: .standard)

		let meta = store.metadata(for: [kept])
		#expect(meta.count == 1)
		#expect(meta[0].id == kept)
		#expect(store.stored(for: dropped) != nil)   // still in memory, just not requested
	}

	@Test func rejectsNonImageData() {
		let store = ImageStore()
		#expect(throws: ImageCoderError.self) {
			try store.add(Data("nope".utf8), quality: .standard)
		}
	}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:MozaicTests/ImageStoreTests`
Expected: `cannot find 'ImageStore' in scope`.

- [x] **Step 3: Write the store**

Create `Mozaic/Document/ImageStore.swift`:

```swift
import Foundation
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Image bytes plus the facts needed to write and lay them out.
///
/// Bytes are immutable once stored under an ID: any edit produces a new ID.
/// `MozaicDocument`'s incremental save relies on this.
struct StoredImage: Sendable {
	var data: Data
	var contentType: UTType
	var pixelWidth: Int
	var pixelHeight: Int
}

/// Owns every image in a document and hands views decoded `Image` values.
///
/// Decoding is memoized. Views resolve images by ID on every render pass, so
/// decoding per call would put a full PNG decode in the render loop.
@MainActor
@Observable
final class ImageStore {
	private(set) var storedImages: [UUID: StoredImage]

	/// Not observed: filling the cache must not invalidate views.
	@ObservationIgnored private var decoded: [UUID: Image] = [:]
	/// Test-only counter proving memoization holds.
	@ObservationIgnored private(set) var decodeCountForTesting = 0

	init(storedImages: [UUID: StoredImage] = [:]) {
		self.storedImages = storedImages
	}

	func stored(for id: UUID) -> StoredImage? { storedImages[id] }

	/// Imports bytes under the document's quality setting and returns the new ID.
	@discardableResult
	func add(_ data: Data, quality: ImageQuality) throws -> UUID {
		let prepared = try ImageCoder.prepared(data, quality: quality)
		let id = UUID()
		storedImages[id] = StoredImage(data: prepared.data,
									   contentType: prepared.contentType,
									   pixelWidth: prepared.pixelWidth,
									   pixelHeight: prepared.pixelHeight)
		return id
	}

	/// Inserts an image whose ID is already known, used when reading a document.
	func insert(_ image: StoredImage, for id: UUID) {
		storedImages[id] = image
		decoded[id] = nil
	}

	func remove(_ id: UUID) {
		storedImages[id] = nil
		decoded[id] = nil
	}

	/// The decoded image, decoded at most once per ID per session.
	func image(for id: UUID) -> Image? {
		if let cached = decoded[id] { return cached }
		guard let stored = storedImages[id] else { return nil }

		decodeCountForTesting += 1
		#if os(macOS)
		guard let native = NSImage(data: stored.data) else { return nil }
		let image = Image(nsImage: native)
		#else
		guard let native = UIImage(data: stored.data) else { return nil }
		let image = Image(uiImage: native)
		#endif

		decoded[id] = image
		return image
	}

	/// Filename inside the package's `images/` directory, carrying the
	/// image's own extension.
	func filename(for id: UUID) -> String? {
		guard let stored = storedImages[id] else { return nil }
		let ext = stored.contentType.preferredFilenameExtension ?? "dat"
		return "\(id.uuidString).\(ext)"
	}

	func metadata(for ids: Set<UUID>) -> [StoredImageMeta] {
		ids.compactMap { id in
			guard let stored = storedImages[id] else { return nil }
			return StoredImageMeta(id: id,
								   contentType: stored.contentType.identifier,
								   pixelWidth: stored.pixelWidth,
								   pixelHeight: stored.pixelHeight)
		}
		.sorted { $0.id.uuidString < $1.id.uuidString }
	}
}
```

- [x] **Step 4: Wire up and run**

```bash
ruby Scripts/add_sources.rb Mozaic Mozaic/Document Mozaic/Document/ImageStore.swift
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/ImageStoreTests.swift
xcodebuild ... test -only-testing:MozaicTests/ImageStoreTests
```
Expected: PASS, 7 tests.

- [x] **Step 5: Commit**

```bash
git add Mozaic/Document/ImageStore.swift MozaicTests/ImageStoreTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add ImageStore with memoized decoding

Single owner of a document's image bytes. Decoding is memoized and the
cache is @ObservationIgnored so filling it does not invalidate views --
views resolve images by ID every render pass, so decoding per call would
put a full image decode in the render loop."
```

---

### Task 5: The document — package read, write, and incremental save

**Files:**
- Create: `Mozaic/Document/UTType+Mozaic.swift`
- Create: `Mozaic/Document/MozaicDocument.swift`
- Create: `MozaicTests/MozaicDocumentTests.swift`
- Modify: `Mozaic/Info.plist`

**Interfaces:**
- Consumes: `BoardFile`, `Board`, `ImageStore`, `StoredImage`.
- Produces:
  - `UTType.mozaicBoard`, `UTType.mozaicImageReference`
  - `@MainActor final class MozaicDocument: ReferenceFileDocument`
  - `MozaicDocument.model: ProjectModel` (wired in **Task 8**; until then the document holds `board` and `images` directly)
  - `struct BoardSnapshot: Sendable { var board: Board; var images: [UUID: StoredImage] }`
  - `static func makeFileWrapper(snapshot:existing:) throws -> FileWrapper` — static so it is testable without a document instance
  - `static func read(_ wrapper: FileWrapper) throws -> BoardSnapshot`
  - `enum DocumentError: Error { case notAPackage, missingManifest, unsupportedVersion(Int) }`

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/MozaicDocumentTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct MozaicDocumentTests {
	private func makeImageData(width: Int = 20) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: width, height: 20, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0, green: 1, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: width, height: 20))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	private func snapshotWithOnePlacedImage() throws -> (BoardSnapshot, UUID) {
		let id = UUID()
		let stored = StoredImage(data: try makeImageData(), contentType: .png,
								 pixelWidth: 20, pixelHeight: 20)
		var board = Board()
		board.rows[0].slots[0] = id
		board.projectName = "Trip"
		return (BoardSnapshot(board: board, images: [id: stored]), id)
	}

	@Test func writesAPackageWithManifestAndImages() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		#expect(wrapper.isDirectory)
		let children = try #require(wrapper.fileWrappers)
		#expect(children["manifest.json"] != nil)

		let images = try #require(children["images"]?.fileWrappers)
		#expect(images["\(id.uuidString).png"] != nil)
	}

	@Test func roundTripsThroughAPackage() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let read = try MozaicDocument.read(wrapper)

		#expect(read.board.projectName == "Trip")
		#expect(read.board.rows[0].slots[0] == id)
		#expect(read.images[id]?.contentType == .png)
		#expect(read.images[id]?.data == snapshot.images[id]?.data)
	}

	@Test func unreferencedImagesAreNotWritten() throws {
		var (snapshot, _) = try snapshotWithOnePlacedImage()
		let orphan = UUID()
		snapshot.images[orphan] = StoredImage(data: try makeImageData(width: 30),
											  contentType: .png, pixelWidth: 30, pixelHeight: 20)

		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let images = try #require(wrapper.fileWrappers?["images"]?.fileWrappers)

		// Garbage collection: only IDs reachable from rows or tray are written.
		#expect(images["\(orphan.uuidString).png"] == nil)
		#expect(images.count == 1)
	}

	@Test func trayImagesAreWritten() throws {
		var (snapshot, _) = try snapshotWithOnePlacedImage()
		let trayID = UUID()
		snapshot.images[trayID] = StoredImage(data: try makeImageData(width: 30),
											  contentType: .png, pixelWidth: 30, pixelHeight: 20)
		snapshot.board.tray = [trayID]

		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let images = try #require(wrapper.fileWrappers?["images"]?.fileWrappers)
		#expect(images["\(trayID.uuidString).png"] != nil)
	}

	@Test func unchangedImagesAreReusedFromTheExistingPackage() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let first = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)
		let originalChild = try #require(first.fileWrappers?["images"]?.fileWrappers?["\(id.uuidString).png"])

		// Save again with the board renamed but the image untouched.
		var changed = snapshot
		changed.board.projectName = "Renamed"
		let second = try MozaicDocument.makeFileWrapper(snapshot: changed, existing: first)
		let reusedChild = try #require(second.fileWrappers?["images"]?.fileWrappers?["\(id.uuidString).png"])

		// Same wrapper instance: the bytes were not rewritten.
		#expect(reusedChild === originalChild)
	}

	@Test func rejectsANewerFormatVersion() throws {
		let (snapshot, _) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		var file = try JSONDecoder().decode(
			BoardFile.self,
			from: #require(wrapper.fileWrappers?["manifest.json"]?.regularFileContents)
		)
		file.formatVersion = BoardFile.currentFormatVersion + 1

		let poisoned = FileWrapper(directoryWithFileWrappers: [
			"manifest.json": FileWrapper(regularFileWithContents: try JSONEncoder().encode(file)),
			"images": FileWrapper(directoryWithFileWrappers: [:]),
		])
		#expect(throws: DocumentError.self) { try MozaicDocument.read(poisoned) }
	}

	@Test func missingManifestThrows() {
		let empty = FileWrapper(directoryWithFileWrappers: [:])
		#expect(throws: DocumentError.self) { try MozaicDocument.read(empty) }
	}

	@Test func aMissingImageFileDoesNotPreventOpening() throws {
		let (snapshot, id) = try snapshotWithOnePlacedImage()
		let wrapper = try MozaicDocument.makeFileWrapper(snapshot: snapshot, existing: nil)

		// Delete the image but leave the manifest referencing it.
		let images = try #require(wrapper.fileWrappers?["images"])
		images.removeFileWrapper(try #require(images.fileWrappers?["\(id.uuidString).png"]))

		// A board that lost one image should still open with the rest.
		let read = try MozaicDocument.read(wrapper)
		#expect(read.board.rows[0].slots[0] == id)   // slot reference survives
		#expect(read.images[id] == nil)              // bytes are simply absent
	}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:MozaicTests/MozaicDocumentTests`
Expected: `cannot find 'MozaicDocument' in scope`.

- [x] **Step 3: Declare the types**

Create `Mozaic/Document/UTType+Mozaic.swift`:

```swift
import UniformTypeIdentifiers

extension UTType {
	/// The `.mozaic` document package. Declared in Info.plist.
	static let mozaicBoard = UTType(exportedAs: "com.mb.unicorn.mozaic.board")

	/// In-process drag payload: a reference to an image already in the store,
	/// so dragging moves a UUID rather than pixels.
	static let mozaicImageReference = UTType(exportedAs: "com.mb.unicorn.mozaic.image-reference")
}
```

- [x] **Step 4: Write the document**

Create `Mozaic/Document/MozaicDocument.swift`:

```swift
import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum DocumentError: Error, Equatable {
	case notAPackage
	case missingManifest
	case unsupportedVersion(Int)
}

/// Everything needed to write a document, captured on the main actor and
/// handed to the background writer. `Sendable` because
/// `fileWrapper(snapshot:configuration:)` is `nonisolated`.
struct BoardSnapshot: Sendable {
	var board: Board
	var images: [UUID: StoredImage]
}

/// A `.mozaic` package: a manifest plus one file per image, in the image's
/// own format.
///
/// `ReferenceFileDocument` rather than `FileDocument` because `ProjectModel`
/// is an `@Observable` class — the value-type `FileDocument` would force it to
/// become a struct — and because it supplies the `UndoManager`.
@MainActor
final class MozaicDocument: ReferenceFileDocument {
	typealias Snapshot = BoardSnapshot

	static var readableContentTypes: [UTType] { [.mozaicBoard] }

	static let manifestName = "manifest.json"
	static let imagesDirectoryName = "images"

	var board: Board
	let images: ImageStore

	init() {
		self.board = Board()
		self.images = ImageStore()
	}

	init(configuration: ReadConfiguration) throws {
		let snapshot = try Self.read(configuration.file)
		self.board = snapshot.board
		self.images = ImageStore(storedImages: snapshot.images)
	}

	func snapshot(contentType: UTType) throws -> BoardSnapshot {
		BoardSnapshot(board: board, images: images.storedImages)
	}

	nonisolated func fileWrapper(snapshot: BoardSnapshot,
								 configuration: WriteConfiguration) throws -> FileWrapper {
		try Self.makeFileWrapper(snapshot: snapshot, existing: configuration.existingFile)
	}

	// MARK: Writing

	/// Builds the package. Static so it can be tested without a document.
	///
	/// Only images reachable from the board are written, which is how garbage
	/// collection happens — an unreferenced image is dropped by simply not
	/// being written, with no reference counting.
	nonisolated static func makeFileWrapper(snapshot: BoardSnapshot,
											existing: FileWrapper?) throws -> FileWrapper {
		let referenced = snapshot.board.referencedImageIDs
		let existingImages = existing?.fileWrappers?[imagesDirectoryName]?.fileWrappers ?? [:]

		var imageChildren: [String: FileWrapper] = [:]
		var metadata: [StoredImageMeta] = []

		for id in referenced.sorted(by: { $0.uuidString < $1.uuidString }) {
			guard let stored = snapshot.images[id] else { continue }
			let ext = stored.contentType.preferredFilenameExtension ?? "dat"
			let name = "\(id.uuidString).\(ext)"

			// Image bytes are immutable per ID — any edit mints a new ID — so
			// a matching filename guarantees matching contents. That makes
			// reuse safe and keeps saves from rewriting unchanged images.
			if let reusable = existingImages[name], reusable.isRegularFile {
				imageChildren[name] = reusable
			} else {
				imageChildren[name] = FileWrapper(regularFileWithContents: stored.data)
			}

			metadata.append(StoredImageMeta(id: id,
											contentType: stored.contentType.identifier,
											pixelWidth: stored.pixelWidth,
											pixelHeight: stored.pixelHeight))
		}

		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
		let manifest = try encoder.encode(BoardFile(board: snapshot.board, images: metadata))

		return FileWrapper(directoryWithFileWrappers: [
			manifestName: FileWrapper(regularFileWithContents: manifest),
			imagesDirectoryName: FileWrapper(directoryWithFileWrappers: imageChildren),
		])
	}

	// MARK: Reading

	/// Reads a package. Tolerant of missing image files: a board that lost one
	/// image still opens with the rest.
	nonisolated static func read(_ wrapper: FileWrapper) throws -> BoardSnapshot {
		guard wrapper.isDirectory, let children = wrapper.fileWrappers else {
			throw DocumentError.notAPackage
		}
		guard let manifestData = children[manifestName]?.regularFileContents else {
			throw DocumentError.missingManifest
		}

		let file: BoardFile
		do {
			file = try JSONDecoder().decode(BoardFile.self, from: manifestData)
		} catch {
			throw CocoaError(.fileReadCorruptFile)
		}
		guard file.formatVersion <= BoardFile.currentFormatVersion else {
			throw DocumentError.unsupportedVersion(file.formatVersion)
		}

		let imageFiles = children[imagesDirectoryName]?.fileWrappers ?? [:]
		var images: [UUID: StoredImage] = [:]

		for meta in file.images {
			guard let type = UTType(meta.contentType) else { continue }
			let ext = type.preferredFilenameExtension ?? "dat"
			guard let data = imageFiles["\(meta.id.uuidString).\(ext)"]?.regularFileContents else {
				continue  // absent or unreadable: slot renders a placeholder
			}
			images[meta.id] = StoredImage(data: data,
										  contentType: type,
										  pixelWidth: meta.pixelWidth,
										  pixelHeight: meta.pixelHeight)
		}

		return BoardSnapshot(board: file.board, images: images)
	}
}
```

- [x] **Step 5: Declare the document type in Info.plist**

Add to the top-level `<dict>` in `Mozaic/Info.plist`, alongside `NSHighResolutionCapable`:

```xml
<key>UTExportedTypeDeclarations</key>
<array>
	<dict>
		<key>UTTypeIdentifier</key>
		<string>com.mb.unicorn.mozaic.board</string>
		<key>UTTypeDescription</key>
		<string>Mozaic Board</string>
		<key>UTTypeConformsTo</key>
		<array>
			<string>com.apple.package</string>
			<string>public.composite-content</string>
		</array>
		<key>UTTypeTagSpecification</key>
		<dict>
			<key>public.filename-extension</key>
			<array><string>mozaic</string></array>
		</dict>
	</dict>
	<dict>
		<key>UTTypeIdentifier</key>
		<string>com.mb.unicorn.mozaic.image-reference</string>
		<key>UTTypeDescription</key>
		<string>Mozaic Image Reference</string>
		<key>UTTypeConformsTo</key>
		<array><string>public.data</string></array>
	</dict>
</array>
<key>CFBundleDocumentTypes</key>
<array>
	<dict>
		<key>CFBundleTypeName</key>
		<string>Mozaic Board</string>
		<key>LSItemContentTypes</key>
		<array><string>com.mb.unicorn.mozaic.board</string></array>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>LSHandlerRank</key>
		<string>Owner</string>
	</dict>
</array>
```

Verify: `plutil -lint Mozaic/Info.plist` → `OK`.

- [x] **Step 6: Wire up and run**

```bash
ruby Scripts/add_sources.rb Mozaic Mozaic/Document \
  Mozaic/Document/UTType+Mozaic.swift Mozaic/Document/MozaicDocument.swift
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/MozaicDocumentTests.swift
xcodebuild ... test -only-testing:MozaicTests/MozaicDocumentTests
```
Expected: PASS, 9 tests. The `reusedChild === originalChild` assertion is the one that proves incremental save works; if it fails, saves are rewriting every image and the reason for choosing a package is lost.

- [x] **Step 7: Commit**

```bash
git add Mozaic/Document/ Mozaic/Info.plist MozaicTests/MozaicDocumentTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add .mozaic package document

ReferenceFileDocument reading and writing a package of manifest.json plus
one file per image in its own format. Garbage collection falls out of only
writing referenced IDs. Unchanged images are reused from the existing
wrapper rather than rewritten, which is safe because image bytes are
immutable per ID. Reading tolerates a missing image file so a board that
lost one image still opens."
```

---

### Task 6: Move ProjectModel and the views onto image IDs

The deepest change in the plan. `ProjectModel` stops holding `Image` values and holds `UUID`s resolved through `ImageStore`. Every view that renders an image changes. The app must still build and run standalone at the end of this task — `DocumentGroup` arrives in Task 8.

**Files:**
- Modify: `Mozaic/Models/ProjectModel.swift`
- Modify: `Mozaic/Moodboard/MbImage.swift`
- Modify: `Mozaic/Moodboard/Modules.swift`
- Modify: `Mozaic/Moodboard/ModWrapper.swift`
- Modify: `Mozaic/Moodboard/MoodBoardMain.swift`
- Modify: `Mozaic/inspector/bottomBar.swift`
- Modify: `Mozaic/ContentView.swift`
- Create: `MozaicTests/ProjectModelTests.swift`
- (`Mozaic/inspector/BoardSettings.swift` needs no change: its `@Bindable`
  bindings still resolve against `ProjectModel`'s new computed properties.
  Touch it only if the build says otherwise.)

**Interfaces:**
- Consumes: `Board`, `Row`, `ImageStore`, `ImageQuality`.
- Produces:
  - `ProjectModel.board: Board`, `ProjectModel.images: ImageStore`
  - `func place(_ id: UUID, row: Int, slot: Int)`
  - `func clearSlot(row: Int, slot: Int)`
  - `@discardableResult func importImage(_ data: Data) throws -> UUID` — adds to store *and* tray, applying the tray cap
  - `func setModule(_ module: Module, row: Int)`
  - Convenience passthroughs kept for the views: `gridGap`, `cellRadius`, `projectName`, `createdBy`, `showBoardInfo`, `cellWidth`, `twoCellWidth`, `halfGridGap`
- Task 7 replaces the drag payload; Task 8 hands `ProjectModel` a document-backed `Board`.

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/ProjectModelTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ProjectModelTests {
	private func imageData(_ seed: Int = 0) throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 8 + seed, height: 8, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 0, green: 0, blue: 1, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 8 + seed, height: 8))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func startsWithSixEmptyRows() {
		let model = ProjectModel()
		#expect(model.board.rows.count == Board.defaultRowCount)
		#expect(model.board.rows.allSatisfy { $0.slots.allSatisfy { $0 == nil } })
	}

	@Test func importingAddsToStoreAndTray() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())

		#expect(model.images.stored(for: id) != nil)
		#expect(model.board.tray == [id])
	}

	@Test func placingWritesTheSlot() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 2, slot: 1)

		#expect(model.board.rows[2].slots[1] == id)
	}

	@Test func clearingEmptiesTheSlot() throws {
		let model = ProjectModel()
		let id = try model.importImage(try imageData())
		model.place(id, row: 0, slot: 0)
		model.clearSlot(row: 0, slot: 0)

		#expect(model.board.rows[0].slots[0] == nil)
	}

	@Test func trayEvictsOldestBeyondTheCap() throws {
		let model = ProjectModel()
		var ids: [UUID] = []
		for seed in 0...Board.trayLimit {          // one more than the cap
			ids.append(try model.importImage(try imageData(seed)))
		}

		#expect(model.board.tray.count == Board.trayLimit)
		#expect(model.board.tray.contains(ids.first!) == false)  // oldest evicted
		#expect(model.board.tray.contains(ids.last!))            // newest kept
	}

	@Test func trayEvictionNeverRemovesAPlacedImage() throws {
		let model = ProjectModel()
		let placed = try model.importImage(try imageData(0))
		model.place(placed, row: 0, slot: 0)

		for seed in 1...(Board.trayLimit + 5) {
			_ = try model.importImage(try imageData(seed))
		}

		// The cap bounds tray membership only. The placed image may leave the
		// tray, but its bytes and its slot must survive.
		#expect(model.board.rows[0].slots[0] == placed)
		#expect(model.images.stored(for: placed) != nil)
	}

	@Test func settingAModuleChangesOnlyThatRow() {
		let model = ProjectModel()
		model.setModule(.fourshort, row: 3)

		#expect(model.board.rows[3].module == .fourshort)
		#expect(model.board.rows[0].module == .vlong2short)
	}

	@Test func cellGeometryTracksGridGap() {
		let model = ProjectModel()
		model.gridGap = 20
		#expect(model.halfGridGap == 10)
		#expect(model.cellWidth == ProjectModel.baseCellWidth - 10)
	}
}
```

- [x] **Step 2: Run to verify it fails**

Run: `xcodebuild ... test -only-testing:MozaicTests/ProjectModelTests`
Expected: failures — `value of type 'ProjectModel' has no member 'board'`.

- [x] **Step 3: Rewrite ProjectModel**

Replace the contents of `Mozaic/Models/ProjectModel.swift`. `MbRow` is gone — `Row` from `BoardManifest.swift` replaces it — as are the `Image`-to-`Data` helpers, which `ImageCoder` and `ImageStore` now own.

```swift
import Foundation
import SwiftUI

/// The live, editable state of one board.
///
/// Holds image *identifiers*, never decoded images: `ImageStore` owns the
/// bytes and the decode cache.
@MainActor
@Observable
final class ProjectModel {
	/// Base width of a single cell before the grid gap is applied.
	///
	/// The module and grid frames in `ModuleWrapper` and `MoodBoardMain` derive
	/// from this; changing it alone will misalign the board.
	static let baseCellWidth: CGFloat = 155.0

	var board: Board
	let images: ImageStore

	init(board: Board = Board(), images: ImageStore = ImageStore()) {
		self.board = board
		self.images = images
	}

	// MARK: Board settings passthroughs

	var projectName: String {
		get { board.projectName }
		set { board.projectName = newValue }
	}
	var createdBy: String {
		get { board.createdBy }
		set { board.createdBy = newValue }
	}
	var showBoardInfo: Bool {
		get { board.showBoardInfo }
		set { board.showBoardInfo = newValue }
	}
	var gridGap: Double {
		get { board.gridGap }
		set { board.gridGap = newValue }
	}
	var cellRadius: Double {
		get { board.cellRadius }
		set { board.cellRadius = newValue }
	}
	var quality: ImageQuality {
		get { board.quality }
		set { board.quality = newValue }
	}

	// MARK: Geometry

	/// Width of a single cell, inset by half the grid gap so adjacent cells
	/// keep a constant pitch as the gap changes.
	var cellWidth: CGFloat { Self.baseCellWidth - halfGridGap }
	var twoCellWidth: CGFloat { Self.baseCellWidth * 2.0 }
	var halfGridGap: CGFloat { CGFloat(gridGap) / 2.0 }

	// MARK: Editing

	func image(for id: UUID?) -> Image? {
		guard let id else { return nil }
		return images.image(for: id)
	}

	func place(_ id: UUID, row: Int, slot: Int) {
		guard board.rows.indices.contains(row),
			  board.rows[row].slots.indices.contains(slot) else { return }
		board.rows[row].slots[slot] = id
	}

	func clearSlot(row: Int, slot: Int) {
		guard board.rows.indices.contains(row),
			  board.rows[row].slots.indices.contains(slot) else { return }
		board.rows[row].slots[slot] = nil
	}

	func setModule(_ module: Module, row: Int) {
		guard board.rows.indices.contains(row) else { return }
		board.rows[row].module = module
	}

	/// Imports bytes into the store and puts the image in the tray.
	///
	/// The tray cap bounds tray membership only — never the store — so
	/// eviction can never remove an image that is placed on the board.
	@discardableResult
	func importImage(_ data: Data) throws -> UUID {
		let id = try images.add(data, quality: board.quality)
		board.tray.append(id)
		if board.tray.count > Board.trayLimit {
			board.tray.removeFirst(board.tray.count - Board.trayLimit)
		}
		return id
	}
}
```

- [x] **Step 4: Run the model tests**

```bash
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/ProjectModelTests.swift
xcodebuild ... test -only-testing:MozaicTests/ProjectModelTests
```
Expected: PASS, 8 tests. The views will not compile yet; that is Step 5.

- [x] **Step 5: Update the views**

`MbImage.swift` — take an optional ID and resolve through the model; show a placeholder when the image is missing (which is also what a document with a lost image renders):

```swift
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
```

Drag and drop modifiers are deliberately absent here — Task 7 adds them back with the new payload. The board is briefly not drag-enabled between Tasks 6 and 7.

`Modules.swift` — change `MbCell.img: [Image]` to `slots: [UUID?]` and every `imgSlot: mbCell.img[n]` to `imageID: mbCell.slots[n]`:

```swift
struct MbCell {
	let cellSpacing: CGFloat
	let cell: CGFloat
	let twoCell: CGFloat
	var slots: [UUID?]
	var index: Int
}
```

Apply the same substitution in all eight layout views and in the file's `#Preview`, replacing the four `Image("OGbgImg")` arguments with `slots: [nil, nil, nil, nil]`.

`ModWrapper.swift` — read the module from the board:

```swift
switch pm.board.rows[mbCell.index].module {
```

and change `setModule` to call through the model:

```swift
private func setModule(_ module: Module) {
	pm.setModule(module, row: mbCell.index)
	isPickingModule = false
}
```

`MoodBoardMain.swift` — iterate rows:

```swift
ForEach(pm.board.rows.enumerated(), id: \.element.id) { index, row in
	ModuleWrapper(mbCell: MbCell(cellSpacing: pm.gridGap,
								 cell: pm.cellWidth,
								 twoCell: pm.twoCellWidth,
								 slots: row.slots,
								 index: index))
}
```

`bottomBar.swift` — take IDs and the model:

```swift
struct BottomBar: View {
	var pm: ProjectModel
	let imageIDs: [UUID]
	let gridItemWidth = 225.0
	let gridItemHeight = 150.0

	var body: some View {
		ScrollView(.vertical) {
			LazyVGrid(columns: [GridItem(.fixed(gridItemWidth))], spacing: 10.0) {
				ForEach(imageIDs, id: \.self) { id in
					if let image = pm.images.image(for: id) {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: gridItemWidth, height: gridItemHeight)
							.background(Material.thin)
							.clipShape(.rect(cornerRadius: 10.0))
					}
				}
			}
		}
	}
}

#Preview {
	BottomBar(pm: ProjectModel(), imageIDs: [])
}
```

`ContentView.swift` — route both importers through `pm.importImage(_:)` and drop the `Image`-building branches. The `fileImporter` handler becomes:

```swift
case .success(let file):
	guard file.startAccessingSecurityScopedResource() else { return }
	defer { file.stopAccessingSecurityScopedResource() }
	do {
		try pm.importImage(try Data(contentsOf: file))
	} catch {
		print("Failed to import image:", error)
	}
```

and the `PhotosPicker` handler loads `Data` instead of `Image`:

```swift
.onChange(of: selectedItems) {
	Task {
		for item in selectedItems {
			guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
			try? pm.importImage(data)
		}
	}
}
```

Update the inspector call site to `BottomBar(pm: pm, imageIDs: pm.board.tray)`.

- [x] **Step 6: Build both platforms and run the whole suite**

```bash
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' build
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test
```
Expected: both builds succeed; all tests pass.

- [x] **Step 7: Commit**

```bash
git add Mozaic/ MozaicTests/ProjectModelTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "refactor: hold image IDs in ProjectModel instead of decoded images

ProjectModel now holds a Board of UUID slot references, with ImageStore
owning bytes and decoding. MbRow and the Image/Data conversion helpers are
gone; ImageCoder and ImageStore replace them. Both importers now feed raw
Data through a single import path that applies the tray cap.

Drag and drop is temporarily absent from MbImage; the next commit restores
it with a Transferable payload that carries an ID rather than pixels."
```

---

### Task 7: Drag payload carrying IDs

The current payload is `Image`, which cannot survive: recovering bytes from a dropped `Image` needs `ImageRenderer`, which rasterizes a SwiftUI view and would silently re-compress every image on every drag.

**Files:**
- Create: `Mozaic/Moodboard/DroppedImage.swift`
- Create: `MozaicTests/DroppedImageTests.swift`
- Modify: `Mozaic/Moodboard/MbImage.swift`
- Modify: `Mozaic/inspector/bottomBar.swift`

**Interfaces:**
- Consumes: `UTType.mozaicImageReference`, `ProjectModel.importImage(_:)`, `ProjectModel.place(_:row:slot:)`.
- Produces: `enum DroppedImage: Codable, Transferable { case reference(UUID); case external(Data, String) }` — the `String` is a UTI identifier, because `UTType` is not `Codable`.
- Produces: `ProjectModel.accept(_ dropped: DroppedImage, row: Int, slot: Int) throws`

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/DroppedImageTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct DroppedImageTests {
	private func pngData() throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 12, height: 12, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 1, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 12, height: 12))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func referencePayloadRoundTrips() throws {
		let id = UUID()
		let data = try JSONEncoder().encode(DroppedImage.reference(id))
		let decoded = try JSONDecoder().decode(DroppedImage.self, from: data)

		guard case .reference(let decodedID) = decoded else {
			Issue.record("expected a reference payload"); return
		}
		#expect(decodedID == id)
	}

	@Test func acceptingAReferencePlacesWithoutCopyingBytes() throws {
		let model = ProjectModel()
		let id = try model.importImage(try pngData())
		let storedCount = model.images.storedImages.count

		try model.accept(.reference(id), row: 1, slot: 2)

		#expect(model.board.rows[1].slots[2] == id)
		// An in-app drag moves an ID: no new image is created.
		#expect(model.images.storedImages.count == storedCount)
	}

	@Test func acceptingAnExternalDropImportsThenPlaces() throws {
		let model = ProjectModel()
		try model.accept(.external(try pngData(), UTType.png.identifier), row: 0, slot: 3)

		let placed = try #require(model.board.rows[0].slots[3])
		#expect(model.images.stored(for: placed) != nil)
	}

	@Test func acceptingAReferenceToAnUnknownImageIsIgnored() throws {
		let model = ProjectModel()
		try model.accept(.reference(UUID()), row: 0, slot: 0)

		// A dangling reference must never reach the board, or the manifest
		// would point at a file that was never written.
		#expect(model.board.rows[0].slots[0] == nil)
	}

	@Test func acceptingCorruptExternalDataThrowsAndLeavesTheBoardAlone() {
		let model = ProjectModel()
		#expect(throws: ImageCoderError.self) {
			try model.accept(.external(Data("nope".utf8), UTType.png.identifier), row: 0, slot: 0)
		}
		#expect(model.board.rows[0].slots[0] == nil)
	}
}
```

- [x] **Step 2: Run to verify it fails**

Expected: `cannot find 'DroppedImage' in scope`.

- [x] **Step 3: Write the payload and the accept path**

Create `Mozaic/Moodboard/DroppedImage.swift`:

```swift
import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// What a drop can deliver.
///
/// In-app drags carry only an ID, so moving an image between slots moves a
/// UUID rather than pixels. Drops from outside carry bytes plus the content
/// type, so the image's original format survives the trip.
enum DroppedImage: Codable, Transferable, Sendable {
	case reference(UUID)
	/// Bytes plus a UTI identifier (`UTType` is not `Codable`).
	case external(Data, String)

	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .mozaicImageReference)
		DataRepresentation(importedContentType: .png)  { .external($0, UTType.png.identifier) }
		DataRepresentation(importedContentType: .jpeg) { .external($0, UTType.jpeg.identifier) }
		DataRepresentation(importedContentType: .heic) { .external($0, UTType.heic.identifier) }
		DataRepresentation(importedContentType: .tiff) { .external($0, UTType.tiff.identifier) }
		DataRepresentation(importedContentType: .gif)  { .external($0, UTType.gif.identifier) }
	}
}

extension ProjectModel {
	/// Resolves a drop into a slot.
	///
	/// The declared content type is a hint only — `ImageCoder` sniffs the real
	/// format from the bytes.
	func accept(_ dropped: DroppedImage, row: Int, slot: Int) throws {
		switch dropped {
		case .reference(let id):
			// Defence in depth: never write an ID the store does not know
			// about, whatever the payload claims.
			guard images.stored(for: id) != nil else { return }
			place(id, row: row, slot: slot)
		case .external(let data, _):
			let id = try importImage(data)
			place(id, row: row, slot: slot)
		}
	}
}
```

- [x] **Step 4: Restore drag and drop in the views**

In `MbImage.swift`, attach the drag **inside** the branch that already knows an
image exists, so an empty slot is simply not draggable. A slot must never
originate a payload referencing an image that is not in the store: `place()`
would write that dangling ID into the board and the manifest would then point
at a file that was never written.

```swift
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
				try pm.accept(first, row: indexes[0], slot: indexes[1])
				return true
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
```

In `bottomBar.swift`, make tray thumbnails draggable by reference:

```swift
.draggable(DroppedImage.reference(id)) {
	image
		.resizable()
		.aspectRatio(contentMode: .fill)
		.frame(width: gridItemWidth / 2.0, height: gridItemHeight / 2.0)
		.clipShape(.rect(cornerRadius: 10))
}
```

- [x] **Step 5: Build, test, and check the drag path by hand**

```bash
xcodebuild ... -destination 'platform=macOS' build
xcodebuild ... -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild ... -destination 'platform=macOS' test
```

Then run the app and verify by hand, because this is the path commit 6115747 was written to fix: import several large photos, drag one from the tray to a slot, and drag between slots. **Dragging must feel no slower than before this plan started.** If it does, stop and check that `ImageStore.image(for:)` is hitting its cache rather than decoding per frame.

- [x] **Step 6: Commit**

```bash
git add Mozaic/Moodboard/ Mozaic/inspector/bottomBar.swift MozaicTests/DroppedImageTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: carry image IDs through drag and drop

Replaces the bare Image drag payload, which could only be turned back into
bytes via ImageRenderer -- rasterizing a SwiftUI view and silently
re-compressing every image on every drag. In-app drags now move a UUID;
external drops carry bytes plus their content type so format survives."
```

---

### Task 8: DocumentGroup, and remove SwiftData

**Files:**
- Modify: `Mozaic/MozaicApp.swift`
- Modify: `Mozaic/ContentView.swift`
- Delete: `Mozaic/Models/MDataModel.swift`

**Interfaces:**
- Consumes: `MozaicDocument`, `ProjectModel`.
- Produces: `ContentView(document: MozaicDocument)`.

- [x] **Step 1: Give MozaicDocument a ProjectModel**

`ContentView` needs one `ProjectModel` whose edits the document can snapshot. Replace `MozaicDocument`'s stored `board`/`images` pair with a model that owns both, keeping `snapshot(contentType:)` reading through it. In `Mozaic/Document/MozaicDocument.swift`:

```swift
	let model: ProjectModel

	init() {
		self.model = ProjectModel()
	}

	init(configuration: ReadConfiguration) throws {
		let snapshot = try Self.read(configuration.file)
		self.model = ProjectModel(board: snapshot.board,
								  images: ImageStore(storedImages: snapshot.images))
	}

	func snapshot(contentType: UTType) throws -> BoardSnapshot {
		BoardSnapshot(board: model.board, images: model.images.storedImages)
	}
```

- [x] **Step 2: Switch the app to DocumentGroup**

Replace `Mozaic/MozaicApp.swift` entirely — the SwiftData container goes with it:

```swift
//
//  MozaicApp.swift
//  Mozaic
//
//  Created by Max Burger on 5/16/24.
//

import SwiftUI

@main
struct MozaicApp: App {
	var body: some Scene {
		DocumentGroup(newDocument: { MozaicDocument() }) { configuration in
			ContentView(document: configuration.document)
		}
	}
}
```

- [x] **Step 3: Take the document in ContentView**

In `Mozaic/ContentView.swift`, replace `@State var pm: ProjectModel = ProjectModel()` with:

```swift
	let document: MozaicDocument
	private var pm: ProjectModel { document.model }
```

Remove `import SwiftData`. Update the preview to `ContentView(document: MozaicDocument())`.

- [x] **Step 4: Delete the SwiftData model**

```bash
git rm Mozaic/Models/MDataModel.swift
ruby -e '
require "xcodeproj"
p = Xcodeproj::Project.open("Mozaic.xcodeproj")
ref = p.files.find { |f| f.display_name == "MDataModel.swift" }
ref&.remove_from_project
p.save
puts ref ? "removed MDataModel.swift from project" : "not referenced"
'
```

- [x] **Step 5: Build, test, and exercise the document lifecycle**

```bash
xcodebuild ... -destination 'platform=macOS' build
xcodebuild ... -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build
xcodebuild ... -destination 'platform=macOS' test
```

Then, by hand on macOS: create a board, import images, place some, save as `Test.mozaic`, close, reopen, and confirm the board and tray come back. Inspect the package:

```bash
ls -la ~/Desktop/Test.mozaic/ ~/Desktop/Test.mozaic/images/
python3 -m json.tool ~/Desktop/Test.mozaic/manifest.json | head -40
```
Expected: a `manifest.json` plus one file per image, each with its own extension.

- [x] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: convert Mozaic to a document-based app

MozaicApp swaps WindowGroup for DocumentGroup, which brings the system
document browser on iPadOS and New/Open/Save/Duplicate/Rename/Versions
plus autosave on macOS. ContentView takes the document rather than owning
its own ProjectModel.

Deletes MDataModel and the in-memory SwiftData container. Nothing read or
wrote them, and the .mozaic format supersedes them."
```

---

### Task 9: Undo

Documents need ⌘Z. `ReferenceFileDocument` supplies the `UndoManager` through the environment; every mutation has to register with it.

**Files:**
- Modify: `Mozaic/Models/ProjectModel.swift`
- Modify: `Mozaic/ContentView.swift`
- Modify: `Mozaic/Moodboard/MbImage.swift`
- Modify: `Mozaic/Moodboard/ModWrapper.swift`
- Modify: `Mozaic/inspector/BoardSettings.swift`
- Create: `MozaicTests/UndoTests.swift`

**Interfaces:**
- Produces: `ProjectModel.undoManager: UndoManager?` and `func withUndo(_ name: String, _ change: (ProjectModel) -> Void)`.

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/UndoTests.swift`:

```swift
import Foundation
import Testing
@testable import Mozaic

@MainActor
@Suite struct UndoTests {
	@Test func undoRestoresAPreviousModule() {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		model.withUndo("Change Layout") { $0.setModule(.fourshort, row: 0) }
		#expect(model.board.rows[0].module == .fourshort)

		undo.undo()
		#expect(model.board.rows[0].module == .vlong2short)
	}

	@Test func redoReappliesTheChange() {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		model.withUndo("Change Layout") { $0.setModule(.twohlong, row: 2) }
		undo.undo()
		undo.redo()

		#expect(model.board.rows[2].module == .twohlong)
	}

	@Test func undoRestoresAClearedSlot() throws {
		let model = ProjectModel()
		let undo = UndoManager()
		undo.groupsByEvent = false
		model.undoManager = undo

		let id = UUID()
		model.board.rows[0].slots[0] = id
		model.withUndo("Clear Image") { $0.clearSlot(row: 0, slot: 0) }
		#expect(model.board.rows[0].slots[0] == nil)

		undo.undo()
		#expect(model.board.rows[0].slots[0] == id)
	}

	@Test func undoIsANoOpWithoutAnUndoManager() {
		let model = ProjectModel()
		model.undoManager = nil
		model.withUndo("Change Layout") { $0.setModule(.onecell, row: 1) }
		#expect(model.board.rows[1].module == .onecell)
	}
}
```

- [x] **Step 2: Run to verify it fails**

Expected: `value of type 'ProjectModel' has no member 'undoManager'`.

- [x] **Step 3: Add undo registration**

Append to `ProjectModel`:

```swift
	/// Supplied by the document's environment. Nil in previews and tests that
	/// do not exercise undo.
	@ObservationIgnored var undoManager: UndoManager?

	/// Runs a change and registers its inverse.
	///
	/// The whole `Board` is a value type, so capturing it before the change is
	/// a cheap and complete snapshot — no per-property undo bookkeeping.
	func withUndo(_ name: String, _ change: (ProjectModel) -> Void) {
		let before = board
		change(self)
		guard let undoManager else { return }

		undoManager.setActionName(name)
		undoManager.registerUndo(withTarget: self) { model in
			model.withUndo(name) { $0.board = before }
		}
	}
```

- [x] **Step 4: Route mutations through withUndo**

In `ContentView`, pick up the environment's manager and hand it to the model:

```swift
	@Environment(\.undoManager) private var undoManager
```

and on the outermost view in `body`:

```swift
	.onChange(of: undoManager, initial: true) {
		pm.undoManager = undoManager
	}
```

Then wrap each mutation site:

- `MbImage`'s drop: `pm.withUndo("Move Image") { try? $0.accept(first, row: indexes[0], slot: indexes[1]) }` — note `accept` throws, so keep the `do/catch` inside the closure and return the result from outside.
- `ModuleWrapper.setModule`: `pm.withUndo("Change Layout") { $0.setModule(module, row: mbCell.index) }`
- `ContentView`'s importers: `pm.withUndo("Import Image") { try? $0.importImage(data) }`
- `BoardSettings`' sliders and text fields: bind through a helper that calls `withUndo("Change Grid Gap")` etc. Slider drags coalesce naturally, because `UndoManager` groups by event loop turn unless `groupsByEvent` is disabled.

- [x] **Step 5: Build, test, and try ⌘Z by hand**

Run the full suite plus both builds. Then in the running app: change a layout, press ⌘Z, confirm it reverts; ⇧⌘Z, confirm it returns. Drag a slider and confirm one ⌘Z undoes the whole drag rather than one step per pixel.

- [x] **Step 6: Commit**

```bash
git add Mozaic/ MozaicTests/UndoTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add undo across board edits

Registers every mutation with the document's UndoManager. Board is a value
type, so snapshotting it before a change gives complete undo without
per-property bookkeeping. Slider drags coalesce into one undo step."
```

---

### Task 10: Quality setting, document size, and Reduce File Size

**Files:**
- Modify: `Mozaic/inspector/BoardSettings.swift`
- Modify: `Mozaic/Document/ImageStore.swift`
- Create: `MozaicTests/ReduceFileSizeTests.swift`

**Interfaces:**
- Produces: `ImageStore.totalByteCount: Int`, `ImageStore.reduceFileSize() throws -> Int` (returns bytes saved).

- [x] **Step 1: Write the failing tests**

Create `MozaicTests/ReduceFileSizeTests.swift`:

```swift
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import Mozaic

@MainActor
@Suite struct ReduceFileSizeTests {
	private func largeJPEG() throws -> Data {
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 2400, height: 1600, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
		for i in 0..<40 {                       // texture, so it does not compress to nothing
			ctx.setFillColor(CGColor(red: Double(i) / 40.0, green: 0.4, blue: 0.7, alpha: 1))
			ctx.fill(CGRect(x: i * 60, y: 0, width: 60, height: 1600))
		}
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))
		return out as Data
	}

	@Test func totalByteCountSumsStoredImages() throws {
		let store = ImageStore()
		let data = try largeJPEG()
		_ = try store.add(data, quality: .full)
		#expect(store.totalByteCount == data.count)
	}

	@Test func reducingShrinksFullQualityImagesAndPreservesFormat() throws {
		let store = ImageStore()
		let id = try store.add(try largeJPEG(), quality: .full)
		let before = store.totalByteCount

		let saved = try store.reduceFileSize()

		#expect(saved > 0)
		#expect(store.totalByteCount < before)
		let stored = try #require(store.stored(for: id))
		#expect(stored.contentType == .jpeg)                       // format preserved
		#expect(max(stored.pixelWidth, stored.pixelHeight) == ImageQuality.standardMaxPixel)
	}

	@Test func reducingIsANoOpForImagesAlreadyUnderTheCap() throws {
		let store = ImageStore()
		let cs = CGColorSpaceCreateDeviceRGB()
		let ctx = CGContext(data: nil, width: 100, height: 80, bitsPerComponent: 8,
							bytesPerRow: 0, space: cs,
							bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
		ctx.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
		ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 80))
		let out = NSMutableData()
		let dest = CGImageDestinationCreateWithData(out, UTType.png.identifier as CFString, 1, nil)!
		CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
		#expect(CGImageDestinationFinalize(dest))

		let id = try store.add(out as Data, quality: .standard)
		let before = try #require(store.stored(for: id)).data

		#expect(try store.reduceFileSize() == 0)
		#expect(store.stored(for: id)?.data == before)   // byte-identical
	}
}
```

- [x] **Step 2: Run to verify it fails**

Expected: `value of type 'ImageStore' has no member 'totalByteCount'`.

- [x] **Step 3: Implement**

Append to `ImageStore`:

```swift
	/// Bytes currently held, for showing document size in the inspector.
	var totalByteCount: Int {
		storedImages.values.reduce(0) { $0 + $1.data.count }
	}

	/// Re-encodes every stored image down to the Standard cap, each to its own
	/// format. Images already within the cap, and formats that cannot round
	/// trip, are left byte-identical.
	///
	/// Destructive and deliberately not undoable: the discarded detail is
	/// gone, so registering an inverse would be a lie.
	@discardableResult
	func reduceFileSize() throws -> Int {
		let before = totalByteCount
		for (id, image) in storedImages {
			let prepared = try ImageCoder.prepared(image.data, quality: .standard)
			guard prepared.data.count < image.data.count else { continue }
			storedImages[id] = StoredImage(data: prepared.data,
										   contentType: prepared.contentType,
										   pixelWidth: prepared.pixelWidth,
										   pixelHeight: prepared.pixelHeight)
			decoded[id] = nil          // force a re-decode of the new bytes
		}
		return before - totalByteCount
	}
```

- [x] **Step 4: Add the inspector controls**

In `BoardSettings.swift`, inside the existing `Section`:

```swift
			Picker("Image Quality", selection: $pm.quality) {
				Text("Standard").tag(ImageQuality.standard)
				Text("Full").tag(ImageQuality.full)
			}
			LabeledContent("Document Size") {
				Text(pm.images.totalByteCount, format: .byteCount(style: .file))
			}
			Button("Reduce File Size", systemImage: "arrow.down.circle") {
				isConfirmingReduce = true
			}
			.confirmationDialog(
				"Reduce every image to \(ImageQuality.standardMaxPixel)px?",
				isPresented: $isConfirmingReduce,
				titleVisibility: .visible
			) {
				Button("Reduce", role: .destructive) { try? pm.images.reduceFileSize() }
				Button("Cancel", role: .cancel) { }
			} message: {
				Text("Discarded detail cannot be recovered, and this cannot be undone.")
			}
```

with `@State private var isConfirmingReduce = false` on the view. Showing document size next to the quality toggle is deliberate: Full mode is unbounded, so the cost should be visible when someone opts in rather than discovered when sharing fails.

- [x] **Step 5: Run the full suite and both builds**

Expected: all green.

- [x] **Step 6: Commit**

```bash
git add Mozaic/ MozaicTests/ReduceFileSizeTests.swift Mozaic.xcodeproj/project.pbxproj
git commit -m "feat: add quality picker, document size, and Reduce File Size

Re-encodes stored images down to the Standard cap, each to its own format,
skipping any already within it. Destructive and not undoable, so it is
behind a confirmation. Document size sits next to the quality picker
because Full mode is unbounded and the cost should be visible at the
moment of opting in."
```

---

### Task 11: Update project documentation

**Files:**
- Modify: `CLAUDE.md`

- [x] **Step 1: Rewrite the stale sections**

CLAUDE.md currently describes the pre-conversion architecture. Update:

- **Two disconnected data models** → gone. Describe `MozaicDocument` → `ProjectModel` → `ImageStore`, and that SwiftData was removed.
- **The render pipeline** → slots hold `UUID?` and resolve through `ImageStore`; `MbCell.slots` replaced `MbCell.img`.
- **`pm` passed two ways** → still true, still deliberate; note it now also carries the `ImageStore`.
- **Test suite** → the files are wired in now and the suite runs; UI tests are excluded from the default test plan.
- **Add:** the `.mozaic` package layout, the immutable-bytes-per-ID invariant that incremental save depends on, and `Scripts/add_sources.rb` as the required way to add files.

- [x] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md for the document-based architecture"
```

---

## Self-Review

**Spec coverage.** Every section of the design maps to a task: format → 2 and 5; incremental save and GC → 5; `MozaicDocument`/`ImageStore`/`ProjectModel` → 4, 5, 6; drag and drop → 7; image pipeline and tray cap → 3, 6; Reduce File Size → 10; undo → 9; app structure and Info.plist → 5 and 8; SwiftData removal → 8; error handling → 3 and 5; testing and step zero → 1; documentation → 11. The two spec risks that need runtime confirmation rather than code — decode-cache performance and drag responsiveness — are hand-verification steps in Tasks 7 and 5.

**Placeholders.** None. Every code step carries the actual code; every test step carries real assertions.

**Type consistency.** `Board`/`Row`/`StoredImageMeta` (Task 2) are used unchanged in 5 and 6. `StoredImage` is defined once in Task 4 and consumed in 5, 6, and 10. `PreparedImage` (3) is consumed only by `ImageStore.add` (4). `MbCell.img` → `MbCell.slots` is renamed once, in Task 6, and every call site in that task moves with it. `ImageQuality.standardMaxPixel` is referenced in 3, 6, and 10 under that one name.

**One deliberate discontinuity:** Task 6 removes drag and drop from `MbImage` and Task 7 restores it. The app builds and runs at the end of both, but the board cannot accept drops in between. Splitting this way keeps the model migration reviewable on its own; doing it in one task would produce a change too large to review meaningfully.
