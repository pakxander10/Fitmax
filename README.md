# Fitmax

FitQuest — an iPhone fitness app for HackNC: meal logging, workout logging, and a game layer on top.

## iOS app (`ios/`)

Open `ios/FitQuest.xcodeproj` in Xcode 26, pick the **FitQuest** scheme and run on an iPhone (iOS 17+).
Set your signing team under *Signing & Capabilities* the first time.

The app opens on a login screen, then a three-step onboarding that works out daily calorie and
macro targets. Accounts and profiles are saved on the phone only for now; logged meals are kept in
memory, and workouts and the gym page still run on sample data.

Two API keys go in `ios/FitQuest/Secrets.plist` (gitignored; copy `Secrets.example.plist` to start):

- `GEMINI_API_KEY` — estimates food from meal photos and typed descriptions. The free tier allows
  about 20 requests a day per model.
- `SPOONACULAR_API_KEY` — finds the "Recommended meals": real recipes filtered by calories and diet,
  each with a link. Free key at spoonacular.com/food-api. Without it the list falls back to Gemini,
  and without either key to labelled samples.

**Hooking up Firebase:** the app only talks to two protocols, `AuthProviding` and `ProfileStoring`
(`Core/Data/`). Add a Firebase Auth type for the first and a Firestore type for the second
(`users/{uid}`, in the shape `UserProfile` encodes to), then pass them to `AppModel(auth:profiles:)`
in `RootView`. No screen needs to change.

```
ios/
  FitQuest/            app sources (the Xcode target syncs this folder; new files need no project edit)
    App/               entry point, root pager, AppModel (all UI state)
    Core/Design/       Frutiger Aero theme: sky background, glass cards, glossy controls
    Core/Logic/        pet level, mood, calorie targets and date maths (pure, unit-tested)
    Core/Models/       food, workout, social and profile types
    Core/Data/         sample data, Gemini food analysis, on-device accounts and profiles
    Features/          Auth, Onboarding, Calorie, Dashboard, Workout, Gym
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
