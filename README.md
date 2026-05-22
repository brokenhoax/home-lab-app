# Home Lab App — Deployment Guide

This project runs:

- Frontend (Next.js)
- Backend (Node.js)
- ChromaDB (vector database)
- NGINX reverse proxy
- Ingestion job

**Ollama does NOT run in Docker.**  
It runs natively on the host because the Docker image is not compatible with all CPUs.

---

## 1. Install Ollama on the host

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

## 2. Ollama models (bootstrap does this automatically)

`./bootstrap.sh` pulls base models and builds the custom chat model from `ollama/Modelfile`:

| Model | Purpose |
|-------|---------|
| `llama3.1:8b` | Base for `kraus-cloud-llama` |
| `nomic-embed-text:v1.5` | Embeddings / RAG |
| `llama-guard3:8b` | Safety filter |
| `kraus-cloud-llama` | Chat (created via `ollama create` from Modelfile) |

Manual equivalent:

```bash
ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b
ollama create kraus-cloud-llama -f ollama/Modelfile
```

## 3. Verify your work

```bash
ollama list
ollama ps
```

You should see `kraus-cloud-llama` in `ollama list`.

## 4. Expose Ollama to Docker (Linux only — required for chat / ingestion)

The backend runs in Docker and talks to Ollama at `http://host.docker.internal:11434` (the host gateway, usually `172.17.0.1`). Ollama’s default bind is **127.0.0.1 only**, so the stack works on Mac but chat fails on RHEL until you widen the listen address.

**`/etc/ollama/config.yaml` does not set the listen address** on current Ollama builds. Use systemd instead:

```bash
cd ~/Documents/dev/home-lab-app
sudo ./scripts/configure-ollama-for-docker.sh
```

Or manually:

```bash
sudo mkdir -p /etc/systemd/system/ollama.service.d
printf '%s\n' '[Service]' 'Environment="OLLAMA_HOST=0.0.0.0:11434"' | sudo tee /etc/systemd/system/ollama.service.d/environment.conf
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

Verify (both should succeed):

```bash
curl -s http://127.0.0.1:11434/api/tags
curl -s http://172.17.0.1:11434/api/tags
```

Then re-run `./bootstrap.sh` if ingestion failed earlier.
