# backend-cloud — Backend Server 2 (Django, cloud VM)

Image-processing backend for the RoboMunch Flutter app.
Runs as a Docker container on a Linux VM in the cloud. Two endpoints:

| Method | URL | Purpose |
|--------|-----|---------|
| `POST` | `/get/resolution`    | Returns the width × height of the image sent in the JSON body. |
| `POST` | `/convert/grayscale` | Converts the sent image to grayscale and returns it as base64 PNG. |
| `GET`  | `/health`            | Liveness probe (used by Docker `HEALTHCHECK`). |

Both processing endpoints accept the same JSON body:

```json
{ "image": "<base64 string OR data:image/png;base64,...>" }
```

## Local development

```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt

# run dev server
python manage.py runserver 0.0.0.0:8000

# lint + tests (what CI runs)
flake8 backend_cloud imageops tests
pytest -v
```

## Run with Docker

```bash
docker compose up --build -d
curl http://localhost:8000/health      # → {"status": "ok", "version": "..."}
docker compose logs -f backend         # use this view for Deliverable #4 recording
```

## Cloud VM deployment (manual one-liner)

On a fresh Ubuntu VM with Docker installed:

```bash
# replace <USER>/<IMAGE>:<TAG> with what the CD workflow pushed
docker pull <USER>/robomunch-backend-cloud:latest
docker rm -f robomunch-backend-cloud 2>/dev/null || true
docker run -d \
  --name robomunch-backend-cloud \
  --restart unless-stopped \
  -p 8000:8000 \
  -e DJANGO_DEBUG=False \
  -e DJANGO_ALLOWED_HOSTS='*' \
  <USER>/robomunch-backend-cloud:latest
```

Then open ports 22 (SSH) and 8000 (the API) in the VM's network security group.
Hit `http://<VM-IP>:8000/health` from your phone's browser to verify.

## CI / CD (GitHub Actions)

Three workflows live under `.github/workflows/`:

| File | Trigger | What it does |
|------|---------|--------------|
| [`ci.yml`](.github/workflows/ci.yml) | Push / PR to `main` | flake8 lint → pytest. Required to pass before merge. |
| [`release.yml`](.github/workflows/release.yml) | Push to `main` that changes `VERSION` | Reads the `VERSION` file, validates it as `X.Y.Z`, creates and pushes a matching `vX.Y.Z` git tag. |
| [`cd.yml`](.github/workflows/cd.yml) | Push of a `v*.*.*` tag (or manual dispatch) | Builds the Docker image, pushes to Docker Hub, SSHes into the VM and re-runs `docker pull && docker run` with the new tag. |

### Versioning flow (what the assignment asks for)

1. First endpoint working → version starts at `1.0.0` in `VERSION`.
2. Commit + push → CI runs lint + tests → on green, `release.yml` creates `v1.0.0` → `cd.yml` builds & deploys.
3. Second endpoint added → bump minor: edit `VERSION` to `1.1.0`, commit + push → CI passes → `v1.1.0` tagged → CD redeploys.

Current value in this repo: `1.1.0` (both endpoints present).

### Secrets the workflows expect

Set these under **Settings → Secrets and variables → Actions** of the `backend-cloud` GitHub repo:

| Secret | Purpose |
|--------|---------|
| `DOCKERHUB_USERNAME` | Docker Hub user — image will be pushed to `<USER>/robomunch-backend-cloud`. |
| `DOCKERHUB_TOKEN`    | Docker Hub access token. |
| `VM_HOST`            | Public IP / hostname of your cloud VM. |
| `VM_USER`            | SSH user on the VM (usually `azureuser`, `ubuntu`, …). |
| `VM_SSH_KEY`         | Private SSH key (PEM contents) with access to the VM. |
| `VM_SSH_PORT`        | Optional, defaults to `22`. |

If `DOCKERHUB_USERNAME` is not set, the build job runs as a dry-build (no push, no deploy) so the workflow still validates without secrets configured.

## Project layout

```
backend-cloud/
├── backend_cloud/           # Django project (settings, urls, wsgi/asgi)
├── imageops/                # Django app — views + pure image helpers
│   ├── views.py             # /get/resolution, /convert/grayscale, /health
│   └── image_utils.py       # decode_image_payload, to_grayscale_png_b64
├── tests/test_endpoints.py  # pytest smoke tests for both endpoints
├── Dockerfile               # python:3.11-slim, gunicorn, non-root user
├── docker-compose.yml       # one-command local run
├── requirements.txt         # runtime deps
├── requirements-dev.txt     # adds flake8 + pytest
├── setup.cfg                # flake8 config
├── pytest.ini               # pytest + django settings module
├── VERSION                  # X.Y.Z — bump this to cut a release
└── .github/workflows/       # ci.yml, release.yml, cd.yml
```
