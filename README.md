# KrausCloud Blog – Home Lab Deployment

This repository contains the Docker-only deployment for the KrausCloud Blog + Chatbot (RAG over DMV dataset).

## Components

- **frontend** – Next.js UI
- **backend** – Express API + RAG ingestion + embeddings
- **chroma** – Vector database
- **ollama** – LLM + embeddings
- **nginx** – Reverse proxy
- **ingest** – One-shot ingestion job

## Requirements

- Ubuntu Server 22.04+
- Docker
- Docker Compose v2

## Quick Start

```bash
git clone https://github.com/yourname/home-lab-blog.git
cd home-lab-blog

chmod +x bootstrap.sh
./bootstrap.sh
```
