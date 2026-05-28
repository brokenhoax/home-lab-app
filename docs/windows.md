# Windows 11 — WSL 2

Run the stack **inside WSL** (Ubuntu recommended). Windows is not Linux, but **WSL 2 runs a real Linux kernel** — install **Docker Engine** in your distro (same idea as RHEL). Docker Desktop is **not** required.

## Prerequisites (install before `./bootstrap.sh`)

| Item | Required? | Notes |
|------|-----------|--------|
| **Windows 11** (Home or Pro) | Yes | WSL 2 required |
| **WSL 2 + Ubuntu** (or similar) | Yes | `wsl --install` or `wsl --install -d Ubuntu` |
| **Docker Engine in WSL** | Yes | `docker` + `docker compose`; `dockerd` running — see [Install Docker](#2-install-docker-engine-in-wsl) |
| **Ollama in WSL** | Yes (for chat / RAG) | Recommended: `curl -fsSL https://ollama.com/install.sh \| sh` |
| **systemd in WSL** | Recommended | Needed for `docker` and `ollama` services — see below |
| Git | Recommended | Clone under `~/` in WSL, not only on `C:\` |
| Ports **80**, **8000**, **9001** | Yes | Published to Windows `localhost` from WSL |
| Docker Hub login | No | Public images |

Hardware: enough RAM/disk for Docker images plus Ollama models (~several GB for `llama3.1:8b`).

**Checklist:** WSL Ubuntu → enable systemd → Docker Engine in WSL → Ollama in WSL → clone to `~/home-lab-app` → `./bootstrap.sh`.

---

## Recommended layout

Clone the repo **inside the WSL filesystem** (fast, reliable file watching):

```bash
# In Ubuntu (WSL) — not PowerShell
cd ~
git clone <repo-url> home-lab-app
cd home-lab-app
```

Avoid running the stack from `C:\` via `/mnt/c/` when possible; use `~/home-lab-app` in WSL instead.

---

## One-time Windows setup

### 1. Install WSL 2

PowerShell **as Administrator**:

```powershell
wsl --install
# or pick a distro:
wsl --install -d Ubuntu
```

Reboot if prompted. Open **Ubuntu** from the Start menu and create your Linux user.

### Enable systemd in WSL (recommended)

Docker Engine and Ollama are easiest to manage with systemd. In WSL:

```bash
sudo tee /etc/wsl.conf <<'EOF'
[boot]
systemd=true
EOF
```

From PowerShell:

```powershell
wsl --shutdown
```

Re-open Ubuntu. Check: `systemctl is-system-running` should not report `offline`.

### 2. Install Docker Engine in WSL

Inside Ubuntu (official Docker CE on Ubuntu — adjust if you use another distro):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

If systemd is enabled:

```bash
sudo systemctl enable --now docker
```

Restart WSL so group membership applies (from PowerShell: `wsl --shutdown`, then reopen Ubuntu), or run `newgrp docker` in the current shell.

Confirm:

```bash
docker version
docker compose version
docker info
```

### 3. Install Ollama (in WSL)

So `./bootstrap.sh` can run `ollama pull` and `ollama create`:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Alternative:** [Ollama for Windows](https://ollama.com/download/windows) on the host. You must pull models from Windows and run `configure-ollama-windows.ps1` (see below). WSL `bootstrap.sh` will not see the Windows `ollama` CLI unless you also install Ollama in WSL.

---

## Bootstrap

### Option A — from WSL (preferred)

```bash
cd ~/home-lab-app
chmod +x bootstrap.sh
./bootstrap.sh
```

### Option B — from PowerShell (launches WSL)

From the repo folder on a Windows path (e.g. cloned to `C:\dev\home-lab-app`):

```powershell
cd C:\dev\home-lab-app
.\bootstrap.ps1
```

This maps the path with `wslpath` and runs `./bootstrap.sh` in your default WSL distro.

Do **not** double-click scripts; the window may close on exit. Use Windows Terminal or PowerShell.

Logs: `bootstrap.log` in the repo root (WSL path).

---

## Expose Ollama to Docker

Containers use `http://host.docker.internal:11434` (see `docker-compose.yml`). Ollama must listen beyond `127.0.0.1` on the **WSL host** that runs `dockerd`.

### Ollama installed in WSL (recommended)

If systemd is enabled:

```bash
cd ~/home-lab-app
sudo ./scripts/configure-ollama-for-docker.sh
```

If systemd is not enabled, set `OLLAMA_HOST` before starting Ollama:

```bash
export OLLAMA_HOST=0.0.0.0:11434
ollama serve
```

### Ollama installed on Windows (native app)

From PowerShell in the repo:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\configure-ollama-windows.ps1
```

Restart Ollama from the system tray. Verify:

```powershell
curl http://127.0.0.1:11434/api/tags
```

Then from WSL:

```bash
./bootstrap.sh
```

Bootstrap checks container reachability via `host.docker.internal` (Docker Engine `host-gateway`), not only `172.17.0.1`.

---

## Verify

In WSL:

```bash
curl -s http://127.0.0.1:11434/api/tags
docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:8.5.0 \
  -sf http://host.docker.internal:11434/api/tags && echo "OK from container"
ollama list
docker compose ps
```

Browser on Windows: http://localhost/ (WSL forwards published container ports to Windows localhost).

---

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `Cannot reach Docker` from bootstrap | `sudo systemctl start docker` or ensure `dockerd` is running; `docker info` must succeed in WSL |
| `Docker CLI not found inside WSL` | Install Docker Engine in WSL — [section 2](#2-install-docker-engine-in-wsl) |
| `permission denied` on `docker.sock` | `sudo usermod -aG docker $USER`, then `wsl --shutdown` and reopen Ubuntu, or `newgrp docker` |
| `Ollama not reachable at 127.0.0.1` in WSL | Install Ollama in WSL, or use Windows Ollama + `configure-ollama-windows.ps1` |
| Ollama works in WSL but ingest fails | Run `configure-ollama-for-docker.sh` or set `OLLAMA_HOST=0.0.0.0:11434` |
| Slow file I/O | Move repo off `/mnt/c/` into `~/` |
| `bash\r: No such file` / script won't run | CRLF line endings — `git config core.autocrlf input` and re-checkout, or `dos2unix bootstrap.sh` |
| Line ending issues on clone | Repo includes `.gitattributes` to keep `*.sh` as LF |

---

## What we do not support on Windows

- Running **only** in CMD/PowerShell without WSL (no native Windows bootstrap for the compose stack).
- Docker on Windows **without** WSL (no documented Hyper-V-only path).

---

## Optional: Docker Desktop

[Docker Desktop](https://www.docker.com/products/docker-desktop/) can provide Docker via WSL integration instead of installing Engine yourself. This project does **not** require it if `docker info` works inside your distro. If you use Desktop, enable **Settings → Resources → WSL integration** for your Ubuntu distro.
