# CLAUDE.md

Guidance for Claude Code (and other AI coding agents) working in this repo. Read `PROJECT_CONTEXT.md` for full background, rationale and the API contract. This file is the short, operational version. If the two disagree, ask the user.

## What this project is

An iPhone fitness app (SwiftUI, iOS 17+) with a **Firebase** backend (Anonymous Auth, Firestore, AI Logic for Gemini, App Check; decision D11 in `PROJECT_CONTEXT.md`, replacing the original FastAPI plan), built for the HackNC hackathon. The SAM 3D scan worker is still a separate Python GPU service. A body scan produces biometrics (neck, chest, waist, hips, Navy body-fat estimate) that feed three sections: **Calorie** (meal photo/text → macros), **Coach** (Gemini-generated workout plan, set/RIR logging, chat), and **Game** (calorie ring, Hunter Rank, evolving avatar). Gemini is the core AI. Photon iMessage, ElevenLabs voice and Tiger Data are stretch.

## Repo layout

```
ios/FitQuest/           SwiftUI app (Features/{Auth,Onboarding,Calorie,Dashboard,Workout,Gym}, Core/{Data,Design,Logic,Models,Firebase})
ios/FitQuest/Core/Firebase/  everything that imports a Firebase module (excluded from ios/Package.swift)
backend/api/            FastAPI app: routers/, services/, schemas.py, tests/
backend/worker/         GPU scan service (SAM 3D Body) + measure.py (pure functions)
backend/sidecar/        Node + spectrum-ts, Photon only (stretch)
docs/                   notes, scan-bakeoff.md
```

This layout is the plan. If the repo differs, trust the repo and update this section.

## Commands

These are the intended commands. Set them up early and keep this list accurate; do not invent others.

```
# API
cd backend/api && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt
uvicorn api.main:app --reload --port 8000        # run from backend/
pytest backend/api/tests

# Worker (needs a GPU; usually run in Colab, see backend/worker/colab_setup.ipynb)
pytest backend/worker/tests                       # measure.py tests run on CPU with a sample mesh

# iOS: open ios/FitQuest.xcodeproj in Xcode; run on a real device for Vision/camera work
cd ios && swift test                              # app logic tests on macOS (Firebase code is excluded)
xcodebuild build -project ios/FitQuest.xcodeproj -scheme FitQuest -destination 'generic/platform=iOS Simulator'
```

Firebase notes: put the gitignored `GoogleService-Info.plist` in `ios/FitQuest/` (without it the app runs on sample data). Firebase iOS SDK is pinned to 12.x because 13.x requires Xcode 26.2+. Any file that imports a Firebase module must live in `Core/Firebase/` (or `App/FitQuestApp.swift`), because `ios/Package.swift` builds the same sources for macOS tests without Firebase; reach it from app code through protocols such as `FoodAnalyzing`.

## Hard rules (do not break these)

1. **Never put a Gemini, ElevenLabs, Photon or other third-party key in the iOS app or in git.** Firebase AI Logic holds the Gemini key. Never commit `GoogleService-Info.plist`, `Secrets.plist` or App Check debug tokens.
2. **App Gemini calls go through Firebase AI Logic in `Core/Firebase/FirebaseFoodAnalyzer.swift`** (the direct-REST `GeminiFoodAnalyzer` is legacy, kept only as a fallback). The model name lives in `GeminiFoodAnalyzer.defaultModel` (`gemini-3.8-flash`); never hard-code it elsewhere. Do not use Gemini 1.5 or 2.5.
3. **Gemini 3.x request config**: do not send `temperature`, `top_p`, `top_k` or `candidate_count`. `thinking_level` may be `low`, `medium` or `high`, never `minimal`. Check the current `google-genai` docs for exact call syntax before changing the wrapper.
4. **Compute numbers in code, not with the LLM**: BMR/TDEE/macros, Navy body fat, XP/rank, load progression. Gemini writes content (plans, explanations, food estimates), and its JSON output is validated before use.
5. **Use JSON schemas and non-streaming calls for structured output.** Use streaming only for chat text.
6. **Label every scan- or photo-derived number an "estimate"** in UI text, API docs and comments. Do not claim tape-measure or clinical accuracy.
7. **Privacy**: body photos are sensitive. Never log them, never commit them, never send them to Gemini unless the user explicitly asks the coach about their physique. The worker deletes photos and meshes after responding. Convert uploads to JPEG (HEIC breaks OpenCV).
8. **Safety clamps live in code**: calorie target never below BMR or the hard floor (about 1,200 kcal women / 1,500 kcal men); cut deficit capped at about 500 kcal; no diagnoses or medication advice in prompts; refer pain, injury, pregnancy and disordered-eating signs to a professional.
9. **The scan has two methods behind one interface** (`sam3d` worker and `vision_navy` on device). The app must work with the worker down: on error/timeout the API returns `503 {"fallback":"on_device"}`. Build and test the on-device path first.
10. **The Photon SDK (`spectrum-ts`) is TypeScript-only.** Keep the Node sidecar free of business logic; it only forwards messages to the Python API over loopback.

## Conventions

- Pydantic models in `backend/api/schemas.py` are the single source of truth for the API. Mirror them as Swift `Codable` types; change both together.
- Swift: SwiftUI + `@Observable`, SwiftData for local persistence, async/await networking, no force-unwraps in production paths. Handle `nil` biometric fields (any field may be missing).
- Python: type hints everywhere, small pure functions for anything numeric (`navy.py`, `targets.py`, `xp.py`, `measure.py`), each with unit tests.
- Units: cm and kg in storage and the API; convert to inches only inside the Navy formula. `bodyFatPercentage` in HealthKit is a 0–1 scalar.
- Keep functions and files small; prefer clear names over comments. Comment *why*, especially around estimates and error bounds.
- Config in one place per side: `Config.swift` (iOS) and env vars (backend).

## Testing expectations

- Unit tests for: Navy formula (known inputs for male and female), ellipse circumference, Mifflin/Katch targets and clamps, XP/rank thresholds, load-progression rules, JSON validation of Gemini output (with canned fixtures), `measure.py` slicing on a sample mesh.
- Do not call the real Gemini API in unit tests; use fixtures. One manual smoke script may call it.
- Vision/camera code must be verified on a real device (the Simulator lacks required support).
- A change is not done until tests pass and the app still builds. If you cannot run something (GPU, device), say so instead of claiming it works.

## Working style for this repo

- Prefer the smallest change that works; this is a hackathon, but do not skip validation of model output.
- Before adding a feature, check the cut list in `PROJECT_CONTEXT.md` section 20; do not build stretch items (Tiger Data, voice, Photon) before the three core sections work end to end.
- Do not vendor the `sam-3d-body` repo or weights. Do not commit photos, scans, meshes, `.env`, or Colab tunnel URLs.
- Keep Meta's SAM license notice and credit when the worker is used.
- When facts are uncertain (see "Unverified claims" in `PROJECT_CONTEXT.md`), say so in code comments and docs rather than asserting them.
- Update `PROJECT_CONTEXT.md` and this file when a decision changes.

## Where to look

- Decisions and rationale: `PROJECT_CONTEXT.md` sections 2 and 20
- Scan pipelines and the bake-off protocol: sections 8.2–8.5
- Prompts and schemas: sections 9.2, 10.1–10.3
- XP/rank/avatar defaults (all tunable): section 11
- API contract: section 15
