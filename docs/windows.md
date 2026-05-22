# Windows 11 — WSL 2 + Docker Desktop

Run the stack **inside WSL**. Docker Desktop on Windows provides the engine; Ollama and `bootstrap.sh` run in your WSL distro.

## Requirements

| Requirement | Notes |
|-------------|--------|
| **Windows 11 Pro** (or Enterprise) | Home works with WSL 2; Pro is typical for dev VMs / Hyper-V features |
| **WSL 2** | `wsl --install` or `wsl --install -d Ubuntu` |
| **Docker Desktop for Windows** | [Download](https://www.docker.com/products/docker-desktop/) — use **WSL 2** backend (default) |
| **WSL integration** | Docker Desktop → **Settings** → **Resources** → **WSL integration** → enable your distro (e.g. Ubuntu) |
| **Git** (optional) | Clone inside WSL: `git clone …` under `~/` |

Hardware: enough RAM/disk for Docker images plus Ollama models (~several GB for `llama3.1:8b`).

Ports **80**, **8000**, **9001** must be free on the machine (Docker Desktop forwards from WSL).

## Recommended layout

Clone the repo **inside the WSL filesystem** (fast, reliable file watching):

```bash
# In Ubuntu (WSL) — not PowerShell
cd ~
git clone <repo-url> home-lab-app
cd home-lab-app
```

Avoid running the stack from `C:\` via `/mnt/c/` when possible; use `~/home-lab-app` in WSL instead.

## One-time Windows setup

### 1. Install WSL 2

PowerShell **as Administrator**:

```powershell
wsl --install
# or pick a distro:
wsl --install -d Ubuntu
```

Reboot if prompted. Open **Ubuntu** from the Start menu and create your Linux user.

### 2. Install Docker Desktop

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/).
2. Start Docker Desktop and wait until it shows **Running**.
3. **Settings** → **General** → use the **WSL 2 based engine**.
4. **Settings** → **Resources** → **WSL integration** → turn on your Ubuntu (or other) distro.

Confirm in WSL:

```bash
docker version
docker compose version
```

### 3. Install Ollama (recommended: inside WSL)

So `./bootstrap.sh` can run `ollama pull` and `ollama create`:

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Alternative:** [Ollama for Windows](https://ollama.com/download/windows) on the host. You must pull models from Windows/PowerShell and expose the API (see below). WSL `bootstrap.sh` will not see the Windows `ollama` CLI unless you install it in WSL too.

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

## Expose Ollama to Docker

Containers use `http://host.docker.internal:11434` (see `docker-compose.yml`). Ollama must listen beyond `127.0.0.1` **on the host that Docker Desktop reaches**.

### Ollama installed in WSL (recommended)

If your WSL distro uses **systemd** (Ubuntu 24.04+ with `systemd=true` in `/etc/wsl.conf`, or recent defaults):

```bash
cd ~/home-lab-app
sudo ./scripts/configure-ollama-for-docker.sh
```

If systemd is not enabled in WSL, set `OLLAMA_HOST` before starting Ollama:

```bash
export OLLAMA_HOST=0.0.0.0:11434
ollama serve   # or restart the ollama service after enabling systemd
```

Enable systemd in WSL (if needed), then reboot WSL from PowerShell:

```powershell
# /etc/wsl.conf inside the distro:
# [boot]
# systemd=true
wsl --shutdown
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

Bootstrap checks container reachability via `host.docker.internal` (Docker Desktop), not only `172.17.0.1`.

## Verify

In WSL:

```bash
curl -s http://127.0.0.1:11434/api/tags
docker run --rm --add-host=host.docker.internal:host-gateway curlimages/curl:8.5.0 \
  -sf http://host.docker.internal:11434/api/tags && echo "OK from container"
ollama list
```

Browser on Windows: http://localhost/ (Docker Desktop publishes ports to Windows).

## Troubleshooting

| Symptom | Fix |
|--------|-----|
| `Cannot reach Docker` from bootstrap | Start Docker Desktop; enable WSL integration for this distro |
| `Docker CLI not found inside WSL` | Install Docker Desktop; open distro once; check integration toggle |
| `Ollama not reachable at 127.0.0.1` in WSL | Install Ollama in WSL, or use Windows Ollama + `configure-ollama-windows.ps1` |
| Ollama works in WSL but ingest fails | Run `configure-ollama-for-docker.sh` or set `OLLAMA_HOST=0.0.0.0:11434` |
| Slow file I/O | Move repo off `/mnt/c/` into `~/` |
| `bash\r: No such file` / script won't run | CRLF line endings — `git config core.autocrlf input` and re-checkout, or `dos2unix bootstrap.sh` |
| Line ending issues on clone | Repo includes `.gitattributes` to keep `*.sh` as LF |

## What we do not support on Windows

- Running **only** in CMD/PowerShell without WSL (no native Windows bootstrap for the compose stack).
- Docker Engine inside WSL without Docker Desktop (possible but not documented here).
