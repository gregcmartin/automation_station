#!/bin/bash

echo "Starting update process..."

# Check if docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Pull latest images
echo "Pulling latest Docker images..."
docker compose pull nocodb n8n postgres redis
if [ -d "firecrawl" ]; then
    echo "Pulling latest Firecrawl image..."
    docker compose -f docker-compose.yml -f docker-compose.firecrawl.yml pull firecrawl
fi

# Check if Skyvern is installed and update it
if [ -d "skyvern" ]; then
    echo "Updating Skyvern..."
    cd skyvern
    git pull origin main
    cd ..
fi

# Check if Firecrawl is installed and update it
if [ -d "firecrawl" ]; then
    echo "Updating Firecrawl..."
    cd firecrawl
    git pull origin main
    cd ..
fi

# Stop current containers
echo "Stopping current containers..."
docker compose down

# Start updated containers
echo "Starting updated containers with new versions..."
if [ -d "firecrawl" ]; then
    docker compose -f docker-compose.yml -f docker-compose.firecrawl.yml up -d
else
    docker compose up -d
fi

# Wait for services to be healthy
echo "Waiting for services to be healthy..."
sleep 10

# Check if services are running
if docker compose ps | grep -q "Up"; then
    echo "Services updated and running successfully!"
    
    # Display current versions
    echo -e "\nCurrent versions:"
    echo "NocoDB: $(docker compose exec nocodb node -e 'console.log(require("./package.json").version)' 2>/dev/null)"
    echo "n8n: $(docker compose exec n8n n8n --version 2>/dev/null)"
    
    if [ -d "skyvern" ]; then
        echo "Skyvern: $(cd skyvern && git describe --tags 2>/dev/null || echo 'latest')"
    fi
    
    if [ -d "firecrawl" ]; then
        echo "Firecrawl: $(cd firecrawl && git describe --tags 2>/dev/null || echo 'latest')"
    fi
else
    echo "Error: Some services failed to start. Please check docker compose logs."
    exit 1
fi