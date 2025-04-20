#!/bin/bash

echo "Setting up Firecrawl integration..."

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "Git is not installed. Please install git and try again."
    exit 1
fi

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Clone Firecrawl repository if not exists
if [ ! -d "firecrawl" ]; then
    echo "Cloning Firecrawl repository..."
    git clone https://github.com/mendableai/firecrawl.git
    if [ $? -ne 0 ]; then
        echo "Failed to clone Firecrawl repository"
        exit 1
    fi
else
    echo "Firecrawl repository already exists, updating..."
    cd firecrawl
    git pull origin main
    cd ..
fi

# Create Firecrawl docker-compose override file
echo "Creating Firecrawl docker configuration..."
cat > docker-compose.firecrawl.yml << 'EOL'
version: '3.8'

services:
  firecrawl:
    image: ghcr.io/mendableai/firecrawl:latest
    container_name: firecrawl
    restart: unless-stopped
    ports:
      - "3001:3001"
    environment:
      - PORT=3001
      - NODE_ENV=production
    networks:
      - app-network
    volumes:
      - firecrawl-data:/app/data

volumes:
  firecrawl-data:
    driver: local

networks:
  app-network:
    external: true
EOL

echo "Firecrawl setup complete!"
echo "To start using Firecrawl:"
echo "1. Run 'docker compose -f docker-compose.yml -f docker-compose.firecrawl.yml up -d' to start all services"
echo "2. Access Firecrawl at http://localhost:3001"