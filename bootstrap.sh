#!/usr/bin/env bash
set -e

echo "=== Installing Docker (RHEL/CentOS) ==="

sudo yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine || true
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker "$USER" || true

echo "=== Preparing project directories ==="
mkdir -p ~/Documents/dev/home-lab-app/infra/nginx
cd ~/Documents/dev/home-lab-app

echo "=== Writing docker-compose.yml ==="
cat > docker-compose.yml << 'EOF'
services:
  frontend:
    image: brokenhoax/lab-app-frontend:latest
    container_name: lab-app-frontend
    environment:
      NODE_ENV: production
      NEXT_PUBLIC_API_URL: "http://localhost"
    depends_on:
      - backend
    networks:
      - lab-app-net

  backend:
    image: brokenhoax/lab-app-backend:latest
    container_name: lab-app-backend
    ports:
      - "8000:8000"
    environment:
      NODE_ENV: production
      PORT: 8000
      USE_HTTPS: "false"
      CHROMA_URL: "http://chroma:8000"
      OLLAMA_HOST: "http://host.docker.internal:11434"
      OLLAMA_MODEL: "llama3.1:8b"
      EMBEDDING_MODEL: "nomic-embed-text:v1.5"
    networks:
      - lab-app-net
    volumes:
      - chroma-data:/app/dist/data
    depends_on:
      - chroma

  chroma:
    image: chromadb/chroma:latest
    container_name: lab-app-chroma
    ports:
      - "9001:8000"
    networks:
      - lab-app-net
    volumes:
      - chroma-data:/chroma

  nginx:
    image: nginx:1.27-alpine
    container_name: lab-app-nginx
    ports:
      - "80:80"
    volumes:
      - ./infra/nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend
      - frontend
    networks:
      - lab-app-net

  ingest:
    image: brokenhoax/lab-app-backend:latest
    container_name: lab-app-ingest
    networks:
      - lab-app-net
    environment:
      NODE_ENV: production
      CHROMA_URL: "http://chroma:8000"
      OLLAMA_HOST: "http://host.docker.internal:11434"

networks:
  lab-app-net:
    driver: bridge

volumes:
  chroma-data:
EOF

echo "=== Writing nginx.conf ==="
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
            proxy_pass http://frontend/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        location /api/ {
            proxy_pass http://backend/api/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }
    }
}
EOF

echo "=== Starting containers ==="
docker compose pull
docker compose up -d

echo "=== Running ingestion (with wait) ==="
docker compose run --rm ingest || true

echo "=== Deployment complete. Visit: http://<server-ip>/ ==="
