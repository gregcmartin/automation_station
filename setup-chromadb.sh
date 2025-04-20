#!/bin/bash

echo "Setting up ChromaDB integration..."

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create ChromaDB docker-compose override file
echo "Creating ChromaDB docker configuration..."
cat > docker-compose.chromadb.yml << 'EOL'
version: '3.8'

services:
  chromadb:
    image: ghcr.io/chroma-core/chroma:latest
    container_name: chromadb
    restart: unless-stopped
    ports:
      - "3004:8000"
    environment:
      - CHROMA_DB_IMPL=duckdb+parquet
      - CHROMA_API_IMPL=rest
      - CHROMA_SERVER_HOST=0.0.0.0
      - CHROMA_SERVER_HTTP_PORT=8000
      - PERSIST_DIRECTORY=/chroma/data
      - ALLOW_RESET=false
      - CHROMA_SERVER_AUTH_CREDENTIALS=${CHROMADB_API_KEY:-admin:admin}
      - CHROMA_SERVER_AUTH_CREDENTIALS_PROVIDER=basic
      - N8N_URL=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
    networks:
      - app_network
    volumes:
      - chromadb-data:/chroma/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/api/v1/heartbeat"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  chromadb-data:
    driver: local

networks:
  app_network:
    external: true
EOL

# Make script executable
chmod +x setup-chromadb.sh

# Append ChromaDB API key information to api_keys.txt
echo "" >> api_keys.txt
echo "ChromaDB Service:" >> api_keys.txt
echo "Host: localhost" >> api_keys.txt
echo "Port: 3004" >> api_keys.txt
echo "Default Credentials:" >> api_keys.txt
echo "Username: admin" >> api_keys.txt
echo "Password: admin" >> api_keys.txt
echo "WARNING: Change these credentials in production!" >> api_keys.txt

echo "ChromaDB setup complete!"
echo "To start using ChromaDB:"
echo "1. Run 'docker compose -f docker-compose.yml -f docker-compose.chromadb.yml up -d' to start all services"
echo "2. Access ChromaDB at http://localhost:3004"
echo "3. Use the ChromaDB nodes in n8n to integrate vector database capabilities"
echo "4. Default credentials: admin:admin (change these in production)"

# Ensure proper permissions
chmod 600 api_keys.txt