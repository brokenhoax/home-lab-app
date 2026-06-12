# Home Lab App

Thanks for checking out the Home Lab App!

Before proceeding, please ensure you have read the main "README.md" file in this repository as there are some critical prerequisites that must be completed before Home Lab App will function correctly. Once those prerequisites are met, the following instructions will help you through deploying the Home Lab App in a few simple commands.

Let's get started!

```
🪟🐧 This particular set of instructions is for Windows environments running Windows Subsystem for Linux (WSL) environments.
```

## Requirements

### Windows 11 — WSL 2

Run the stack inside Windows Subsystem for Linux (WSL).

Ubuntu is recommended.

Windows is not Linux, but WSL 2 runs a real Linux kernel — install Docker Engine in your distro (e.g., Ubuntu). Docker Desktop is not required!

## Prerequisites (install before `./bootstrap.sh`)


| Item                                        | Required?   | Notes                                                                                                  |
| ------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------ |
| **Windows 11** (Home or Pro)                | Yes         | WSL 2 required                                                                                         |
| **WSL 2 + Ubuntu** (or similar)             | Yes         | `wsl --install` or `wsl --install -d Ubuntu`                                                           |
| **Docker Engine in WSL**                    | Yes         | `docker` + `docker compose`; `dockerd` running — see [Install Docker](#2-install-docker-engine-in-wsl) |
| **systemd in WSL**                          | Recommended | Needed for the `docker` service — see below                                                            |
| Git                                         | Recommended | Clone under `~/` in WSL, not only on `C:\`                                                             |
| Ports **80**, **8000**, **9001**, **11434** | Yes         | Published to Windows `localhost` from WSL                                                              |
| Docker Hub login                            | No          | Public images                                                                                          |


Hardware: enough RAM/disk for Docker images plus Ollama models (~several GB for `llama3.1:8b`). **Ollama runs in Docker** on Linux/WSL — bootstrap pulls models automatically; no separate Ollama install.

**Checklist:** WSL Ubuntu → enable systemd → Docker Engine in WSL → clone to `~/home-lab-app` → `./bootstrap.sh`.

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

Docker Engine is easiest to manage with systemd. In WSL:

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

---

## Bootstrap

### Option A — from WSL (preferred)

```bash
cd ~/home-lab-app
chmod +x bootstrap.sh
./bootstrap.sh
```

Bootstrap uses `docker-compose.linux.yml` to run **Ollama in a container**, pull models, start the stack, and run ingestion.

### Option B — from PowerShell (launches WSL)

From the repo folder on a Windows path (e.g. cloned to `C:\dev\home-lab-app`):

```powershell
cd C:\dev\home-lab-app
.\bootstrap.ps1
```

This maps the path with `wslpath` and runs `./bootstrap.sh` in your default WSL distro.

Do **not** double-click scripts; the window may close on exit. Use Windows Terminal or PowerShell.

Logs: `bootstrap.log` in the repo root (WSL path).

After a successful bootstrap on any platform:

- App: [http://localhost/](http://localhost/)
- Backend: [http://localhost:8000](http://localhost:8000)
- Chroma (host port): [http://localhost:9001](http://localhost:9001)

Logs: `bootstrap.log` in the repo root.

---

## Verify

In WSL:

```bash
docker compose -f docker-compose.yml -f docker-compose.linux.yml ps
docker compose -f docker-compose.yml -f docker-compose.linux.yml exec ollama ollama list
curl -s http://127.0.0.1:11434/api/tags
```

Browser on Windows: [http://localhost/](http://localhost/) (WSL forwards published container ports to Windows localhost).

---

## Troubleshooting


| Symptom                                   | Fix                                                                                                            |
| ----------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| `Cannot reach Docker` from bootstrap      | `sudo systemctl start docker` or ensure `dockerd` is running; `docker info` must succeed in WSL                |
| `Docker CLI not found inside WSL`         | Install Docker Engine in WSL — [section 2](#2-install-docker-engine-in-wsl)                                    |
| `permission denied` on `docker.sock`      | `sudo usermod -aG docker $USER`, then `wsl --shutdown` and reopen Ubuntu, or `newgrp docker`                   |
| Ollama / ingest errors                    | `docker compose -f docker-compose.yml -f docker-compose.linux.yml logs ollama`; ensure models finished pulling |
| Slow first chat reply                     | Normal while `llama3.1:8b` loads; first model pull can take many minutes                                       |
| Slow file I/O                             | Move repo off `/mnt/c/` into `~/`                                                                              |
| `bash\r: No such file` / script won't run | CRLF line endings — `git config core.autocrlf input` and re-checkout, or `dos2unix bootstrap.sh`               |
| Line ending issues on clone               | Repo includes `.gitattributes` to keep `*.sh` as LF                                                            |


---

## What we do not support on Windows

- Running **only** in CMD/PowerShell without WSL (no native Windows bootstrap for the compose stack).
- Docker on Windows **without** WSL (no documented Hyper-V-only path).

---

## Optional: Docker Desktop

[Docker Desktop](https://www.docker.com/products/docker-desktop/) can provide Docker via WSL integration instead of installing Engine yourself. This project does **not** require it if `docker info` works inside your distro. If you use Desktop, enable **Settings → Resources → WSL integration** for your Ubuntu distro.