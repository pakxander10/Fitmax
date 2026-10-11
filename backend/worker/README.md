# Scan worker

Turns one full-body photo into estimated neck, chest, waist and hip circumferences plus a Navy
body-fat estimate, using Meta's SAM 3D Body. All numbers are estimates; see the bake-off in
`PROJECT_CONTEXT.md` section 8.5.

- `server.py`: FastAPI app. `POST /scan` (multipart `photo`, `height_cm`, `sex`, optional `weight_kg`,
  header `Authorization: Bearer <Firebase ID token>`) returns the Biometrics record. On any model
  failure it returns `503 {"fallback": "on_device"}`. Photos and meshes are never stored or logged.
- `measure.py`: stands the mesh upright, scales it to the user's height and slices it like a tape measure.
- `navy.py`: US Navy body-fat formula.
- `colab_setup.ipynb`: installs SAM 3D Body on a Colab T4 and exposes the worker through a tunnel.

## Tests (no GPU needed)

```sh
cd backend/worker
python3.12 -m venv .venv && .venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest tests
```

## Credit

SAM 3D Body © Meta Platforms, Inc. and affiliates, used under the SAM License
(https://github.com/facebookresearch/sam-3d-body). Its code and weights are installed at run time
and are not part of this repo.
