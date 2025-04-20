#!/bin/bash

echo "Starting n8n and NocoDB installation..."

# Pull latest images and start services
docker-compose pull
docker-compose up -d

# Function to check if a curl request was successful
check_response() {
    if [ $1 -ne 0 ]; then
        echo "Error: $2 failed"
        exit 1
    fi
}

# Function to debug API response
debug_response() {
    echo "Debug: API Response for $1:"
    echo "$2"
    echo "---"
}

# Function to check container logs
check_logs() {
    echo "Checking logs for $1..."
    docker-compose logs --tail=50 "$1"
}

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
    sleep 5
    echo "Still waiting for PostgreSQL..."
    check_logs postgres
done

echo "PostgreSQL is ready"

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
until docker-compose exec -T redis redis-cli -a password ping | grep -q "PONG"; do
    sleep 5
    echo "Still waiting for Redis..."
    check_logs redis
done

echo "Redis is ready"

# Wait for n8n to be ready with detailed debugging
echo "Waiting for n8n to be ready..."
N8N_READY=0
N8N_ATTEMPTS=0
MAX_N8N_ATTEMPTS=60

while [ $N8N_READY -eq 0 ] && [ $N8N_ATTEMPTS -lt $MAX_N8N_ATTEMPTS ]; do
    echo "Checking n8n status (Attempt $N8N_ATTEMPTS of $MAX_N8N_ATTEMPTS)..."
    
    # Check container status
    N8N_STATUS=$(docker-compose ps -a n8n | grep n8n | awk '{print $4}')
    echo "n8n container status: $N8N_STATUS"
    
    # Check container logs
    check_logs n8n
    
    # Try health check
    if curl -s http://localhost:5678/healthz > /dev/null; then
        echo "n8n health check passed"
        N8N_READY=1
    else
        echo "n8n health check failed"
        sleep 5
        N8N_ATTEMPTS=$((N8N_ATTEMPTS + 1))
    fi
done

if [ $N8N_READY -eq 0 ]; then
    echo "Error: n8n failed to become ready within timeout"
    check_logs n8n
    exit 1
fi

echo "n8n is ready and configured with demo user account"

# Wait for NocoDB to be ready with detailed debugging
echo "Waiting for NocoDB to be ready..."
READY=0
MAX_ATTEMPTS=60  # 5 minutes timeout
ATTEMPT=0

while [ $READY -eq 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    echo "Checking NocoDB status (Attempt $ATTEMPT of $MAX_ATTEMPTS)..."
    
    # Check container status
    NOCODB_STATUS=$(docker-compose ps -a nocodb | grep nocodb | awk '{print $4}')
    echo "NocoDB container status: $NOCODB_STATUS"
    
    # Check container logs
    check_logs nocodb
    
    # Try health check
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/health)
    if [ "$RESPONSE" = "200" ]; then
        READY=1
        echo "NocoDB health check passed"
    else
        echo "NocoDB health check failed (HTTP $RESPONSE)"
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $READY -eq 0 ]; then
    echo "Error: NocoDB failed to become ready within timeout"
    check_logs nocodb
    exit 1
fi

echo "NocoDB is ready. Waiting for full initialization..."
sleep 30  # Give extra time for NocoDB to fully initialize

echo "Creating demo user..."

# Create NocoDB demo user account
SIGNUP_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/user/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "DemoUser132!",
    "roles": "user"
  }')
check_response $? "NocoDB user creation"
debug_response "NocoDB user creation" "$SIGNUP_RESPONSE"

echo "Logging in to get auth token..."

# Login to get token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/user/signin \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demo@example.com",
    "password": "DemoUser132!"
  }')
check_response $? "NocoDB authentication"
debug_response "NocoDB authentication" "$TOKEN_RESPONSE"

TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .token)

if [ "$TOKEN" == "null" ] || [ -z "$TOKEN" ]; then
    echo "Error: Failed to get authentication token"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

echo "Creating CRM project..."

# Create CRM project
PROJECT_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/db/meta/projects \
  -H "xc-auth: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "CRM",
    "type": "database"
  }')
check_response $? "CRM project creation"
debug_response "CRM project creation" "$PROJECT_RESPONSE"

PROJECT_ID=$(echo "$PROJECT_RESPONSE" | jq -r .id)

if [ "$PROJECT_ID" == "null" ] || [ -z "$PROJECT_ID" ]; then
    echo "Error: Failed to create CRM project"
    echo "Response: $PROJECT_RESPONSE"
    exit 1
fi

# Save API tokens to file with labels
echo "# API Keys for n8n and NocoDB Services" > api_keys.txt
echo "# Generated on $(date)" >> api_keys.txt
echo "" >> api_keys.txt
echo "NocoDB API Key:" >> api_keys.txt
echo "$TOKEN" >> api_keys.txt
echo "" >> api_keys.txt
echo "n8n API Key:" >> api_keys.txt
echo "${N8N_API_KEY}" >> api_keys.txt

# Verify API token file was created and has content
if [ ! -s api_keys.txt ]; then
    echo "Error: API token file is empty"
    exit 1
fi

# Set proper permissions on API keys file
chmod 600 api_keys.txt

echo "Installation complete!"
echo "NocoDB URL: http://localhost:8080"
echo "n8n URL: http://localhost:5678"
echo "Credentials for both services: demo@example.com / DemoUser132!"
echo "API token has been saved to api_keys.txt"

# Final verification
echo "Verifying services..."
curl -s http://localhost:8080/api/v1/health > /dev/null
check_response $? "NocoDB final verification"
curl -s http://localhost:5678/healthz > /dev/null
check_response $? "n8n final verification"
echo "All services verified!"