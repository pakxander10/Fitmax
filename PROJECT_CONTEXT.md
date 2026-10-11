# PROJECT_CONTEXT.md — HackNC Fitness App (working title: "FitQuest")

Audience: any AI model or new teammate that needs full context to help build this project.
Last updated: 2026-10-10. Written from three team inputs plus the team's follow-up decisions plus a short round of web research.

How to read this file:
- Sections marked **[DECIDED]** are team decisions. Do not re-litigate them; build to them.
- Sections marked **[PROPOSED]** are defaults chosen by the planning assistant so work can start. They are reasonable but untested. Change them if testing says so, and update this file.
- Sections marked **[VERIFIED]** were checked against a primary page on 2026-10-10. Everything under "Unverified claims" (section 18) was not checked.
- If this file and the code disagree, the code is right; fix this file.

---

## 1. One-paragraph summary [DECIDED]

An iPhone app (SwiftUI, iOS 17+) with a Python backend. A user gives a few facts and one or two full-body photos. A body-scan pipeline turns the photos into **biometrics** (neck, chest, waist, hip circumference in cm, plus a Navy-formula body-fat estimate). Those biometrics, the user's goals, injuries and equipment feed three sections:

1. **Calorie** — snap a meal photo or type what you ate; Gemini returns structured nutrition estimates; a daily budget is computed in code.
2. **Coach (workouts)** — Gemini generates a science-based weekly program as JSON; the user logs sets, reps and reps-in-reserve (RIR); the plan adapts week to week. A streaming chat coach answers questions using the user's own data.
3. **Game (dashboard)** — a calorie ring with macro bars, trends, a "Hunter Rank" (Solo Leveling style) based on consistency, and an avatar that visibly evolves as the user progresses.

Built for a hackathon (HackNC, roughly 30 working hours, 3–4 people). Gemini is the core AI; Photon iMessage, ElevenLabs voice and Tiger Data are stretch prize tracks.

## 2. Hard decisions and why [DECIDED]

| # | Decision | Reason / consequence |
|---|---|---|
| D1 | **Body scan has two methods behind one interface**: (a) SAM 3D Body on a GPU worker, (b) on-device Vision silhouette + Navy formula. ~~Build (b) first.~~ **Update 2026-10-10: Hugging Face access was granted and the team chose (a) as the primary method; the worker is in `backend/worker/`. (b) remains the fallback on `503 {"fallback":"on_device"}`.** The worker authenticates the app with a Firebase ID token. | SAM 3D weights are gated on Hugging Face and the access request is **pending**. (b) has no external dependency, so it is the safety net and also the automatic fallback if the worker is down. |
| D2 | **The 3D mesh is used only to extract biometrics.** It is never shown to the user. | Removes the 3D viewer from the MVP. The avatar is a separate stock 3D model (D7). |
| D3 | **Which scan method is the default is decided by a tape-measure bake-off**, not by opinion. | No published accuracy test of SAM 3D Body for circumferences was found, and its repo documents no measurement output. See section 8.5. |
| D4 | ~~Backend is Python (FastAPI).~~ **Superseded by D11 (2026-10-10).** | Was a team choice. The GPU scan worker (D1) is still Python and still runs outside Firebase. Photon (D6) would now need its own small server. |
| D5 | **Gemini model: `gemini-3.8-flash`**, called from the Python backend with the `google-genai` SDK. Model name lives in one env var (`GEMINI_MODEL`). | It is the newest stable model on Google's models page (page updated 2026-10-09). Gemini 1.5 (mentioned in the original feature spec) is far behind; 2.5 is access-limited for new projects. |
| D6 | **Photon iMessage (stretch)** uses a Node sidecar running `spectrum-ts` that forwards messages to the Python API over loopback HTTP. | Spectrum's SDK supports TypeScript only; Python is announced as planned with no date. |
| D7 | **Avatar = stock 3D humanoid scaled by scan ratios**, with gear unlocked by rank. | Neither scan path needs to produce a displayable body. |
| D8 | **Scope = three sections: Calorie, Coach (workouts), Game (dashboard with calorie ring + avatar evolution).** | Team's explicit scope. Everything else is stretch. |
| D9 | **Voice onboarding with ElevenLabs only if time allows.** A typed form is the default and the fallback. | Reduces risk. |
| D10 | ~~All Gemini calls go through the Python backend.~~ **Superseded by D11 (2026-10-10):** Gemini calls go through **Firebase AI Logic** (Gemini Developer API). | The key still never ships in the app: Firebase holds it, and App Check guards the endpoint. Trade-off: the prompt lives in the app, so iMessage (stretch) cannot share it without a server. |
| D11 | **Backend is Firebase (2026-10-10)**: Anonymous Auth for identity, Firestore for data, AI Logic for Gemini, App Check against quota abuse. Firebase iOS SDK pinned to **12.x** (13.x needs Xcode 26.2+; the team has 26.1). | No server to host or keep alive during the hackathon; everything listed runs on the free Spark plan. Numbers (targets, XP, rank) are computed in Swift on device (`Core/Logic`); Cloud Functions would need the paid Blaze plan. Firebase cannot run the SAM 3D worker, so D1's worker stays a separate service. |

## 3. Glossary

- **Biometrics**: the record of body measurements in section 7.1.
- **Navy method**: US Navy circumference-based body-fat formula (Hodgdon & Beckett, 1984).
- **BMR / TDEE**: basal metabolic rate / total daily energy expenditure.
- **RPE / RIR**: rate of perceived exertion / reps in reserve (how many more reps you could have done).
- **MHR**: Momentum Human Rig, the parametric body mesh that SAM 3D Body outputs.
- **SAM 3D Body**: Meta's single-image full-body 3D mesh model (`facebookresearch/sam-3d-body`).
- **Worker**: the GPU service that runs SAM 3D Body. **API**: the main FastAPI service. **Sidecar**: the small Node process for Photon.
- **Hunter Rank**: the gamified level/rank shown on the Game tab.

## 4. System architecture [DECIDED, revised 2026-10-10 by D11]

Current architecture (Firebase):

```
┌──────────── iPhone app (SwiftUI, iOS 17+) ────────────┐
│ Calorie │ Workout │ Dashboard │ Gym                   │
│ Core/Logic: targets, XP, Navy maths (pure Swift)      │
│ Core/Firebase: setup, App Check, AI Logic analyzer    │
└───────┬──────────────────┬───────────────────┬────────┘
        │ Anonymous Auth   │ Firestore         │ AI Logic (App Check token)
        ▼                  ▼                   ▼
   Firebase Auth      Firestore (us-east1)   Gemini Developer API (gemini-3.8-flash)

   Scan worker (SAM 3D Body, GPU) stays separate: Colab + tunnel, called only for scans.
```

Status: Auth, App Check (debug provider in Debug builds) and AI Logic food estimates are wired. `AppModel` state is still in memory; the Firestore layout below is PROPOSED and not yet written to.

Proposed Firestore layout (security rules enforce the same split):

```
gyms/{gymId}                         name, logo (entered by hand)
members/{uid}                        name, initials, gymID, isPrivate   ← any signed-in user can read
members/{uid}/details/card           level, streak, pet, week, song, atGym, since   ← hidden from non-friends if private
members/{uid}/friends/{friendUid}    since
friendRequests/{fromUid_toUid}       from, to, createdAt
users/{uid}                          xp, activeTemplateID               ← owner only (everything under users/)
users/{uid}/meals/{mealId}           day "YYYY-MM-DD", slot, time, name, kcal, protein, carbs, fat, source
users/{uid}/templates/{templateId}   name, exercises [...]
users/{uid}/sessions/{sessionId}     templateID, day, minutes, volume, sets, highlight
```

`Member.id` must move from initials to the Firebase `uid` before the social data goes live.

Original architecture (FastAPI), kept for reference:

```
┌──────────── iPhone app (SwiftUI, iOS 17+) ────────────┐
│ Onboarding │ Calorie │ Coach │ Game                   │
│ On-device scan fallback (Vision + Navy)               │
│ SwiftData (source of truth for UI) + HealthKit (opt.) │
└───────────────────────────┬───────────────────────────┘
                            │ HTTPS, Bearer device token
                            ▼
              ┌───────────────────────────┐        ┌──────────────────────────┐
              │ Python API (FastAPI, CPU) │──HTTP─▶│ Scan worker (FastAPI,GPU)│
              │ - Gemini via google-genai │        │ SAM 3D Body + mesh slice │
              │ - targets, plans, XP/rank │        └──────────────────────────┘
              │ - SQLite (opt. Postgres)  │
              └──────▲───────────┬────────┘
                     │ loopback  │ google-genai
          ┌──────────┴─────┐     ▼
          │ Photon sidecar │   Gemini API (gemini-3.8-flash)
          │ (Node, stretch)│
          └────────────────┘
```

Rules that follow from the architecture:
- The **API** is the only component that holds the Gemini key, the Photon secret and user data beyond the phone.
- The **worker** has no user data and no Gemini key. It receives a photo and a height and returns numbers. It deletes the photo after responding.
- The app must work with the worker **down**: on worker error or timeout, the app falls back to the on-device scan.
- Numbers (calories, macros, body fat, XP, rank, load progression) are computed in **code**. Gemini produces content (plans, text, estimates of food), never the authoritative arithmetic.

Hosting for the hackathon [PROPOSED]:
- Worker: Google Colab T4 (about 15 GB VRAM) exposed with a Cloudflare quick tunnel (`cloudflared tunnel --url http://localhost:8000`). The tunnel URL changes on every restart and requests are cut at roughly 100 seconds. Keep the URL in one config place. Backup: a teammate's NVIDIA PC or a paid cloud GPU.
- API: any always-on host or a teammate's laptop with a tunnel. It needs only CPU.

## 5. Repository layout [PROPOSED]

```
hacknc-fit/
├── CLAUDE.md                  # instructions for Claude Code in this repo
├── PROJECT_CONTEXT.md         # this file
├── README.md                  # how to run everything
├── ios/FitQuest/              # Xcode project
│   ├── App/                   # app entry, tab shell, Config.swift
│   ├── Features/{Onboarding,Calorie,Coach,Game,Scan}/
│   ├── Core/{API,Models,Storage,Health}/
│   └── Resources/             # avatar USDZ, thumbnails
├── backend/
│   ├── api/                   # FastAPI app
│   │   ├── main.py
│   │   ├── routers/{scan,food,plan,coach,dashboard,photon}.py
│   │   ├── services/{gemini,targets,xp,navy,context}.py
│   │   ├── schemas.py         # Pydantic models = the API contract
│   │   └── tests/
│   ├── worker/                # GPU scan service
│   │   ├── server.py
│   │   ├── measure.py         # pure functions, unit-tested
│   │   ├── colab_setup.ipynb
│   │   └── tests/
│   └── sidecar/               # Node, Photon only (stretch)
│       └── index.ts
├── docs/
└── .env.example
```

Do not vendor the `sam-3d-body` repo or its weights. Clone and install them at setup time. Never commit photos, scans, meshes or `.env` files.

## 6. Tech stack

- iOS: SwiftUI, SwiftData, Swift Charts, Vision, PhotosUI/AVFoundation, SceneKit (avatar), optional HealthKit and VisionKit (barcode). Minimum iOS 17 (`@Observable`, Vision 3D pose APIs).
- API: Python 3.11, FastAPI, uvicorn, Pydantic v2, `google-genai`, SQLite (SQLModel or plain `sqlite3`), optional Postgres for Tiger Data.
- Worker: Python 3.11, PyTorch, SAM 3D Body, `trimesh`, `scipy`, `opencv-python`, `numpy`. Set `PYOPENGL_PLATFORM=egl` in headless environments.
- Sidecar (stretch): Node 18.17+, TypeScript, `spectrum-ts`.
- Voice (stretch): ElevenLabs conversational agent.

## 7. Data model

### 7.1 Biometrics record [DECIDED shape, PROPOSED details]

Single schema returned by **both** scan methods:

```json
{
  "method": "sam3d | vision_navy | manual",
  "confidence": "low | medium | high",
  "height_cm": 178.0,
  "weight_kg": 74.5,
  "sex": "male | female",
  "neck_cm": 38.2,
  "chest_cm": 99.0,
  "waist_cm": 82.5,
  "hips_cm": 97.0,
  "body_fat_pct": 16.4,
  "body_fat_method": "navy",
  "measured_at": "2026-10-11T14:03:00Z",
  "user_edited_fields": ["waist_cm"]
}
```

Rules:
- Any field may be `null` if the method could not produce it. The UI must handle nulls.
- Every field is user-editable. Edited fields are listed in `user_edited_fields`; body fat is recomputed from the edited values.
- Hips are required for the female Navy formula; if missing, body fat is `null`.
- All values are **estimates**. UI and API text must say "estimate".

### 7.2 Core entities (names are PROPOSED; mirror them in SwiftData and the API schemas)

- `UserProfile`: id, sex, birth_year, height_cm, weight_kg, goal (`cut|maintain|lean_bulk`), target_weight_kg?, activity_level, training_history, injuries (list of strings), equipment (list), experience (`beginner|intermediate|advanced`), created_at.
- `Biometrics`: section 7.1, one row per scan.
- `FoodEntry`: id, logged_at, meal (`breakfast|lunch|dinner|snack`), name, grams, kcal, protein_g, carbs_g, fat_g, source (`photo|text|barcode|manual`), confidence, edited (bool).
- `Targets`: kcal, protein_g, carbs_g, fat_g, method (`mifflin|katch_mcardle`), computed_at.
- `WorkoutPlan`: id, week_start, days (list of `WorkoutDay`), rationale, generated_by_model, created_at.
- `WorkoutDay`: weekday, focus, exercises (list of `PlannedExercise`).
- `PlannedExercise`: exercise_id, name, muscle_group, sets, rep_range [lo, hi], target_rpe, rest_seconds, notes.
- `SetLog`: id, planned_exercise_id, set_index, weight_kg, reps, rir, failed (bool), note, logged_at.
- `GameState`: xp, level, rank, streak_days, last_active_date, unlocked_gear (list).
- `ChatMessage`: id, role, text, created_at (history is kept by the API per session; the app may cache).

## 8. Body scan (biometrics) — the most uncertain component

### 8.1 What is being measured
Neck, chest, waist and hip circumference in cm, plus body fat % from the Navy formula. These are **estimates**. Do not claim tape-measure accuracy anywhere (code, UI, pitch, Devpost).

### 8.2 Capture flow (one flow for both methods) [PROPOSED]
1. User enters height (cm) and weight (kg). Height is mandatory because a single photo has no absolute scale.
2. User takes a **front** full-body photo: one person, fitted clothing, arms slightly away from the body, feet apart, whole body in frame, phone at about waist height, roughly 2.5 m away, plain background, good light.
3. The app uploads it to `POST /v1/scan`. The API forwards to the worker.
4. If the worker returns biometrics, show them. If the worker errors, times out (suggest 25 s client timeout) or is unreachable, the API responds `503 {"fallback": "on_device"}` and the app asks for a **side** photo and runs the on-device pipeline.
5. The user reviews and can edit every number. Photos are deleted from the device sandbox after numbers are extracted (unless the user opts in to progress photos).
6. Convert images to **JPEG** before upload. HEIC breaks OpenCV on the server.

### 8.3 Method A — SAM 3D Body worker [VERIFIED facts / PROPOSED pipeline]
Verified facts:
- Code: `github.com/facebookresearch/sam-3d-body`. Weights are **not** in the repo.
- Hugging Face checkpoints (gated; request access on the model page, then log in with a read token via `huggingface_hub.login()`): `facebook/sam-3d-body-dinov3` (DINOv3-H+ backbone, 840M params) and the smaller `facebook/sam-3d-body-vith` (ViT-H, 631M params).
- It outputs a full-body mesh using the Momentum Human Rig (MHR), which decouples skeleton and surface shape.
- Python entry point (from the repo README, run with the repo root on `sys.path`):
  ```python
  from notebook.utils import setup_sam_3d_body
  estimator = setup_sam_3d_body(hf_repo_id="facebook/sam-3d-body-dinov3")
  outputs = estimator.process_one_image(rgb_image)   # list, one dict per detected person
  verts = outputs[0]["pred_vertices"]                # ~18,439 x 3
  faces = estimator.faces
  ```
- From the team's earlier notes (treat as likely, re-check when running): camera coordinates are x right, y **down**, z forward; other keys include `pred_cam_t`, `pred_keypoints_3d`, `bbox`, `focal_length`. Multiply vertices by `[1, -1, -1]` to get y-up (a proper rotation, so faces stay valid).
- Install: follow the repo's INSTALL.md (Python 3.11 recommended; detectron2 pinned to a specific commit; also needs MoGe).
- License: SAM License. Commercial use is allowed with conditions; keep Meta's license notice and credit Meta.
- GPU: the team's notes say about 12 GB. If a T4 (about 15 GB) runs out of memory, switch to the `-vith` checkpoint and restart the runtime so two copies of the model are not loaded.

Proposed worker pipeline:
1. Decode JPEG to RGB. Run `process_one_image`. If no person is found, return `{"error": "no_person"}`.
2. Convert to y-up; scale uniformly so the mesh height equals `height_cm`; translate so feet are at y=0 and the body is centered on x/z.
3. Slice the mesh with horizontal planes (`trimesh.intersections` / `mesh.section`). For each slice, choose the cross-section loop closest to the body's vertical center axis (this excludes the arms), project to 2D and take the **perimeter of the convex hull** (mimics a tape measure).
4. Slice heights: starting defaults from the team's notes are fractions of body height — chest 0.72, waist 0.62, hips 0.52. Fixed fractions do not fit every body. Preferred improvement: derive landmark heights from `pred_keypoints_3d` (shoulders, hips) or use a library such as `clad-body` which the team's notes say supports MHR meshes (**unverified; check before relying on it**).
5. Neck: not specified in the team's notes. Slice just below the chin using a keypoint-derived height; the exact method is an open task. Navy needs it.
6. Return JSON (section 7.1 fields). Optionally write `body.obj` (units cm, y-up) for debugging in Blender; never ship it to users and delete job files after responding.

Worker API [PROPOSED, adapted from the team's brief]:
- `POST /scan` multipart: `photo` (JPEG), `height_cm` (float) → `{"job": str, "neck_cm": float|null, "chest_cm": float|null, "waist_cm": float|null, "hips_cm": float|null}` or `{"error": str}`.
- `GET /mesh/{job}` (dev only) → `body.obj`.
- Load the model **once at startup**, not per request. Cloudflare quick tunnels cut requests at roughly 100 s.

### 8.4 Method B — On-device Vision silhouette + Navy [PROPOSED; from input 1]
Inputs: front photo, side photo, height.
1. Run `VNGeneratePersonSegmentationRequest` (quality `.accurate`, iOS 15+) and `VNDetectHumanBodyPoseRequest` (2D, iOS 14+) on each photo.
2. `cm_per_pixel = height_cm / (mask_bottom_y - mask_top_y)` from the front mask.
3. Choose measurement rows from joints: neck just below the head and above the shoulders; chest about 25% of the way from shoulders to hips; waist = the narrowest mask row between the ribs and the hip joints; hips = the widest mask row at hip-joint level.
4. In each row read mask width: front = `a`, side = `b`, converted to cm.
5. Circumference ≈ Ramanujan's ellipse approximation with half-axes `x = a/2`, `y = b/2`:
   `C ≈ π · (3(x+y) − sqrt((3x+y)(x+3y)))`
6. Apply the Navy formula (section 8.6).

Apple API facts that matter [VERIFIED by the team's research; not re-checked]: `VNDetectHumanBodyPose3DRequest` (iOS 17) returns 17 joints in meters and a `bodyHeight`, but that height is unreliable without depth data (a developer reported 5'4" to 10'1" for a 6'0" person). ARKit body tracking needs an A12 chip and the rear camera. None of Apple's native APIs returns circumferences, so they must be computed as above. Object Capture/photogrammetry needs a still subject and is not suitable. LiDAR is not assumed (most phones lack it).

### 8.5 Choosing the default method — bake-off protocol [DECIDED process]
When SAM 3D access arrives (target: before hour 12):
1. Tape-measure two or three teammates: neck, chest, waist, hips (same posture, same clothing, relaxed exhale).
2. Run both methods on the same people and photos.
3. Record absolute error in cm per field per method.
4. The method with the lower mean absolute error on waist and hips becomes `DEFAULT_SCAN_METHOD`; the other is the fallback.
5. Write results into `docs/scan-bakeoff.md`. If SAM access has not arrived by hour 12, ship Method B as default and treat Method A as stretch.

### 8.6 Navy body-fat formula [from input 1; VERIFIED against the original reference by the team's research, not re-checked here]
All lengths in **inches** inside the formula (convert from cm: `inches = cm / 2.54`):
- Men: `BF% = 86.010·log10(waist − neck) − 70.041·log10(height) + 36.76`
- Women: `BF% = 163.205·log10(waist + hips − neck) − 97.684·log10(height) − 78.387`

Error context to show in code comments and the pitch: the formula's own standard error is about 3.5 body-fat points for men and 3.7 for women versus underwater weighing (Hodgdon & Beckett, 1984). In a Marine Corps study it read men about 2.6 points low and women about 2.3 points high versus DXA. Circumference-based estimates can miss real changes (an Army basic-training study found DXA showing drops of 3–4 points where circumferences showed 0–2). Therefore: **emphasize trends over absolutes** and label every value as an estimate.

Do **not** use Gemini to estimate body fat from photos as a source of truth. Research on general chat models is anecdotal; use it at most for a qualitative remark and never let it overwrite measured numbers.

## 9. Calorie section

### 9.1 Targets (deterministic code in `services/targets.py`) [PROPOSED from input 1]
- Mifflin–St Jeor BMR: men `10·kg + 6.25·cm − 5·age + 5`; women `10·kg + 6.25·cm − 5·age − 161`.
- Katch–McArdle (use when body fat exists): `370 + 21.6 · LBM_kg`, with `LBM = kg · (1 − BF)`.
- TDEE = BMR × activity factor: 1.2 sedentary, 1.375 light, 1.55 moderate, 1.725 very active.
- Goal adjustment: cut = TDEE − 15–20% (cap the deficit at about 500 kcal); lean bulk = +5–10%; maintain = 0.
- Macros: protein 1.6–2.2 g/kg (high end on a cut); fat 0.6–1.0 g/kg (at least about 20% of kcal); carbs = remaining kcal.
- **Safety clamp in code**: never recommend below BMR and never below a hard floor of about 1,200 kcal (women) / 1,500 kcal (men). Be cautious with very low targets (possible disordered eating).
- Gemini may *explain* the targets in text but never computes them.

### 9.2 Food photo analysis
- Endpoint `POST /v1/food/analyze` (image). Downscale to about 1024 px before sending to Gemini.
- Use the structured-output (JSON schema) feature of the Gemini API with a **non-streaming** call. Third-party reports say streaming plus JSON mode is unreliable.
- Output schema (superset of the original spec `{item, calories, protein_g, carbs_g, fat_g}`):
  ```json
  [{"item": "grilled chicken breast", "grams": 150, "calories": 248,
    "protein_g": 46, "carbs_g": 0, "fat_g": 5, "confidence": "medium"}]
  ```
- Prompt guidance: list each food, **estimate grams first**, then nutrition, be conservative, return an empty list if no food is visible.
- Accuracy expectation: published studies on older models report energy error of roughly 36% (best case) and much worse for some models. No published evaluation of Gemini 3.x on calories was found. Therefore: show results as **editable estimates**, let the user tap to correct grams, and make **no accuracy claims** in the pitch.

### 9.3 Text logging
`POST /v1/food/parse-text` ("Just ate 2 eggs and toast") returns the same item list. This same function serves the Photon iMessage path. Optional: ground generic foods against USDA FoodData Central (free key; `DEMO_KEY` is limited to 30 requests/hour, 50/day) and barcodes against Open Food Facts (`GET https://world.openfoodfacts.org/api/v2/product/{barcode}`, send a custom `User-Agent`, about 15 requests/min/IP, ODbL license).

### 9.4 Persistence
SwiftData on the phone is the UI source of truth. The app mirrors entries to the API (`POST /v1/log/food`). Optional HealthKit write: `dietaryEnergyConsumed`, `dietaryProtein`. Note `bodyFatPercentage` is a 0–1 scalar in HealthKit (0.18 = 18%); passing 18 is a classic bug.

## 10. Coach (workout) section

### 10.1 Program generation [PROPOSED]
- Endpoint `POST /v1/plan/generate`. Inputs (built by `services/context.py`): profile, goal, experience, injuries, equipment, available days per week, latest biometrics, and the previous week's logs if any.
- Gemini returns JSON matching `WorkoutPlan` (section 7.2) using a response schema. The system prompt must enforce:
  - progressive overload; weekly volume per muscle group in a sensible range for the user's experience; adequate recovery between sessions for the same muscle group;
  - exercise choices that respect `injuries` and `equipment` (never include a movement that conflicts with a stated injury; offer a substitute instead);
  - target RPE/RIR and rest times on every exercise;
  - no diagnosis and no medical claims; recommend a professional for pain or injury.
- Validate the output in code: required fields, `sets` and `rep_range` within bounds, every exercise has a muscle group from a fixed enum. On validation failure, retry once, then fall back to a small hand-written template program so the demo never shows an empty tab.
- Muscle-group thumbnails: ship a fixed set of local images keyed by the muscle-group enum. Do not generate images at runtime.

### 10.2 Logging and adaptation [PROPOSED]
- UI: workout cards expand to show sets × rep range, target RPE, rest timer; interactive fields for completed weight, reps, RIR, and a failure/pain note.
- Adaptation is **rule-based in code**, with Gemini only writing the explanation. Starting rules (tune with testing):
  - If all sets hit the top of the rep range with RIR at or below target: raise load next session by about 2.5–5% (smaller for upper body/isolation).
  - If reps fall below the bottom of the range or RIR is far below target for two sessions: hold or reduce load.
  - If a pain/injury note appears for a movement: replace it and flag it to the user with a suggestion to see a professional if it persists.
- `POST /v1/plan/adapt` is called weekly (or on demand) and returns the next week's plan with a short rationale.

### 10.3 Coach chat
- `POST /v1/coach/chat` streams (server-sent events). The system instruction includes a compact JSON context (keep under about 1 KB): goal and target date, latest biometrics and the 4-week trend (waist, body fat), today's calories/macros vs targets, this week's workout completion, and rank. Rebuild context when it changes.
- System-prompt rules: friendly, short, actionable; use only the provided numbers and never invent measurements; body-fat values are estimates (about ±4 points); no diagnoses or medication advice; recommend a professional for injuries, pain, pregnancy or signs of disordered eating.

## 11. Game section (dashboard)

### 11.1 Calorie ring [DECIDED]
Ring = consumed vs. remaining budget for today, with protein, carb and fat distribution bars. Updates immediately after a log is saved.

### 11.2 Hunter Rank and XP [PROPOSED — all numbers are starting defaults]
Computed in code in `services/xp.py` (and mirrored or fetched by the app).
- XP events: workout completed +100; each logged meal +10 (max 3 counted per day); daily calorie target within ±10% +25; weekly plan fully completed +150 bonus; scan completed +30 (max once per week).
- Streak multiplier: ×1.1 at 3 days, ×1.25 at 7 days, ×1.5 at 14 days; a missed day resets to ×1.0 (display "streak broken", never shame the user).
- Rank bands (Solo Leveling style): E → D → C → B → A → S, thresholds on total XP, e.g. E 0, D 500, C 1,500, B 3,500, A 7,000, S 12,000. Tune so a demo user can visibly rank up in minutes (use the demo-data toggle).
- Level = a smooth function of XP (for example `floor(sqrt(xp / 50))`).

### 11.3 Avatar evolution [PROPOSED]
- One stock humanoid model (USDZ) rendered in SceneKit. Scale named body regions (shoulders/chest, waist, hips) by the ratio of current to baseline scan circumferences, clamped to a modest range so it never looks absurd.
- Gear unlocks at rank thresholds (for example a cloak at D, armor pieces at C/B/A, a full set at S). Use a small set of pre-made assets; no runtime generation.
- Progress shown over time: show baseline vs. current silhouette scale, or a short "evolution" timeline.
- Stretch only: use the user's own SAM mesh as the avatar (requires decimating `body.obj` and loading it; extra work, not in MVP).

### 11.4 Trends
Swift Charts line charts for weight, waist and body fat over time; steps and active energy from HealthKit if enabled.

## 12. Onboarding

Default: a typed form for sex, age, height, weight, goal, training history, injuries, equipment, days per week. On completion the API computes targets (section 9.1) and the app shows a targets card.

Stretch (D9): an ElevenLabs conversational agent runs the same intake by voice and also guides the scan ("step back about six feet, arms slightly out"). Gemini converts the transcript into the same structured profile JSON. Use a public ElevenLabs agent ID from the app, or short-lived tokens from the API. **Never ship a raw ElevenLabs API key in the app.** The form stays as the fallback in case of venue noise or network problems.

## 13. Photon iMessage agent (stretch) [VERIFIED facts / PROPOSED design]

Verified:
- Spectrum (Photon's open-source SDK, MIT) currently supports **TypeScript only**; Python is announced as planned with no release date. An existing Python agent project (Hermes) works around this by running `spectrum-ts` in a Node sidecar that its Python code supervises.
- Receiving: an async message stream (`app.messages`) yields each conversation ("space") and message. Sending: `message.reply()` inside `space.responding()`.
- The connection is a persistent gRPC stream, not webhooks or polling. Credentials are a Photon project ID and secret from `app.photon.codes`.

Proposed design:
- `backend/sidecar/index.ts` listens on the Spectrum stream and forwards each message to `POST http://127.0.0.1:8000/internal/photon/message` with `{user_ref, text}`; it sends the API's reply text back. The sidecar contains **no business logic**.
- The API maps `user_ref` to a user (pairing flow: the user texts a code shown in the app), runs intent routing, and replies:
  - meal text → `parse-text` → saves `FoodEntry` → reply with updated remaining kcal;
  - exercise question → coach function with the user's context;
  - "move my workout to Thursday" → plan adjustment;
  - scheduled reminders (workout days, evening log nudge).
- The loopback endpoint must reject requests that do not come from localhost.

## 14. Tiger Data (stretch)
Sync biometrics, food entries and set logs to a Postgres hypertable and build daily/weekly continuous aggregates for the trend charts. It is Postgres, so Python uses a normal driver. Never put DB credentials in the app; only the API connects. Tiger Cloud's trial terms were reported as 30 days with credits (from input 1; unverified here).

## 15. API contract (summary) [SUPERSEDED for app data by D11]

With Firebase there is no REST API for app data: food estimates go through AI Logic (`FirebaseFoodAnalyzer`), and profile, logs and game state go to the Firestore paths in section 4. The table below is kept for the scan worker (`/v1/scan` semantics and the `503 {"fallback":"on_device"}` contract still apply) and as a reference if a server returns.

All app endpoints require `Authorization: Bearer <device_token>` (issued on first launch; hackathon-grade auth). Errors use `{"error": {"code": str, "message": str}}`. Pydantic models in `backend/api/schemas.py` are the single source of truth; mirror them in Swift `Codable` types.

| Method | Path | Purpose |
|---|---|---|
| POST | `/v1/profile` | Create/update profile; returns targets |
| POST | `/v1/scan` | Multipart `photo`, `height_cm`, `weight_kg`, `sex` → Biometrics, or `503 {"fallback":"on_device"}` |
| POST | `/v1/biometrics` | Save a (possibly user-edited / on-device) Biometrics record; returns recomputed body fat |
| POST | `/v1/food/analyze` | Image → item list |
| POST | `/v1/food/parse-text` | Text → item list |
| POST | `/v1/log/food` | Save a food entry |
| POST | `/v1/plan/generate` | Generate this week's plan |
| POST | `/v1/plan/adapt` | Adapt next week's plan from logs |
| POST | `/v1/log/set` | Save a set log; returns updated XP/rank |
| POST | `/v1/coach/chat` | Streaming chat (SSE) |
| GET | `/v1/dashboard` | Today's totals, targets, trends, game state |
| POST | `/internal/photon/message` | Loopback only; sidecar → API |

Worker endpoints are internal (section 8.3).

## 16. Configuration and secrets

`.env.example` (never commit real values):
```
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.8-flash
GEMINI_MODEL_FAST=gemini-3.5-flash-lite      # dev and high-volume calls
SCAN_WORKER_URL=                              # changes whenever the Colab tunnel restarts
DEFAULT_SCAN_METHOD=vision_navy               # or sam3d, per bake-off
DEVICE_TOKEN_SECRET=
PHOTON_PROJECT_ID=
PHOTON_PROJECT_SECRET=
ELEVENLABS_AGENT_ID=
DATABASE_URL=sqlite:///./fit.db
```
Rules: the iOS app contains only the API base URL (in one `Config.swift`), never any third-party key.

Firebase (D11):
- `ios/FitQuest/GoogleService-Info.plist` identifies the Firebase project (`fitmax-be935`, bundle ID `com.adharsh.fitquest`). It is gitignored; share it privately. Without it the app runs on sample data instead of crashing.
- The Gemini key lives in Firebase AI Logic, not in the app or git.
- App Check debug tokens print in the Xcode console on first Debug run; register each one under App Check → Apps → Manage debug tokens. They are secrets: never commit or post them.
- App Check enforcement for AI Logic reportedly becomes automatic on 2026-11-02 (per a notice in the console, not independently verified). Release builds use App Attest and need the App Attest capability, which is not added yet.
- `Secrets.plist` / `GEMINI_API_KEY` remain only for the legacy direct `GeminiFoodAnalyzer`; delete once the Firebase path is confirmed on device.

## 17. Gemini specifics [VERIFIED 2026-10-09 against Google's pages]

- `gemini-3.8-flash` is Stable/GA. Introductory price $0.75 per 1M input tokens and $3.75 per 1M output tokens through 2026-12-31; $1.50/$7.50 from 2027-01-01. Context 1M tokens, max output 64k.
- Thinking is controlled with `thinking_level`: `low`, `medium` (default), `high`. `minimal` is **not supported and returns an error**. The old `thinking_budget` is replaced.
- Remove `temperature`, `top_p`, `top_k` and `candidate_count` from request config (unsupported on Gemini 3+). Do not prefill model turns.
- Other stable models: `gemini-3.6-flash`, `gemini-3.5-flash-lite`, `gemini-3.1-flash-lite`. 2.5 models remain only for projects that already used them; Google says new projects should use 3.5 Flash-Lite or 3.8 Flash. Gemini 2.0 Flash is shut down.
- Python SDK is `google-genai`. Google's current example calls `client.interactions.create(model="gemini-3.8-flash", ...)`. The older `client.models.generate_content(...)` pattern with a response schema is widely documented, but **check the current SDK docs for the exact call and structured-output syntax before coding**; wrap all Gemini calls in `services/gemini.py` so only one file changes.
- Free-tier quotas are unclear (independent reports range from 20 to 1,500 requests/day). Develop on the Flash-Lite model, attach billing before judging, and keep the model name in env so it can be swapped without a deploy. Model names churn quickly.
- Images: downscale to about 1024 px; JPEG.
- Firebase AI Logic (D11): Swift module `FirebaseAILogic` (the old `FirebaseAI` product name still builds in SDK 12.x but warns). Model name comes from `GeminiFoodAnalyzer.defaultModel`. `FirebaseFoodAnalyzer` sends no thinking config and does not retry 503s yet, unlike the direct REST analyzer.

## 18. Unverified claims (do not treat as fact)

- Accuracy of SAM 3D Body for circumferences (none found; bake-off will decide).
- `clad-body` support for MHR meshes (from the team's notes; not checked).
- Exact fixed-fraction slice heights; the neck slice method.
- Hour estimates for Photon sidecar (4–6 h is the planning assistant's estimate), ElevenLabs (3–5 h) and Tiger Data (4–6 h) (the last two from input 1).
- Sponsor rules for each prize track (read each Devpost page).
- Free-tier quotas for Gemini, USDA and Tiger Cloud.
- All XP/rank numbers in section 11 (proposed defaults).
- Nutritionix free tier (not used).

## 19. Privacy, safety and compliance rules [DECIDED]

1. Body photos are sensitive. HTTPS only. The worker deletes photos and meshes right after responding. The API does not log or store body photos. The app deletes them after extraction unless the user opts in to progress photos (stored in the app sandbox with `.complete` file protection).
2. Body photos are **never** sent to Gemini unless the user explicitly taps an "ask the coach about my physique" action. Food photos may be sent.
3. Show a consent note before the first scan. Never commit scans, photos or meshes to git.
4. Not medical advice: onboarding disclaimer, calorie floors in code, no diagnoses, referral language for pain/injury/pregnancy/eating-disorder signs. Do not offer the app to minors without guardian consent.
5. Label every scan-derived and photo-derived number an **estimate**.
6. Keep Meta's SAM license notice and credit Meta.
7. Never commit API keys; the app never holds third-party keys.

## 20. Build order, checkpoints and cut list [PROPOSED]

Roadmap (~30 h; shift to the real event length). Checkpoints are in bold.

| Hours | Work | Checkpoint |
|---|---|---|
| 0–3 | Xcode project, SwiftData shell, FastAPI skeleton, env/config, repo | **Gemini replies** (one round-trip app → API → Gemini) |
| 3–10 | Calorie section (photo/text → items → ring), workout plan JSON + logging, coach chat | **Meal logs end to end** |
| 10–18 | Vision fallback scan, SAM worker (when access arrives), bake-off, rank/XP, ring polish | **Scan returns numbers** |
| 18–24 | Avatar + gear, Photon sidecar, voice (if time), Tiger Data (if time) | **Feature freeze at hour 24** |
| 24–30 | Polish, empty states, disclaimers, demo video, Devpost, rehearse three times on a real device | **Demo ready** |

Cut order if behind (cut from the top): Tiger Data and voice → Photon → avatar gear unlocks (keep a plain scaled avatar) → barcode scan → HealthKit write → the SAM worker (stay on-device if access is late). **Never cut the Gemini-powered Calorie and Coach sections.**

Demo script (3 min): onboarding (voice if built, otherwise the form); scan with biometrics shown as estimates; snap a meal and watch the ring update; open the generated workout, log a set with RIR and see the plan adapt; text the iMessage coach if built; show rank and avatar. Provide a **demo-data toggle** that seeds six weeks of scans, logs and workouts so charts, rank and the coach have history. Pre-record a 60-second scan video in case venue lighting or Wi-Fi breaks the live scan. Have one canned coach question that shows personalization.

## 21. Known risks

- SAM 3D access delay; Colab idle disconnects; tunnel URL changes; first start downloads large weights.
- Single-photo measurement error is typically several cm; clothing, posture and camera tilt bias both methods.
- Photo calorie error; Gemini free-tier limits; model churn.
- Scope is large for ~30 hours; the cut list exists for a reason.
- Venue Wi-Fi and lighting at demo time.

## 22. Open questions for the team

1. Confirm the prize-track list: Gemini core; Photon, ElevenLabs, Tiger Data stretch. Add .Tech domain and the Commit Fellowship pitch (cheap, no engineering).
2. Who owns the backend (API + worker + sidecar)? One person owning all three is a risk.
3. Real event length in hours (the plan assumes ~30).
4. Hosting for the API and a backup GPU for the worker.
5. Is the hackathon app for iOS only? (Assumed yes.)

## 23. Source inputs this plan merges

1. "HackNC Fitness App: Swift Build Plan" — on-device Vision scan, Gemini coach, calorie tracking, prize-track analysis.
2. "BodyScan: HackNC Project Brief" — SAM 3D Body server design, API contract, measurement slicing.
3. Feature spec — voice onboarding, calorie JSON schema, science-backed workout planner, gamification and avatar evolution, Photon iMessage and Gemini/ElevenLabs tracks.
Plus: team follow-up decisions (SAM 3D access requested; mesh used for biometrics only; latest Gemini; Python backend; scope = calorie, coach, game) and web checks of Google's model docs, Spectrum/Photon, and the SAM 3D Body repository on 2026-10-10.
