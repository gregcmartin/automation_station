#!/bin/bash

echo "Resetting n8n and NocoDB to default installation..."

# Stop containers but keep volumes
docker-compose down

# Start services again
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

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; do
    sleep 5
    echo "Still waiting for PostgreSQL..."
done

# Wait for Redis to be ready
echo "Waiting for Redis to be ready..."
until docker-compose exec -T redis redis-cli -a password ping | grep -q "PONG"; do
    sleep 5
    echo "Still waiting for Redis..."
done

# Wait for n8n to be ready (checking every 5 seconds)
echo "Waiting for n8n to be ready..."
until curl -s http://localhost:5678/healthz > /dev/null; do
    sleep 5
    echo "Still waiting for n8n..."
done

echo "n8n is ready and configured with demo user account"

# Wait for NocoDB to be ready (checking every 5 seconds)
echo "Waiting for NocoDB to be ready..."
READY=0
MAX_ATTEMPTS=60  # 5 minutes timeout
ATTEMPT=0

while [ $READY -eq 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/v1/health)
    if [ "$RESPONSE" = "200" ]; then
        READY=1
    else
        echo "Still waiting for NocoDB... (Attempt $ATTEMPT of $MAX_ATTEMPTS)"
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $READY -eq 0 ]; then
    echo "Error: NocoDB failed to become ready within timeout"
    exit 1
fi

echo "NocoDB is ready. Waiting for full initialization..."
sleep 30  # Give extra time for NocoDB to fully initialize

echo "Creating demo user..."

# Create NocoDB demo user account
SIGNUP_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/user/signup \
  -H "Content-Type: application/json" \
  -d '{
    "email": "demouser",
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
    "email": "demouser",
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

echo "Generating API token..."

# Generate API token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8080/api/v1/auth/token \
  -H "xc-auth: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Full Access Token",
    "permissions": ["*"]
  }')
check_response $? "API token generation"
debug_response "API token generation" "$TOKEN_RESPONSE"

API_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r .token)

if [ "$API_TOKEN" == "null" ] || [ -z "$API_TOKEN" ]; then
    echo "Error: Failed to generate API token"
    echo "Response: $TOKEN_RESPONSE"
    exit 1
fi

# Save API token to file
echo "$API_TOKEN" > api_keys.txt

# Verify API token was saved
if [ ! -s api_keys.txt ]; then
    echo "Error: API token file is empty"
    exit 1
fi

echo "Reset complete!"
echo "NocoDB URL: http://localhost:8080"
echo "n8n URL: http://localhost:5678"
echo "Credentials for both services: demouser / DemoUser132!"
echo "New API token has been saved to api_keys.txt"

# Final verification
echo "Verifying services..."
curl -s http://localhost:8080/api/v1/health > /dev/null
check_response $? "NocoDB final verification"
curl -s http://localhost:5678/healthz > /dev/null
check_response $? "n8n final verification"
echo "All services verified!"