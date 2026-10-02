# Document-Based Mozaic — Design

Date: 2026-08-21
Status: approved for planning

## Goal

Turn Mozaic from a single-window scratch app into a document-based app, so a
person can save a moodboard as a file, hand it to someone else, and have that
person open and keep editing it.

Sharing means **file handoff** — AirDrop, iCloud Drive, Dropbox. Not live
collaboration, and not iCloud sync. Both remain possible later; neither is in
scope.

## Decisions

| Decision | Choice |
|---|---|
| Sharing model | File handoff. Recipient edits their own copy. |
| Document format | Package (`FileWrapper` directory) |
| Image encoding | Original format preserved; re-encoded to that same format only when downscaling |
| Standard quality cap | 1000px longest edge |
| Full quality | Opt-in, per document |
| Unplaced image tray | Saved with the document, capped at 30 |
| Existing SwiftData model | Deleted |
| Undo | Full coverage |
| Quality setting | Applies at import; plus a "Reduce File Size" command |

Two of these were reversals made during design, recorded so the reasoning
isn't lost:

- **Format.** A flat single file was recommended first, because its only real
  weakness — rewriting the whole file on every save — was confined to an
  opt-in mode. Choosing 1000px PNG made 50–100 MB the *default* board size,
  which moved that weakness into the common case. Meanwhile the flat file's
  advantage (surviving Slack and Gmail uploads) stopped mattering, because
  boards that large can't use those transports anyway.

  Preserving original formats later brought Standard-mode boards back down to
  10–20 MB, which weakens that specific argument — but the package decision
  stands. Full mode is still 70–150 MB, where incremental save matters most,
  and a package costs nothing at 20 MB. Reversing it again would be churn, not
  improvement.
- **Encoding**, twice. A mixed JPEG/PNG rule was proposed first, to keep
  photos small. It was replaced by an all-PNG rule, which removed the
  `isOpaque` field that existed only to choose between encoders — but all-PNG
  turned out to inflate Full mode badly, since a 3 MB JPEG re-encoded to PNG
  becomes 25–35 MB. Preserving each image's original format supersedes both:
  it removes the inflation entirely, and as a side effect brings Standard-mode
  boards down to roughly 10–20 MB, which is emailable again.

## Format

```
MyBoard.mozaic/            package; one file to Finder, AirDrop, iCloud Drive
  manifest.json
  images/
    <uuid>.jpg             extension follows each image's own format
    <uuid>.png
    <uuid>.heic
```

`manifest.json` carries no image bytes, so it stays small and inspectable:

```json
{
  "formatVersion": 1,
  "board": {
    "projectName": "Untitled Project",
    "createdBy": "Anonymous",
    "projectDescription": "",
    "showBoardInfo": true,
    "gridGap": 10,
    "cellRadius": 10,
    "quality": "standard",
    "rows": [
      { "id": "<uuid>", "module": "vlong2short",
        "slots": ["<uuid>", null, "<uuid>", null] }
    ],
    "tray": ["<uuid>"]
  },
  "images": [
    { "id": "<uuid>", "contentType": "public.jpeg",
      "pixelWidth": 1000, "pixelHeight": 750 }
  ]
}
```

Rows and tray hold **IDs, not bytes**. An image that is both placed and in the
tray is stored once — this is what makes saving the tray affordable instead of
doubling the file. Image dimensions and content type live in the manifest, so layout and
re-encoding decisions never require decoding the image.

`Module` already has stable `String` raw values, so it encodes directly. Those
raw values are now a persistence contract and must not change.

`rows` is variable-length even though the UI renders exactly 6. This costs
nothing today and avoids a format migration if rows become addable later.

### Versioning

`formatVersion` is 1. A reader encountering a higher version fails with a
readable "created by a newer version of Mozaic" error rather than a decode
crash. There are no existing documents in the wild, so version 1 is greenfield
and no migration path is needed.

### Incremental save

`fileWrapper(snapshot:configuration:)` receives `configuration.existingFile`,
the previously written wrapper. Unchanged image children are reused from it by
reference rather than re-encoded, so a save writes the manifest plus only the
images that actually changed.

Garbage collection falls out of this for free: only IDs still reachable from
`rows` or `tray` get a wrapper, so an unreferenced image is dropped by simply
not being written. No reference counting.

## Runtime architecture

### `MozaicDocument: ReferenceFileDocument`

`ReferenceFileDocument`, not `FileDocument`. `ProjectModel` is an `@Observable`
class; the value-type `FileDocument` would force it to become a struct and
fight the existing design. `ReferenceFileDocument` also supplies the
`UndoManager` that undo depends on.

```swift
@MainActor
final class MozaicDocument: ReferenceFileDocument {
    typealias Snapshot = BoardSnapshot
    static var readableContentTypes: [UTType] { [.mozaicBoard] }

    let model: ProjectModel

    init()
    init(configuration: ReadConfiguration) throws
    func snapshot(contentType: UTType) throws -> BoardSnapshot
    nonisolated func fileWrapper(snapshot: BoardSnapshot,
                                configuration: WriteConfiguration) throws -> FileWrapper
}
```

The project builds in Swift 6 language mode with `MainActor` default
isolation, which makes the snapshot boundary do real work here:
`fileWrapper(snapshot:configuration:)` must be `nonisolated` so encoding
happens off the main actor, and the compiler therefore requires
`BoardSnapshot` to be `Sendable`. It is — `Board` is a Codable value type and
`[UUID: Data]` is Sendable. Taking the snapshot is cheap because `Data` is
copy-on-write.

### `ImageStore`

Single owner of image bytes, and the only type that knows about encoding.

```swift
@MainActor @Observable
final class ImageStore {
    private(set) var data: [UUID: Data]
    @ObservationIgnored private var decoded: [UUID: Image]

    func image(for id: UUID) -> Image      // memoized
    func bytes(for id: UUID) -> Data?
    func add(_ imageData: Data, quality: ImageQuality) throws -> UUID
}
```

The `decoded` cache is `@ObservationIgnored` so filling it does not invalidate
views. See Risks — this cache is the single most important part of the design
to get right.

### `ProjectModel` changes

`imgC: [MbRow]` where `MbRow.image: [Image]` becomes slots of `UUID?`.
`selectedPHImages: [Image]` becomes `tray: [UUID]`. The model stops holding
images entirely and holds identifiers; views resolve them through
`ImageStore`. `gridGap`, `cellRadius`, and the rest carry over unchanged.

## Drag and drop

The current payload is `Image`, which cannot survive this design: recovering
bytes from a dropped `Image` requires `ImageRenderer`, which rasterizes a
SwiftUI view. That would silently re-compress every image on every drag. This
is a latent bug today and becomes a correctness problem once images are
persisted.

Replace it with a `Transferable` that handles both origins:

```swift
enum DroppedImage: Transferable {
    case reference(UUID)              // dragged within the app
    case external(Data, UTType)       // from Photos, Finder, another app

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mozaicImageReference)
        DataRepresentation(importedContentType: .png)  { .external($0, .png)  }
        DataRepresentation(importedContentType: .jpeg) { .external($0, .jpeg) }
        DataRepresentation(importedContentType: .heic) { .external($0, .heic) }
        DataRepresentation(importedContentType: .tiff) { .external($0, .tiff) }
        DataRepresentation(importedContentType: .gif)  { .external($0, .gif)  }
    }
}
```

In-app drags then move a UUID rather than pixels, which should make the hot
path materially cheaper than it is today. External drops go through the import
pipeline below.

`.mozaicImageReference` is a private UTI used only for in-process drags.

## Image pipeline

**Images keep the format they arrived in.** Mozaic never converts between
formats; a JPEG stays a JPEG, a PNG stays a PNG. Re-encoding happens only as a
side effect of downscaling, and always back to the source's own format.

Import, from any source (`fileImporter`, `PhotosPicker`, external drop):

1. Identify the content type. Reject anything that isn't an image.
2. If `quality == .full`, **store the original bytes verbatim** — no decode, no
   re-encode, nothing to lose.
3. If `quality == .standard` and the longest edge exceeds 1000px, decode,
   scale to 1000px preserving aspect ratio, and re-encode to the *same*
   content type (JPEG at 0.85, PNG lossless, HEIC at 0.85).
4. If `quality == .standard` and the image is already within the cap, store
   the original bytes verbatim. Never re-encode an image that doesn't need
   resizing — that would lose quality for nothing.
5. Store under a fresh UUID; record content type and pixel dimensions in the
   manifest.

Round-tripping is supported for PNG, JPEG, HEIC, and TIFF. **Any other format
— GIF being the realistic case, since `fileImporter` accepts it — is stored
verbatim and never downscaled**, because re-encoding it would either change
its format or destroy it (an animated GIF has no sensible single-frame
re-encode). Such images are exempt from the cap, and the size cost is
accepted.

The largest module renders a 310pt slot, so 1000px covers a 3× export of even
the biggest cell with headroom. Because any image can be dragged into any
slot, sizing targets the largest slot rather than the slot it first landed in.

Format preservation makes Standard mode substantially cheaper than the earlier
all-PNG rule: a 1000px photo is ~200–400 KB as JPEG rather than ~2 MB as PNG,
putting a full board near 10–20 MB. Full mode stores originals, so a board of
12-megapixel photos runs 70–150 MB — large, but honest, with no inflation.

### Tray cap

The cap bounds **tray membership only**, never the store. Evicting an unplaced
image can never remove one that is on the board. FIFO eviction at 30, and the
user is told when it happens.

### Reduce File Size

An explicit command that re-encodes every stored image down to the Standard
cap and reports bytes saved. Each image is re-encoded to its own format, and
images already within the cap — or in a format that isn't round-trippable —
are left untouched.

This is **destructive and not undoable** — the discarded detail is gone, so
registering it with the `UndoManager` would be a lie. It requires
confirmation. On macOS, Versions still offers a way back; on iPadOS it does
not, and the confirmation copy should reflect that.

## Undo

Every mutation registers with the `UndoManager` from the environment:

- dropping an image into a slot (and clearing a slot)
- changing a row's module
- adding to / removing from the tray
- `gridGap` and `cellRadius` edits, coalesced so a slider drag is one undo
  step rather than hundreds
- `projectName`, `createdBy`, `showBoardInfo`

Excluded: Reduce File Size, per above.

## App structure

`MozaicApp` swaps `WindowGroup` for `DocumentGroup`. This provides the system
document browser on iPadOS and New/Open/Save/Duplicate/Rename/Versions plus
autosave on macOS. `ContentView` stops owning `@State pm` and receives the
document.

`Info.plist` gains the type declarations (the file already exists and is wired
up; `LSSupportsOpeningDocumentsInPlace` is already set):

```xml
<key>UTExportedTypeDeclarations</key>
<array><dict>
  <key>UTTypeIdentifier</key><string>com.mb.unicorn.mozaic.board</string>
  <key>UTTypeDescription</key><string>Mozaic Board</string>
  <key>UTTypeConformsTo</key>
  <array>
    <string>com.apple.package</string>
    <string>public.composite-content</string>
  </array>
  <key>UTTypeTagSpecification</key>
  <dict>
    <key>public.filename-extension</key><array><string>mozaic</string></array>
  </dict>
</dict></array>

<key>CFBundleDocumentTypes</key>
<array><dict>
  <key>CFBundleTypeName</key><string>Mozaic Board</string>
  <key>LSItemContentTypes</key>
  <array><string>com.mb.unicorn.mozaic.board</string></array>
  <key>CFBundleTypeRole</key><string>Editor</string>
  <key>LSHandlerRank</key><string>Owner</string>
</dict></array>
```

The existing PNG export and `ShareLink` stay untouched. They are
complementary: share a *picture* for people who only want to look, share the
*document* for people who will edit.

`projectName` remains a document field independent of the filename, because
`BottomInfo` draws it into the exported image. It is presentation, not
identity.

## Removals

- `Mozaic/Models/MDataModel.swift`
- the `ModelContainer` and `SwiftData` import in `MozaicApp.swift`

Nothing reads or writes them, the container is `isStoredInMemoryOnly`, and
this format supersedes them.

## Files

New:

- `Mozaic/Document/MozaicDocument.swift`
- `Mozaic/Document/BoardManifest.swift` — `BoardFile`, `Board`, `Row`,
  `StoredImageMeta`, `ImageQuality`
- `Mozaic/Document/ImageStore.swift`
- `Mozaic/Document/ImageCoder.swift` — content-type sniffing, downscale, and
  same-format re-encode, per platform
- `Mozaic/Document/UTType+Mozaic.swift`
- `Mozaic/Moodboard/DroppedImage.swift`

Modified: `MozaicApp.swift`, `ContentView.swift`, `ProjectModel.swift`,
`MbImage.swift`, `Modules.swift`, `bottomBar.swift`, `BoardSettings.swift`,
`Info.plist`, `project.pbxproj`.

`project.pbxproj` is `objectVersion = 56` with an explicit file list and no
synchronized folders, so every new file needs both a `PBXFileReference` and a
`PBXSourcesBuildPhase` entry. A missed build-phase entry fails silently — the
file compiles nowhere and nothing references it.

## Error handling

| Condition | Behaviour |
|---|---|
| Missing or corrupt `manifest.json` | Throw `CocoaError(.fileReadCorruptFile)` |
| `formatVersion` higher than supported | Readable "created by a newer version" error |
| Manifest references an image file that is absent | Render a placeholder in that slot; open the document anyway |
| Image file present but undecodable | Same as absent |
| Import of an unsupported or corrupt image | Reject that image, report it, leave the board untouched |
| Image whose bytes disagree with its extension | Trust the bytes; record the sniffed type |
| Round-trippable format fails to re-encode | Fall back to storing the original bytes rather than losing the image |

Partial-data tolerance on open is deliberate. A board that lost one image
should still open with the other 23.

## Testing

`MozaicTests` is XCTest boilerplate with no assertions; move it to Swift
Testing. The design deliberately concentrates logic in pure, UI-free types so
it can be covered:

- `BoardFile` round-trip encode/decode, including empty slots and an empty tray
- rejection of a higher `formatVersion`
- garbage collection: unreferenced images are dropped, referenced ones survive
- tray eviction at the cap, and that eviction never removes a placed image
- downscale arithmetic: aspect ratio preserved, no upscaling of small images,
  the 1000px boundary itself
- format preservation: a JPEG in is a JPEG out, a PNG in is a PNG out; an
  image already under the cap comes back byte-identical rather than re-encoded;
  Full mode returns the original bytes untouched; a GIF is stored verbatim and
  exempt from the cap
- content type is identified from the bytes, not the filename extension
- `Module` raw values, pinned as a persistence contract

### Step zero: the test targets are empty

`xcodebuild test` does not currently run on either platform, and the cause is
not signing. **The test source files are not in the Xcode project at all** —
`MozaicTests.swift`, `MozaicUITests.swift`, and
`MozaicUITestsLaunchTests.swift` exist on disk but have no `PBXFileReference`
and no `PBXSourcesBuildPhase` entry. Both test targets therefore compile zero
files and produce bundles with no executable.

The two platforms report this differently, which is why it read as a signing
problem at first:

- iPadOS: `Failed to load the test bundle … its executable couldn't be located`
- macOS: `Command CodeSign failed`, signing an empty bundle

So the suite has never run since the project was created. Fixing it is
mechanical — add the three files to their targets — and it must happen first,
because every test in this design is unrunnable until it does.

This is a concrete instance of the `objectVersion = 56` explicit-file-list
hazard noted under Files: a source file that is not wired into a build phase
fails silently rather than erroring.

## Risks

**The decode cache.** Today `imgC` holds decoded `Image` values, which is why
rendering is cheap. Commit 6115747 ("Optomization to fix langyness…") shows
this path has already been a problem once — it moved `MbImage` off
`@Environment` onto an explicitly passed `ProjectModel` for exactly this
reason. Decoding per frame instead of per session would reintroduce that lag
in a worse form. The memoized cache in `ImageStore` is the mitigation, and it
needs to be verified under a full board of 1000px PNGs, not an empty one.

**Drag payload change.** Touches the same hot path. Moving a UUID should be
strictly cheaper than the current `Image` payload, but it must be measured
rather than assumed.

**`FileWrapper` reuse.** Subtle in both directions: failing to reuse rewrites
every image on every save and forfeits the reason for choosing a package;
over-eager reuse writes stale images. Needs a test that saves, mutates one
image, saves again, and asserts what changed on disk.

**Full mode is unbounded.** Storing originals verbatim means a board's size is
whatever the user imports. Twenty-four 12-megapixel photos is 70–150 MB; a
board built from 48-megapixel ProRAW-derived exports would be far larger.
There is no inflation any more — the file is exactly as big as its inputs —
but there is also no ceiling. Mitigation is to surface the document's size in
the settings inspector next to the quality toggle, so the cost is visible at
the moment the user opts in, rather than discovered when sharing fails.

**Format sniffing.** Preserving format means trusting the declared content
type. A file whose extension disagrees with its actual bytes (a PNG named
`.jpg`) must be identified by content, not name, or the manifest will record a
lie and later re-encoding will fail. Identify from the data itself and treat
the extension as a hint only.

## Out of scope

- iCloud sync and CloudKit sharing
- Live/real-time collaboration
- Adding or removing rows in the UI (the format allows it; the UI does not)
- Retroactive quality changes beyond the Reduce File Size command
- Migrating any pre-existing data — none exists
