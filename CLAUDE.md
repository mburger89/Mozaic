# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Mozaic is a SwiftUI moodboard app — the user drops images into fixed-layout grid "modules" and exports the whole board as a PNG. It is a document-based app (`DocumentGroup`/`ReferenceFileDocument`): each board is a `.mozaic` package on disk. Single Xcode project, no package manager, no third-party dependencies.

**`AGENTS.md` in the repo root holds the mandatory Swift/SwiftUI style rules for this project. Read it before writing code.** The codebase was swept for violations of its "Never/Always" API rules and is currently clean; keep it that way. Two structural rules are *not* yet satisfied, because both need `project.pbxproj` surgery (see "Adding or renaming files" below): several files declare more than one type (`Modules.swift` has 9, `ModWrapper.swift` has 4, `ContentView.swift` has 2), and two filenames don't match the type inside (`bottomBar.swift` → `BottomBar`, `Bottominfo.swift` → `BottomInfo`).

## Build & test

Single scheme `Mozaic`; targets `Mozaic`, `MozaicTests`, `MozaicUITests`. `SDKROOT = auto` — the same target builds for both macOS and iOS/iPadOS, so **always specify a destination**.

```sh
# Build (macOS)
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' build

# Build (iPad simulator - app target is TARGETED_DEVICE_FAMILY = 2, iPad only;
# an iPhone destination fails with "doesn't match any of Mozaic.app's targeted device families")
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build

# Test — run the full MozaicTests target, do not narrow with -only-testing
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test
```

**MozaicTests uses Swift Testing (`@Test`), not XCTest**, and it runs (77 test-case passes as of this writing, from 75 `@Test` functions — one is parameterized over 3 inputs). Count real passes reliably with:

```sh
xcodebuild ... test 2>&1 | grep -cE "^Test case .* passed"
```

**`-only-testing:` narrowed below the whole `MozaicTests` target, combined with `-parallel-testing-enabled NO`, can silently report success with zero tests run.** Confirmed by hand: `xcodebuild ... -only-testing:MozaicTests/SmokeTests test -parallel-testing-enabled NO` prints a legacy XCTest-style summary — `Test Suite 'MozaicTests.xctest' passed … Executed 0 tests, with 0 failures` — and still exits `** TEST SUCCEEDED **`, even though the real Swift Testing runner further down the *same log* did run and pass the one test. A script that checks the exit code, or greps for that legacy summary line, is fooled. Avoid the combination: run the full target, without `-parallel-testing-enabled NO`, and count with the grep above.

`MozaicUITests` is excluded from both `Mozaic.xctestplan`'s `testTargets` list *and* the scheme's own `TestAction/Testables` list — these are two independent places and editing only one does not stop `xcodebuild test` from building (and thus potentially trying to run) that target. It was excluded because its Xcode-generated boilerplate does not compile under this project's `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: the `XCTestCase` overrides (`setUpWithError`, `runsForEachTargetApplicationUIConfiguration`, etc.) get inferred as `@MainActor` by the default-isolation setting, which clashes with the nonisolated superclass declarations. Re-enabling it needs explicit `nonisolated` on those overrides.

A change that compiles on macOS can still break iOS — much of the image/render code is behind `#if os(macOS)` / `#if os(iOS)`, and only one branch is type-checked per destination. Build both after touching anything image- or export-related.

App target deploys to iOS 26.0 / macOS 26.0; the test targets are still on 17.5 / 14.5. The project builds in **Swift 6 language mode** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`, so everything is main-actor isolated unless you opt out — that is why almost nothing needs an explicit `@MainActor`. Anything you move off the main actor (a `Task.detached`, a `nonisolated` helper) must carry `Sendable` values across the boundary. **SwiftLint is not installed** on this machine, so AGENTS.md's lint gate cannot actually be run here — treat the style rules as reviewed by eye instead.

## Architecture

### `MozaicDocument` → `ProjectModel` → `ImageStore`

SwiftData and the old `MDataModel` are gone. The document stack is now:

- **`MozaicDocument`** (`Document/MozaicDocument.swift`) — a `ReferenceFileDocument` (chosen over `FileDocument` because `ProjectModel` is a reference-type `@Observable` class, and because `ReferenceFileDocument` supplies the `UndoManager`). Owns one `ProjectModel` (`model`) and one `BoardMirror` (`mirror`).
- **`ProjectModel`** (`Models/ProjectModel.swift`) — the `@Observable`, `@MainActor` runtime source of truth: a `Board` (layout, settings, and *UUIDs* — never decoded images) plus a `let images: ImageStore`.
- **`ImageStore`** (`Document/ImageStore.swift`) — owns the actual image bytes (`[UUID: StoredImage]`) and memoizes `Image` decoding per ID, since views resolve an image by ID on every render pass and a full decode per call would put that in the render loop. A failed decode is memoized too (`decodeFailures`), so a corrupt image isn't retried every frame.

Rows and the tray both store `UUID`s into the same `ImageStore`, so an image that is both placed on the board and still sitting in the tray is stored exactly once.

### The `.mozaic` package format

A `.mozaic` document is a `FileWrapper` directory:

```
MyBoard.mozaic/
  manifest.json        — BoardFile: formatVersion, Board (rows/tray/settings, UUIDs only), [StoredImageMeta]
  images/
    <uuid>.<ext>        — raw image bytes, one file per stored image
```

**Mozaic never converts image formats.** `ImageCoder.contentType(of:)` sniffs the real format from the bytes (never trusts a filename extension), and the file on disk keeps that image's own extension. Downscaling (see Quality below) always re-encodes back into the source's own format; GIF and any multi-frame/animated source are excluded from re-encoding entirely (see `ImageCoder.isRoundTrippable` and the frame-count check in `ImageCoder.prepared`) because a naive re-encode would only touch frame 0.

Garbage collection falls out of the write path rather than being a separate pass: `MozaicDocument.makeFileWrapper` only ever writes images in `board.referencedImageIDs` (every ID reachable from `rows[].slots` or `tray`); anything in `ImageStore` that isn't referenced is simply never written, so it disappears from the next save with no reference counting anywhere.

### `BoardMirror` is what actually gets saved — read this before touching save/undo

This is the single most load-bearing piece of the document architecture, and it exists because of a crash discovered during development: **AppKit calls `ReferenceFileDocument.snapshot(contentType:)` (and `fileWrapper(snapshot:configuration:)`) from a background queue** (`-[NSDocument writeToURL:...]` on `com.apple.root.default-qos`), not the main actor. `ReferenceFileDocument` carries no actor annotation, so nothing in the SDK contracts that call to the main actor. A main-actor-isolated `snapshot(contentType:)` only compiles behind `@preconcurrency` and then traps in `_checkExpectedExecutor` the first time the user presses Cmd+S.

So `snapshot(contentType:)` is `nonisolated` and just reads `mirror.snapshot` — a `Mutex`-protected `BoardSnapshot` (`Document/BoardMirror.swift`) that `ProjectModel` pushes a fresh, wholesale-replaced copy into after *every* mutation. Consequences that matter for anyone changing `ProjectModel` or `ImageStore`:

- **`ProjectModel.board` is `private(set)`.** The only way to mutate it is `mutateBoard(_:)` (private) or `restore(_:)` (public, used by undo/revert) — both call `syncMirror()` afterward. This is deliberate: it makes the compiler reject a new mutating method that forgets to sync the mirror, rather than relying on someone remembering.
- **`ImageStore.didChange` is wired to `ProjectModel.syncMirror()`** in `ProjectModel.init`, so a caller that mutates `images` directly — bypassing every `ProjectModel` method, e.g. `pm.images.reduceFileSize()` called straight from the inspector — still keeps the mirror correct.
- **A mutation that reaches neither path is silently lost on save, with no error anywhere.** There's no assertion, no test hook that catches it structurally — a direct write to some future stored property that isn't routed through `mutateBoard`/`syncMirror`/`didChange` would just not appear in the next save.

### Immutable bytes per ID — the one thing incremental save depends on

Image bytes never change under a given `UUID`; any edit that changes an image mints a new ID for the result. `ImageStore.insert(_:for:)` (the document-read path) enforces this by being insert-if-absent — reinserting under an existing ID is a no-op (logged in DEBUG, not trapped, so one bad call can't take down a whole document read). This invariant is what lets `MozaicDocument.makeFileWrapper` reuse an existing `FileWrapper` for an image whose filename (`<uuid>.<ext>`) already exists in the previous save, instead of rewriting every image's bytes on every save.

**The one deliberate exception is `ImageStore.reduceFileSize()`** ("Reduce File Size" in the settings inspector), which replaces the bytes stored under an existing ID with a downscaled re-encode. Because that breaks the "same filename ⇒ same bytes" assumption, `makeFileWrapper` additionally compares the *pixel dimensions* recorded in the previous save's `manifest.json` against the current `StoredImageMeta` before reusing a wrapper — a dimension mismatch means the bytes changed, so it's rewritten; the check only ever reads the small manifest, never image bytes, to reach this conclusion. Skipping this check would leave a save after "Reduce File Size" writing the old, pre-reduction bytes back out.

`reduceFileSize()` is also skip-and-continue rather than all-or-nothing: an image whose bytes fail `ImageCoder.prepared` (reachable because `insert` tolerates corrupt bytes at document-read time) is left untouched, `ReductionOutcome.failedCount` reports how many were skipped, and every other image still gets reduced.

### Board rendering pipeline

```
ContentView  (owns document: MozaicDocument, computed `pm` = document.model)
  └ MoodBoardMain      LazyHGrid, 2 fixed rows over pm.board.rows
      └ ModuleWrapper  switches on Row.module → one of 8 layout views, built from an MbCell
          └ Vlong2Short / FourShort / OneCell / …   (Moodboard/Modules.swift)
              └ MbImage   one image slot: resolves a UUID? through pm.image(for:), draggable source + dropDestination
```

`Row.slots` is `[UUID?]`, always exactly 4 entries (layouts using fewer just ignore the tail — `MozaicDocument.slotsPerRow` and `MozaicDocument.read` enforce this on every row at document-open time, since the views subscript `slots[0...3]` without bounds-checking). `MbImage` resolves its `imageID: UUID?` through `pm.image(for:)`, which forwards to `ImageStore.image(for:)`.

Drag and drop moves `DroppedImage` (`Moodboard/DroppedImage.swift`), not raw pixels: `.reference(UUID)` for an in-app drag between slots/tray, `.external(Data)` for a drop arriving from outside the app. `ProjectModel.accept(_:row:slot:)` resolves either case into a `place(_:row:slot:)` call, importing new bytes via `importImage` for the external case.

Adding a layout means: a case in `Module` (with raw value, `assetName`, and `displayName`), a view struct in `Modules.swift`, and a case in `ModuleWrapper`'s switch. The long-press picker is driven off `Module.allCases`, so it picks up the new layout automatically — but it lays out in rows of four, so a count that isn't a multiple of four leaves a ragged last row. `Module`'s raw values are the on-disk format for `Row.module` in `manifest.json`; changing one breaks any board saved with the old value.

### Sizing is hard-coded and cross-cutting

Cell geometry is split between `ProjectModel.baseCellWidth` (155.0, feeding the `cellWidth` / `twoCellWidth` / `halfGridGap` computed properties) and magic numbers still inline elsewhere: `310×310` on the `ModuleWrapper` frame, `300 + pm.gridGap` in `MoodBoardMain`'s `GridItem`s. `gridGap` and `cellRadius` are live-bound to sliders in `BoardSettings`, so changing one constant without the others produces visibly misaligned modules. There is no layout container doing this math for you.

`gridGap` and `cellRadius` are `Double`, not `CGFloat`, because `.number` format styles (used by the grid-gap `TextField`) only exist for `Double`. Convert explicitly at the geometry boundary rather than retyping the model.

### `pm` is passed two ways at once

`ContentView` computes `pm` from `document.model` and injects it with `.environment(pm)`. `MoodBoardMain` and `ModuleWrapper` read it via `@Environment(ProjectModel.self)`, but then pass it *explicitly* as a plain `var pm: ProjectModel` down into the layout views, `MbImage`, and `BottomBar` — this was a deliberate performance fix for drag/drop lag (commit `6115747`). Because `pm` now also carries `images: ImageStore`, that same explicit pass is what gets image bytes down to `MbImage`/`BottomBar` without going back through the environment. Previews therefore need both `.environment(ProjectModel())` and, for the lower-level views, an explicit `pm:` argument.

### Image in / image out

- **In:** `fileImporter` and `PhotosPicker`, both routed through `ProjectModel.importImage(_:)`, which calls `ImageStore.add(_:quality:)` (running `ImageCoder.prepared` under the document's current `Quality` setting) and appends the resulting UUID to `board.tray`, evicting the oldest tray entries past `Board.trayLimit` (30) — eviction only ever removes from the tray array, never from `ImageStore`, so it can never delete an image that's actually placed on the board. Drag-and-drop from outside the app goes through the same `importImage` via `ProjectModel.accept(_:row:slot:)`.
- **Out:** `ContentView.renderMoodBoard()` runs `ImageRenderer` over a fresh `MoodBoardMain().environment(pm)` and wraps the PNG in `MoodBoardImage`, a `Transferable` + `FileDocument` used by both `fileExporter` and `ShareLink`. There are separate macOS (`NSBitmapImageRep`) and iOS (`uiImage.pngData()`) implementations. Because export re-renders the view tree offscreen, anything that depends on the on-screen environment or container size will not appear in the exported PNG. `Moodboard/renderBoard.swift` is an empty stub.

### Adding or renaming files

`project.pbxproj` is `objectVersion = 56` with an **explicit file list** — not a `PBXFileSystemSynchronizedRootGroup`. A new `.swift` file dropped into a folder is **not** compiled until it is added to a `PBXSourcesBuildPhase`, and it fails *silently*: no error, no warning, the file just isn't part of any target. This isn't hypothetical — it's exactly why `MozaicTests`' source files existed on disk but had never been wired to the test target, and the suite had never run once before that was fixed.

**Use `Scripts/add_sources.rb` to add a source file**, rather than hand-editing `project.pbxproj` or relying on Xcode's own "Add Files" dialog to remember every target:

```sh
ruby Scripts/add_sources.rb <target> <group path, slash separated> <file paths...>
# e.g.
ruby Scripts/add_sources.rb MozaicTests MozaicTests MozaicTests/SomeNewTests.swift
```

It's idempotent (a file already in the target is skipped) and walks/creates the destination group in the project navigator to match. Renaming a file still means updating its `PBXFileReference` path directly — the script only adds, it doesn't rename.
