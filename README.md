# Home Lab App

Thanks for checking out the Home Lab App!

Deploying the Home Lab App has never been easier. It's essentially a two step process, outlined below. This README will guide you through the first step—setting the correct environment variables for the app. Then, for the second step, and depending on what Operating System (OS) you're running (i.e., Windows, Linux, macOS), you'll follow the deployment steps in the respective README documents found in the "docs" folder within the "home-lab-app" repository.

Let's get started!

## About the Project

Home Lab App is intended to be used in home lab environments for educational purposes. It runs a simple NGINX web server to serve up a simple blog application. It also provides a simple backend API running on Node.js. And it also has a built-in, self-hosted chatbot. In the future, Home Lab App will include blog posts that demonstrate how to build your own home lab and how to use the Home Lab App to experiment with and learn new technologies.

The core components of the Home Lab App include:

- Frontend (Next.js)
- Backend (Node.js)
- NGINX reverse proxy
- ChromaDB (vector database)
- Ingestion job
- Ollama LLM

```
📢 Ollama placement depends on platform

On macOS, Ollama runs on the host (native app) so Apple Silicon can use the GPU — Docker on Mac cannot expose the Apple GPU to containers. On WSL and RHEL, bootstrap runs Ollama in Docker (`docker-compose.linux.yml`) so you only need Docker; models are pulled automatically.
```

---

## Step 1 — Set Environment Variables (`backend.env`)

For the Docker stack deployed from this repo, `backend.env` is the one file you edit for secrets and environment-specific overrides. Bootstrap creates it from `backend.env.example` on first run if it is missing. So, update only what you need/want and, if you're not sure, leave it untouched. That said, go ahead and copy the example environment variable file and rename it to "backend.env".

```bash
cd ~/Documents/dev/home-lab-app
cp backend.env.example backend.env
```


| Variable                           | Required? | Typical home-lab value                                                                      | When to change                                                                     |
| ---------------------------------- | --------- | ------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| `AI_GUARD_KEY`                     | No        | empty (guard disabled)                                                                      | Enable Zscaler AI Guard                                                            |
| `XAI_API_KEY`                      | No        | empty                                                                                       | Use xAI as a chat provider                                                         |
| `DEV_ENV_IP_ADDR`                  | No        | empty                                                                                       | Dev bind address (see `blog-backend`)                                              |
| `PROD_ENV_IP_ADDR`                 | No        | empty                                                                                       | Documented in backend templates; prod compose listens on all interfaces via `PORT` |
| `CHROMA_URL`                       | No        | `http://chroma:8000` in compose                                                             | Custom Chroma host                                                                 |
| `OLLAMA_HOST`                      | No        | `http://ollama:11434` (Window WSL and Linux) or `http://host.docker.internal:11434` (macOS) | Ollama on another machine                                                          |
| `CERT_KEY_PATH` / `CERT_CERT_PATH` | No        | empty                                                                                       | Host HTTPS outside the default compose/nginx setup                                 |


```
📢 Leaving values uncommented in "backend.env" will compose with defaults. Furthermore, the values in "docker-compose.yml" (i.e., "environment:") will override "env_file" (in this case, ".backend.env") for the same key.
```

The following settings are not in `backend.env`:


| Setting                                               | Where to configure                                                                                                     |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| **Ollama listen address** (host Ollama on macOS only) | [macos.md](docs/macos.md) — usually no config needed; Linux uses container Ollama                                      |
| **Frontend API URL** (`NEXT_PUBLIC_API_URL`)          | `docker-compose.yml` → `frontend` service (change if users reach the app by hostname/IP other than `http://localhost`) |
| **Chat / embedding model names**                      | Hardcoded in `blog-backend` today; bootstrap pulls Ollama models listed in README                                      |
| **CORS allowed origins**                              | `blog-backend/server.ts` (change if frontend is served from another origin)                                            |


---

## Step 2 — Bootstrap the Home Lab App

You've completed the prerequisite step of setting your environment variables. Next, depending on what OS you're running, you will bootstrap Home Lab App by following the simple deployment steps found in the respective OS-specific guides:


| Platform                                 | Guide                                    | Bootstrap                                    |
| ---------------------------------------- | ---------------------------------------- | -------------------------------------------- |
| **Linux (RHEL / CentOS / Rocky / Alma)** | [docs/linux-rhel.md](docs/linux-rhel.md) | `./bootstrap.sh`                             |
| **Windows 11 + WSL 2**                   | [docs/windows.md](docs/windows.md)       | `.\bootstrap.ps1` or `./bootstrap.sh` in WSL |
| **macOS**                                | [docs/macos.md](docs/macos.md)           | `./bootstrap.sh`                             |


---

## Miscellaneous

### Ollama models (all platforms)

`bootstrap.sh` pulls base models and builds the custom chat model from `ollama/Modelfile`:


| Model                   | Purpose                        |
| ----------------------- | ------------------------------ |
| `llama3.1:8b`           | Base for `kraus-cloud-llama`   |
| `nomic-embed-text:v1.5` | Embeddings / RAG               |
| `llama-guard3:8b`       | Safety filter                  |
| `kraus-cloud-llama`     | Chat (from `ollama/Modelfile`) |


---

### Troubleshooting (all platforms)


| Symptom                              | What to check                                                                         |
| ------------------------------------ | ------------------------------------------------------------------------------------- |
| Terminal closes immediately          | Run from an existing terminal; do not double-click scripts                            |
| Ingestion / chat errors              | Linux: `docker compose … logs ollama`; macOS: start Ollama.app — see your OS guide    |
| Chat **504 Gateway Timeout**         | `docker compose restart nginx`; first reply can take several minutes on slow hardware |
| `permission denied` on `docker.sock` | RHEL / WSL: add user to `docker` group — see your OS guide; macOS uses Docker Desktop |


