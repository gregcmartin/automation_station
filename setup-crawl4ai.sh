#!/bin/bash

echo "Setting up Crawl4AI integration..."

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

# Function to check container logs
check_logs() {
    echo "Checking logs for crawl4ai..."
    docker-compose -f docker-compose.yml -f docker-compose.crawl4ai.yml logs --tail=50 crawl4ai
}

# Clone Crawl4AI repository if not exists
if [ ! -d "crawl4ai" ]; then
    echo "Cloning Crawl4AI repository..."
    git clone https://github.com/unclecode/crawl4ai.git
    if [ $? -ne 0 ]; then
        echo "Failed to clone Crawl4AI repository"
        exit 1
    fi
else
    echo "Crawl4AI repository already exists, updating..."
    cd crawl4ai
    git pull origin main
    cd ..
fi

# Create Crawl4AI docker-compose override file
echo "Creating Crawl4AI docker configuration..."
cat > docker-compose.crawl4ai.yml << 'EOL'
services:
  crawl4ai:
    build:
      context: ./crawl4ai
      dockerfile: Dockerfile
      args:
        - NODE_ENV=production
    container_name: crawl4ai
    restart: unless-stopped
    ports:
      - "3002:3002"
    environment:
      - PORT=3002
      - NODE_ENV=production
      - N8N_URL=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
      - GUNICORN_CMD_ARGS="--bind=0.0.0.0:3002 --workers=2 --access-logfile=- --error-logfile=- --timeout=30"
    networks:
      - app_network
    volumes:
      - crawl4ai-data:/data
      - ./crawl4ai/deploy/docker/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro
    command: supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
    user: root
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3002/api/health || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  crawl4ai-data:
    driver: local

networks:
  app_network:
    external: true
EOL

# Build the Crawl4AI image
echo "Building Crawl4AI image..."
if ! docker-compose -f docker-compose.yml -f docker-compose.crawl4ai.yml build crawl4ai; then
    echo "Failed to build Crawl4AI image"
    exit 1
fi

# Ensure network exists
echo "Ensuring Docker network exists..."
if ! docker network inspect app_network >/dev/null 2>&1; then
    echo "Creating app_network..."
    docker network create app_network
fi

# Ensure core services are running
echo "Ensuring core services are running..."
if ! docker-compose ps | grep -q "postgres.*Up"; then
    echo "Starting core services..."
    docker-compose up -d postgres redis
    
    # Wait for PostgreSQL to be ready
    echo "Waiting for PostgreSQL..."
    until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
        sleep 5
        echo "Still waiting for PostgreSQL..."
    done
fi

# Start Crawl4AI service
echo "Starting Crawl4AI service..."
if ! docker-compose -f docker-compose.yml -f docker-compose.crawl4ai.yml up -d crawl4ai; then
    echo "Failed to start Crawl4AI service"
    check_logs
    exit 1
fi

# Wait for Crawl4AI to be ready
echo "Waiting for Crawl4AI to be ready..."
READY=0
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $READY -eq 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    echo "Checking Crawl4AI status (Attempt $((ATTEMPT + 1)) of $MAX_ATTEMPTS)..."
    
    # Check container status
    if ! CRAWL4AI_STATUS=$(docker-compose -f docker-compose.yml -f docker-compose.crawl4ai.yml ps -a crawl4ai | grep crawl4ai | awk '{print $4}'); then
        echo "Failed to get container status"
        check_logs
        exit 1
    fi
    echo "Crawl4AI container status: $CRAWL4AI_STATUS"
    
    # Check if container is running and healthy
    if ! docker inspect --format='{{.State.Health.Status}}' crawl4ai 2>/dev/null | grep -q "healthy"; then
        echo "Container is not healthy"
        check_logs
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
        continue
    fi
    
    # Try health check with verbose output
    HEALTH_CHECK_RESPONSE=$(curl -v http://localhost:3002/api/health -o /dev/null 2>&1 | grep "< HTTP" | awk '{print $3}')
    if [ "$HEALTH_CHECK_RESPONSE" = "200" ]; then
        READY=1
        echo "Crawl4AI health check passed"
    else
        echo "Crawl4AI health check failed (HTTP $HEALTH_CHECK_RESPONSE)"
        check_logs
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $READY -eq 0 ]; then
    echo "Error: Crawl4AI failed to become ready within timeout"
    check_logs
    docker-compose -f docker-compose.yml -f docker-compose.crawl4ai.yml logs crawl4ai
    exit 1
fi

echo "Verifying Crawl4AI API..."
if ! curl -s http://localhost:3002/api/health > /dev/null; then
    echo "Error: Failed to verify Crawl4AI API"
    check_logs
    exit 1
fi

echo "Crawl4AI setup complete!"
echo "Crawl4AI is now running at http://localhost:3002"
echo "You can use the Crawl4AI node in n8n to integrate web crawling capabilities"