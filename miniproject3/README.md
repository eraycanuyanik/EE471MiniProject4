# miniproject3 — Backend Server 1 (Flask, localhost)

Originally Project #3 (RoboMunch web app). For Mini Project #4 it serves as
**Backend Server 1** — runs on your computer and is hit by the Flutter mobile app
over the local Wi-Fi network.

## Endpoints

| Method | URL | Purpose |
|--------|-----|---------|
| `GET`  | `/`                   | Original web UI (still works in a browser). |
| `GET`  | `/health`             | Liveness probe. |
| `POST` | `/api/chat`           | Chat with RoboMunch (SmolLM2-360M-Instruct, runs locally on CPU). |
| `POST` | `/api/generate-image` | Text-to-image (FLUX / SD via Hugging Face Inference API). |

## Setup

```bash
python -m venv .venv
source .venv/bin/activate           # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# put your Hugging Face token (free at https://huggingface.co/settings/tokens)
```

`.env` keys:

| Key           | Default                                 |
|---------------|-----------------------------------------|
| `HF_TOKEN`    | _required_                              |
| `IMAGE_MODEL` | `black-forest-labs/FLUX.1-schnell`      |
| `TEXT_MODEL`  | `HuggingFaceTB/SmolLM2-360M-Instruct`   |
| `HOST`        | `0.0.0.0` (so the phone can reach it)   |
| `PORT`        | `5000`                                  |

## Run

```bash
python app.py
```

Then:

- Browser: `http://127.0.0.1:5000`.
- From your phone: `http://<your-computer-LAN-IP>:5000` (use this in the Flutter app's settings dialog).
  - macOS: `ipconfig getifaddr en0`
  - Windows: `ipconfig`
  - Linux: `hostname -I`

> **Important**: phone and computer must be on the **same Wi-Fi network**.
> Eduroam / university Wi-Fi often blocks intra-network traffic — use a hotspot or home Wi-Fi.
> Allow inbound TCP 5000 in your firewall (macOS will prompt the first time).

## Notes

- **Chat runs locally** via `transformers` (SmolLM2-360M on CPU). First message after server start triggers a ~720 MB download and load — be patient. Subsequent replies are fast.
- **Image generation uses the HF Inference API** (FLUX/SD weights are too large for CPU). Needs `HF_TOKEN`.
- **CORS** is enabled (`flask-cors`) so the Flutter app can call the API from any origin.
- The original web UI is still served at `/` — useful for sanity-checking before testing on the phone.
