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

## 2. Pull the Ollama models

ollama pull llama3.1:8b
ollama pull nomic-embed-text:v1.5
ollama pull llama-guard3:8b

## 3. Verify Your Work
ollama list
ollama ps

## 4. Create an Ollama config file (if it doesn't exist)
sudo mkdir -p /etc/ollama
sudo nano /etc/ollama/config.yaml

## 5. Add the following text to it:
listen: 0.0.0.0:11434

## 6. Restart Ollama
sudo systemctl restart ollama
