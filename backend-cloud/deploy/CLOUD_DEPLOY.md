# Cloud VM Deployment — step by step

This guide gets Backend Server 2 running on a public IP in **under 10 minutes**.
The only thing automated up to here is the in-VM setup. Provisioning a VM
requires *your* cloud account, so the steps below show exactly which buttons
to click in **Azure** (the assignment's example provider).
The same script works on AWS EC2 / GCP / DigitalOcean — only the VM-creation
steps differ.

## TL;DR

```bash
# On the VM:
curl -fsSL https://raw.githubusercontent.com/eraycanuyanik/EE471MiniProject4/main/backend-cloud/deploy/setup-vm.sh \
  | sudo bash
```

That one line installs Docker, clones the repo, builds the image, runs the
container on port 8000, opens UFW, and smoke-tests both endpoints.

## Option A — Azure (recommended for the assignment)

Azure for Students gives you free credit — perfect for this assignment.
**Use a low-tier image** as the assignment specifies.

### 1. Create the VM

1. Portal → **Create a resource → Virtual machine**.
2. Fill in:
   - Resource group: *create new*, e.g. `rg-robomunch`
   - VM name: `robomunch-backend`
   - Region: closest to you (e.g. *West Europe*, *UK South*)
   - Image: **Ubuntu Server 22.04 LTS — x64 Gen2** (low-tier, supported)
   - Size: **Standard_B1s** (1 vCPU / 1 GB RAM — cheapest, plenty for this app)
   - Authentication type: **SSH public key**
   - Username: `azureuser`
   - SSH public key source: *Generate new key pair* → download the `.pem` when prompted (you'll need this once)
   - Public inbound ports: allow **SSH (22)** for now
3. Networking tab → leave defaults (you'll add port 8000 in a moment).
4. **Review + create → Create**. Wait ~1 minute.

### 2. Open port 8000

VM → **Networking → Add inbound port rule**:

| Field | Value |
|---|---|
| Source | `Any` |
| Source port ranges | `*` |
| Destination | `Any` |
| Service | `Custom` |
| Destination port ranges | `8000` |
| Protocol | `TCP` |
| Action | `Allow` |
| Priority | `1010` |
| Name | `AllowBackend8000` |

### 3. SSH in & run the setup script

```bash
chmod 400 ~/Downloads/robomunch-backend_key.pem
ssh -i ~/Downloads/robomunch-backend_key.pem azureuser@<VM-PUBLIC-IP>

# inside the VM:
curl -fsSL https://raw.githubusercontent.com/eraycanuyanik/EE471MiniProject4/main/backend-cloud/deploy/setup-vm.sh \
  | sudo bash
```

The script prints the public URL at the end. From your laptop:

```bash
curl http://<VM-PUBLIC-IP>:8000/health
# → {"status": "ok", "version": "1.1.0"}
```

### 4. Stream Docker logs (Deliverable #4 video)

Keep this open in one SSH window while you exercise the mobile app:

```bash
docker logs -f robomunch-backend-cloud
```

Each `/get/resolution` and `/convert/grayscale` call from the phone will print
a line like:

```
[06/Jun/2026 17:51:02] INFO imageops.views: get_resolution served 1024x1024
[06/Jun/2026 17:51:03] "POST /get/resolution HTTP/1.1" 200 60
```

### 5. **DON'T FORGET** — shut down when done

The assignment explicitly says: *"do not forget to shut down or delete the
VM resources once you completed this assignment."*

```
Portal → VM → Stop          # stops billing for compute
Portal → resource group → Delete   # nukes everything (safer)
```

## Option B — AWS EC2

```bash
# Same VM size class: t3.micro (free tier eligible). Ubuntu 22.04.
# Open port 8000 in the security group. Then SSH in:
ssh -i ~/your-key.pem ubuntu@<EC2-PUBLIC-IP>

curl -fsSL https://raw.githubusercontent.com/eraycanuyanik/EE471MiniProject4/main/backend-cloud/deploy/setup-vm.sh \
  | sudo bash
```

## Option C — DigitalOcean / Hetzner / Linode

Cheapest droplet (~€4/mo). Ubuntu 22.04. Open port 8000 in the cloud firewall.
Same one-liner.

## After deployment — update the Flutter app

Open the app on your phone → tap the ⚙️ icon → set **Backend Server 2** to:

```
http://<VM-PUBLIC-IP>:8000
```

Hit *Save*. The "colorize" button will now call the cloud VM.

## CI/CD note (Deliverable: working CI/CD pipeline)

The repo already includes three GitHub Actions:

- **CI (lint + tests)** — runs on every push/PR. Required to pass.
- **Release (semantic versioning)** — auto-tags `vX.Y.Z` when `VERSION` is changed.
- **CD (build & deploy)** — on a new tag: builds the Docker image, pushes to
  Docker Hub, SSHes into the VM and re-runs `docker pull && docker run`.

To enable the deploy half, add these to the repo's **Settings → Secrets**:

| Secret | Value |
|---|---|
| `DOCKERHUB_USERNAME` | your Docker Hub user |
| `DOCKERHUB_TOKEN` | a Docker Hub access token |
| `VM_HOST` | the VM's public IP |
| `VM_USER` | `azureuser` (or `ubuntu` etc.) |
| `VM_SSH_KEY` | the **contents** of the .pem file (paste the whole thing including BEGIN/END lines) |

Then to cut a release:

```bash
# from your laptop
echo "1.0.0" > backend-cloud/VERSION
git add backend-cloud/VERSION && git commit -m "release: cut v1.0.0"
git push origin main
# → release.yml tags v1.0.0 → cd.yml deploys
```

Bump for the second endpoint:

```bash
echo "1.1.0" > backend-cloud/VERSION
git add backend-cloud/VERSION && git commit -m "release: cut v1.1.0 (+/convert/grayscale)"
git push origin main
# → release.yml tags v1.1.0 → cd.yml redeploys
```

## Troubleshooting

- **`curl http://<VM-IP>:8000/health` hangs from your laptop**
  → Port 8000 isn't open in the cloud firewall. Recheck step 2.

- **`docker: command not found`** after running the script
  → The script installs it for you; if you ran it as a non-root user and it
    silently skipped, run it again with `sudo bash`.

- **Container starts then immediately dies** (`docker ps` shows nothing)
  → `docker logs robomunch-backend-cloud` will show the Python traceback.

- **`502 Bad Gateway` from a reverse proxy in front of the VM**
  → You probably don't need one for this assignment. Hit the VM directly on `:8000`.
