#!/bin/bash

echo "Setting up Browser Use integration..."

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create Browser Use docker-compose override file
echo "Creating Browser Use docker configuration..."
cat > docker-compose.browser-use.yml << 'EOL'
version: '3.8'

services:
  browser-use:
    image: browseruse/automation:latest
    container_name: browser-use
    restart: unless-stopped
    ports:
      - "3003:3003"
    environment:
      - PORT=3003
      - NODE_ENV=production
      - N8N_URL=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
      - CHROME_PATH=/usr/bin/chromium
    networks:
      - app_network
    volumes:
      - browser-use-data:/app/data
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3003/health"]
      interval: 10s
      timeout: 5s
      retries: 5
    cap_add:
      - SYS_ADMIN
    security_opt:
      - seccomp=unconfined
    shm_size: 2gb

volumes:
  browser-use-data:
    driver: local

networks:
  app_network:
    external: true
EOL

# Make script executable
chmod +x setup-browser-use.sh

# Append Browser Use API key information to api_keys.txt
echo "" >> api_keys.txt
echo "Browser Use Service:" >> api_keys.txt
echo "Host: localhost" >> api_keys.txt
echo "Port: 3003" >> api_keys.txt
echo "Uses n8n API key for authentication" >> api_keys.txt

echo "Browser Use setup complete!"
echo "To start using Browser Use:"
echo "1. Run 'docker compose -f docker-compose.yml -f docker-compose.browser-use.yml up -d' to start all services"
echo "2. Access Browser Use at http://localhost:3003"
echo "3. Use the Browser Use nodes in n8n to integrate browser automation capabilities"

# Ensure proper permissions
chmod 600 api_keys.txt