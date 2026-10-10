# Fitmax

FitQuest — an iPhone fitness app for HackNC: meal logging, workout logging, and a game layer on top.

## iOS app (`ios/`)

Open `ios/FitQuest.xcodeproj` in Xcode 26, pick the **FitQuest** scheme and run on an iPhone (iOS 17+).
Set your signing team under *Signing & Capabilities* the first time.

The app currently runs entirely on sample data — no backend, camera or persistence yet.

```
ios/
  FitQuest/            app sources (the Xcode target syncs this folder; new files need no project edit)
    App/               entry point, root pager, AppModel (all UI state)
    Core/Design/       colour and type tokens, shared components
    Core/Logic/        rank, calorie and date maths (pure, unit-tested)
    Core/Models/       food, workout and social types
    Core/Data/         sample data from the design prototype
    Features/          Calorie, Dashboard, Workout, Gym
    Resources/Fonts/   Saira Condensed, EB Garamond, JetBrains Mono (OFL)
  FitQuestTests/       unit tests
  Package.swift        builds the same sources for macOS so tests run without a simulator
```

### Tests

```sh
cd ios
swift test                                   # logic tests, on macOS, no simulator needed
FQ_RENDER_DIR=/tmp/fq swift test --filter RenderTests   # also writes a PNG of every screen
```

Rendered PNGs show yellow blocks where native controls (links, menus, text fields) sit; macOS cannot
snapshot those. They draw normally on iOS.

`xcodebuild -scheme FitQuest test` runs the same tests on a simulator once an iOS runtime is installed
(Xcode › Settings › Components).

Because the sources also compile for macOS, keep UIKit-only calls behind `#if os(iOS)`.
