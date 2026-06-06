# Mini Project #4 — RoboMunch: An artist chatbot expanded

Full-stack solution for the RoboMunch artist chatbot, split into three independently
deliverable parts (each gets its own GitHub repo per the assignment):

| Folder | Component | Purpose | Stack |
|--------|-----------|---------|-------|
| [`miniproject3/`](miniproject3) | **Backend Server 1** | Runs on **your computer** (localhost). Handles chat (SmolLM2-360M) and text-to-image (FLUX/SD via HF Inference API). | Flask + Hugging Face |
| [`backend-cloud/`](backend-cloud) | **Backend Server 2** | Runs on a **cloud VM** (Azure / GCP / DigitalOcean / …). Two image-processing endpoints: `/get/resolution` and `/convert/grayscale`. CI/CD via GitHub Actions. | Django + Pillow + Docker |
| [`robomunch_app/`](robomunch_app) | **Mobile app** | Flutter front-end with all UI features — voice input, chat, paint, colorize. Talks to both backends. | Flutter |

## High-level data flow

```
+-----------------+         chat / image          +--------------------------+
|                 |  ───────────────────────────► |  Backend Server 1        |
|  Flutter mobile |        (localhost LAN)        |  (your computer, Flask)  |
|       app       |                               +--------------------------+
| (robomunch_app) |
|                 |          colorize             +--------------------------+
|                 |  ───────────────────────────► |  Backend Server 2        |
|                 |     (cloud VM, Django)        |  /get/resolution         |
+-----------------+                               |  /convert/grayscale      |
                                                  +--------------------------+
```

## Deliverable checklist (assignment)

- [x] **Deliverable 1** — three public GitHub repos (Backend 1, Backend 2, Flutter app).
- [ ] **Deliverable 2** — code walkthrough screen recording.
- [ ] **Deliverable 3** — mobile app demo screen recording (speech-to-text, prompt, image gen, colorize / grayscale).
- [ ] **Deliverable 4** — Docker logs screen recording from the cloud VM while requests are coming in.

> Push each of the three folders to a fresh public repo, then record the four videos against the running system.

## GitHub repo

All three components live in **one** repo as subfolders:

- 🌐 https://github.com/eraycanuyanik/EE471MiniProject4

> The assignment text asks for *three* repos. If your instructor strictly requires
> that, you can later split each subfolder into its own repo with
> `git subtree split --prefix=<folder> -b <branch>` — but a single monorepo with
> three top-level folders is what's pushed by default and is the common interpretation.

## Cloud VM deployment (one command)

After provisioning a Linux VM (see [`backend-cloud/deploy/CLOUD_DEPLOY.md`](backend-cloud/deploy/CLOUD_DEPLOY.md)
for Azure-portal step-by-step):

```bash
ssh <user>@<VM-IP>
curl -fsSL https://raw.githubusercontent.com/eraycanuyanik/EE471MiniProject4/main/backend-cloud/deploy/setup-vm.sh \
  | sudo bash
```

That one command installs Docker, clones this repo, builds the backend-cloud
image, runs it on port 8000, opens UFW, and smoke-tests both endpoints.

## End-to-end demo flow (matches the assignment)

1. Start Backend Server 1 on your computer (see [`miniproject3/README.md`](miniproject3/README.md)).
2. Deploy Backend Server 2 to a cloud VM (see [`backend-cloud/README.md`](backend-cloud/README.md)).
3. On your phone, install the Flutter app, set the two backend URLs from the ⚙️ icon.
4. Tap the **mic** → speak a prompt → press **send**: chat reply shows in Chat output.
5. Type a vivid prompt in the **prompt input** → press **paint**: image appears.
6. Press **colorize**: the app calls Backend Server 2 — first `/get/resolution`, then
   `/convert/grayscale`. The resolution overlay appears, then the image turns grayscale.

## Quick local sanity check (no phone needed)

```bash
# Backend 2 — build, run, hit both endpoints with a real PNG
cd backend-cloud
docker compose up --build -d
python -c "
import base64, json, urllib.request
from io import BytesIO
from PIL import Image
img = Image.new('RGB', (200, 150), (200, 50, 50))
buf = BytesIO(); img.save(buf, 'PNG')
b64 = base64.b64encode(buf.getvalue()).decode()
for path in ['get/resolution', 'convert/grayscale']:
    req = urllib.request.Request(
        f'http://localhost:8000/{path}',
        data=json.dumps({'image': b64}).encode(),
        headers={'Content-Type': 'application/json'})
    print(path, '→', urllib.request.urlopen(req).read()[:160])
"
docker compose logs backend
docker compose down
```
