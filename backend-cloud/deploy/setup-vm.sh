#!/usr/bin/env bash
#
# One-shot Backend Server 2 bootstrap for a fresh Ubuntu 22.04 / 24.04 VM.
#
# What it does:
#   1. Installs Docker + docker compose plugin
#   2. Clones the EE471MiniProject4 repo
#   3. Builds the backend-cloud image
#   4. Runs the container on port 8000 with restart=unless-stopped
#   5. Opens UFW port 8000 (if UFW is active)
#   6. Smoke-tests /health and /get/resolution
#
# Usage (on the VM, after SSHing in):
#   curl -fsSL https://raw.githubusercontent.com/eraycanuyanik/EE471MiniProject4/main/backend-cloud/deploy/setup-vm.sh | sudo bash
#
# Or (if you cloned the repo first):
#   sudo bash backend-cloud/deploy/setup-vm.sh

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/eraycanuyanik/EE471MiniProject4.git}"
REPO_DIR="${REPO_DIR:-/opt/EE471MiniProject4}"
CONTAINER_NAME="${CONTAINER_NAME:-robomunch-backend-cloud}"
IMAGE_NAME="${IMAGE_NAME:-robomunch/backend-cloud:latest}"
PORT="${PORT:-8000}"

log() { printf "\n\033[1;32m[setup-vm]\033[0m %s\n" "$*"; }
err() { printf "\n\033[1;31m[setup-vm]\033[0m %s\n" "$*" >&2; }

if [[ $EUID -ne 0 ]]; then
    err "Run as root (use: sudo bash setup-vm.sh)."
    exit 1
fi

# 1) Packages -----------------------------------------------------------------
log "Updating apt and installing prerequisites…"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg git ufw

# 2) Docker -------------------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    log "Installing Docker Engine…"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    . /etc/os-release
    echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
        > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y \
        docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
else
    log "Docker already installed: $(docker --version)"
fi

# 3) Clone or pull repo -------------------------------------------------------
if [[ -d "$REPO_DIR/.git" ]]; then
    log "Repo exists, pulling latest…"
    git -C "$REPO_DIR" pull --ff-only
else
    log "Cloning $REPO_URL → $REPO_DIR …"
    git clone "$REPO_URL" "$REPO_DIR"
fi

# 4) Build & (re)run the container --------------------------------------------
cd "$REPO_DIR/backend-cloud"
log "Building Docker image $IMAGE_NAME …"
docker build -t "$IMAGE_NAME" .

log "Stopping any previous container…"
docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

log "Running new container on port $PORT …"
docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    -p "${PORT}:8000" \
    -e DJANGO_DEBUG=False \
    -e DJANGO_ALLOWED_HOSTS='*' \
    "$IMAGE_NAME"

# 5) Firewall -----------------------------------------------------------------
if ufw status 2>/dev/null | grep -q "Status: active"; then
    log "Opening UFW port $PORT/tcp…"
    ufw allow "$PORT/tcp" || true
fi

# 6) Smoke test ---------------------------------------------------------------
log "Waiting for the container to become healthy…"
for i in $(seq 1 30); do
    if curl -fsS "http://localhost:${PORT}/health" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

log "Container status:"
docker ps --filter "name=$CONTAINER_NAME"

log "/health response:"
curl -fsS "http://localhost:${PORT}/health" || true
echo

log "Smoke-testing /get/resolution and /convert/grayscale with a 320x240 PNG…"
python3 - <<'PY' || true
import base64, json, urllib.request
from io import BytesIO
try:
    from PIL import Image
except ImportError:
    import subprocess, sys
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--quiet", "Pillow"])
    from PIL import Image

img = Image.new("RGB", (320, 240), (200, 50, 50))
buf = BytesIO(); img.save(buf, "PNG")
b64 = base64.b64encode(buf.getvalue()).decode()

for path in ("get/resolution", "convert/grayscale"):
    req = urllib.request.Request(
        f"http://localhost:8000/{path}",
        data=json.dumps({"image": b64}).encode(),
        headers={"Content-Type": "application/json"},
    )
    body = urllib.request.urlopen(req, timeout=10).read().decode()
    print(f"  {path:25s} → {body[:140]}")
PY

PUBLIC_IP="$(curl -fsS --max-time 3 https://api.ipify.org || true)"
log "DONE.

  Local URL : http://localhost:${PORT}
  Public URL: http://${PUBLIC_IP:-<your-vm-ip>}:${PORT}

  Endpoints :
    GET  /health
    POST /get/resolution
    POST /convert/grayscale

  Useful:
    docker logs -f $CONTAINER_NAME           # for Deliverable #4 screen recording
    docker restart $CONTAINER_NAME
    docker rm -f $CONTAINER_NAME             # tear down
"
