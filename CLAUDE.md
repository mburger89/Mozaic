# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Mozaic is a SwiftUI moodboard app — the user drops images into fixed-layout grid "modules" and exports the whole board as a PNG. Single Xcode project, no package manager, no third-party dependencies.

**`AGENTS.md` in the repo root holds the mandatory Swift/SwiftUI style rules for this project. Read it before writing code.** The codebase was swept for violations of its "Never/Always" API rules and is currently clean; keep it that way. Two structural rules are *not* yet satisfied, because both need `project.pbxproj` surgery (see below): several files declare more than one type, and two filenames don't match the type inside (`bottomBar.swift` → `BottomBar`, `Bottominfo.swift` → `BottomInfo`).

## Build & test

Single scheme `Mozaic`; targets `Mozaic`, `MozaicTests`, `MozaicUITests`. `SDKROOT = auto` — the same target builds for both macOS and iOS/iPadOS, so **always specify a destination**.

```sh
# Build (macOS)
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' build

# Build (iPad simulator - app target is TARGETED_DEVICE_FAMILY = 2, iPad only;
# an iPhone destination fails with "doesn't match any of Mozaic.app's targeted device families")
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic \
  -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M5)' build

# Test (Mozaic.xctestplan runs MozaicTests + MozaicUITests)
xcodebuild -project Mozaic.xcodeproj -scheme Mozaic -destination 'platform=macOS' test

# Single test / class
xcodebuild ... test -only-testing:MozaicTests/MozaicTests/testExample
```

**`test` does not currently run on either platform, and the cause is not signing.** The three test source files exist on disk but are not in the Xcode project — no `PBXFileReference`, no `PBXSourcesBuildPhase` entry — so both test targets compile zero files and produce bundles with no executable. The symptom differs by platform and is misleading on macOS:

- iPadOS: `Failed to load the test bundle … its executable couldn't be located`
- macOS: `Command CodeSign failed` (signing an empty bundle)

The suite has never run since the project was created. Fixing it means adding the files to their targets. Until then `build` is the only reliable signal. See "Adding or renaming files" — this is that hazard in the wild.

A change that compiles on macOS can still break iOS — much of the image/render code is behind `#if os(macOS)` / `#if os(iOS)`, and only one branch is type-checked per destination. Build both after touching anything image- or export-related.

App target deploys to iOS 26.0 / macOS 26.0; the test targets are still on 17.5 / 14.5. The project builds in **Swift 6 language mode** with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and `SWIFT_APPROACHABLE_CONCURRENCY = YES`, so everything is main-actor isolated unless you opt out — that is why almost nothing needs an explicit `@MainActor`. Anything you move off the main actor (a `Task.detached`, a `nonisolated` helper) must carry `Sendable` values across the boundary. SwiftLint is not installed.

## Architecture

### Two data models that are not yet connected

- **`ProjectModel`** (`Models/ProjectModel.swift`) — the `@Observable` runtime source of truth for everything on screen: board contents, grid gap, cell radius, project name/author, the image tray. Holds SwiftUI `Image` values directly.
- **`MDataModel`** (`Models/MDataModel.swift`) — the SwiftData `@Model`. The container in `MozaicApp.swift` is `isStoredInMemoryOnly: true`, and nothing reads or writes it yet. Its board storage is flattened into six numbered field pairs (`mbRowImgData1…6` / `module1…6`) mirroring the six rows of `ProjectModel.imgC`; the `modules` enum's `toString()`/`fromString()` and `ProjectModel`'s `imageToData`/`dataToImage` helpers exist to bridge the two but are currently unused. **Persistence is unimplemented — assume board state is lost on quit.** `Module`'s `String` raw values are the on-disk format for `module1…6`, so changing a raw value breaks any board saved once persistence lands.

### Board rendering pipeline

```
ContentView  (owns @State pm, toolbar, inspector, export)
  └ MoodBoardMain      LazyHGrid, 2 fixed rows over pm.imgC (6 MbRows)
      └ ModuleWrapper  switches on MbRow.module → one of 8 layout views
          └ Vlong2Short / FourShort / OneCell / …   (Moodboard/Modules.swift)
              └ MbImage   one image slot: draggable source + dropDestination
```

`pm.imgC` is `[MbRow]`, each row = a `Module` layout enum + exactly 4 `Image`s (layouts using fewer just ignore the tail). Every leaf `MbImage` is addressed by `indexes: [rowIndex, slotIndex]`; a drop calls `pm.writeToModel(items:indexs:)`, which writes `imgC[indexs[0]].image[indexs[1]]`.

Adding a layout means: a case in `Module` (with raw value, `assetName`, and `displayName`), a view struct in `Modules.swift`, and a case in `ModuleWrapper`'s switch. The long-press picker is driven off `Module.allCases`, so it picks up the new layout automatically — but it lays out in rows of four, so a count that isn't a multiple of four leaves a ragged last row.

### Sizing is hard-coded and cross-cutting

Cell geometry is split between `ProjectModel.baseCellWidth` (155.0, feeding the `cellWidth` / `twoCellWidth` / `halfGridGap` computed properties) and magic numbers still inline elsewhere: `310×310` on the `ModuleWrapper` frame, `300 + pm.gridGap` in `MoodBoardMain`'s `GridItem`s. `gridGap` and `cellRadius` are live-bound to sliders in `BoardSettings`, so changing one constant without the others produces visibly misaligned modules. There is no layout container doing this math for you.

`gridGap` and `cellRadius` are `Double`, not `CGFloat`, because `.number` format styles (used by the grid-gap `TextField`) only exist for `Double`. Convert explicitly at the geometry boundary rather than retyping the model.

### `pm` is passed two ways at once

`ContentView` owns `pm` as `@State` and injects it with `.environment(pm)`. `MoodBoardMain` and `Modulewrapper` read it via `@Environment(ProjectModel.self)`, but then pass it *explicitly* as a plain `var pm: ProjectModel` down into the layout views and `MbImage` (the environment line in `MbImage` is commented out) — this was a deliberate performance fix for drag/drop lag. `BoardSettings` takes it as `@Binding`. Previews therefore need both `.environment(ProjectModel())` and, for the lower-level views, an explicit `pm:` argument.

### Image in / image out

- **In:** `fileImporter` (security-scoped URL → platform image → `Image`) and `PhotosPicker` (`loadTransferable(type: Image.self)`), both appending to `pm.selectedPHImages`, which the `bottomBar` inspector tab renders as a tray of `draggable` sources.
- **Out:** `ContentView.renderMoodBoard()` runs `ImageRenderer` over a fresh `MoodBoardMain().environment(pm)` and wraps the PNG in `MoodBoardImage`, a `Transferable` + `FileDocument` used by both `fileExporter` and `ShareLink`. There are separate macOS (`NSBitmapImageRep`) and iOS (`uiImage.pngData()`) implementations. Because export re-renders the view tree offscreen, anything that depends on the on-screen environment or container size will not appear in the exported PNG. `Moodboard/renderBoard.swift` is an empty stub.

### Adding or renaming files

`project.pbxproj` is `objectVersion = 56` with an **explicit file list** — not a `PBXFileSystemSynchronizedRootGroup`. A new `.swift` file dropped in a folder will *not* be compiled until it is added to the `PBXSourcesBuildPhase`, and renaming a file means updating its `PBXFileReference` path too. Do it in Xcode where practical; hand-editing works but silently produces "file exists but nothing uses it" if you miss the build phase. This is why AGENTS.md's one-type-per-file rule is still outstanding in `Modules.swift` (9 types), `ModWrapper.swift` (4), `ProjectModel.swift` (2), and `ContentView.swift` (2).
