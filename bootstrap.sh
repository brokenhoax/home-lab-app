#!/usr/bin/env bash
set -e

echo "Installing Docker (RHEL)..."

# Remove old versions if present
sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true

# Install required packages
sudo yum install -y yum-utils device-mapper-persistent-data lvm2

# Add Docker CE repo
sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Install Docker + Compose plugin
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable + start Docker
sudo systemctl enable --now docker

# Add user to docker group
sudo usermod -aG docker "$USER" || true

echo "Preparing directories..."
mkdir -p ~/lab-app/infra/nginx
cd ~/lab-app

echo "Creating docker-compose.yml..."
cat > docker-compose.yml << 'EOF'
version: "3.9"

services:
  frontend:
    image: brokenhoax/lab-app-frontend:latest
    container_name: lab-app-frontend
    environment:
      NODE_ENV: production
      NEXT_PUBLIC_API_URL: https://krauscloud.com
    depends_on:
      - backend
    networks:
      - lab-app-net

  backend:
    image: brokenhoax/lab-app-backend:latest
    container_name: lab-app-backend
    environment:
      NODE_ENV: production
      PORT: 8000
      USE_HTTPS: "false"
      CHROMA_URL: "http://chroma:8000"
      OLLAMA_HOST: "http://ollama:11434"
      OLLAMA_MODEL: "llama3.1:8b"
      EMBEDDING_MODEL: "nomic-embed-text:v1.5"
    depends_on:
      - chroma
      - ollama
    networks:
      - lab-app-net

  chroma:
    image: chromadb/chroma:latest
    container_name: lab-app-chroma
    volumes:
      - chroma-data:/chroma
    networks:
      - lab-app-net

  ollama:
    image: ollama/ollama:latest
    container_name: lab-app-ollama
    ports:
      - "11434:11434"
    volumes:
      - ollama-data:/root/.ollama
    networks:
      - lab-app-net
    command: >
      /bin/sh -c "
        ollama serve &
        sleep 5 &&
        ollama pull llama3.1:8b &&
        ollama pull nomic-embed-text:v1.5 &&
        wait
      "

  nginx:
    image: nginx:1.27-alpine
    container_name: lab-app-nginx
    ports:
      - "80:80"
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - frontend
      - backend
    networks:
      - lab-app-net

  ingest:
    image: brokenhoax/lab-app-backend:latest
    container_name: lab-app-ingest
    depends_on:
      - chroma
      - ollama
    environment:
      NODE_ENV: production
      CHROMA_URL: "http://chroma:8000"
      OLLAMA_HOST: "http://ollama:11434"
    command: ["npm", "run", "docker_ingest"]
    networks:
      - lab-app-net
    restart: "no"

networks:
  lab-app-net:
    driver: bridge

volumes:
  chroma-data:
  ollama-data:
EOF

echo "Creating nginx.conf..."
cat > infra/nginx/nginx.conf << 'EOF'
events {}

http {
    upstream frontend {
        server frontend:3000;
    }

    upstream backend {
        server backend:8000;
    }

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://frontend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/ {
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

echo "Starting containers..."
docker compose pull
docker compose up -d

echo "Running ingestion..."
docker compose run --rm ingest || true

echo "Deployment complete. Visit: http://<server-ip>/"
