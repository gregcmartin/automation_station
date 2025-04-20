#!/bin/bash

echo "Setting up Skyvern integration..."

# Create Skyvern MCP server configuration
cat << 'EOF' > mcp-config.json
{
  "servers": [
    {
      "name": "skyvern",
      "type": "local",
      "host": "localhost",
      "port": 3000,
      "tools": [
        {
          "name": "browser_automation",
          "description": "Automate browser interactions using Skyvern",
          "input_schema": {
            "type": "object",
            "properties": {
              "url": {
                "type": "string",
                "description": "URL to navigate to"
              },
              "actions": {
                "type": "array",
                "items": {
                  "type": "object",
                  "properties": {
                    "type": {
                      "type": "string",
                      "enum": ["click", "type", "wait", "screenshot"]
                    },
                    "selector": {
                      "type": "string"
                    },
                    "value": {
                      "type": "string"
                    }
                  }
                }
              }
            }
          }
        }
      ]
    }
  ]
}
EOF

echo "Creating MCP server configuration..."

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL to be ready..."
until PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U postgres -d postgres -c '\l' > /dev/null 2>&1; do
  echo "PostgreSQL is unavailable - sleeping"
  sleep 1
done

echo "PostgreSQL is ready"

# Create Skyvern database
echo "Creating Skyvern database..."
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U postgres -d postgres -c "DROP DATABASE IF EXISTS skyvern;"
PGPASSWORD=$POSTGRES_PASSWORD psql -h localhost -U postgres -d postgres -c "CREATE DATABASE skyvern;"

# Start services
echo "Starting Skyvern services..."
docker-compose up -d skyvern-db skyvern

# Wait for Skyvern to be ready
echo "Waiting for Skyvern to be ready..."
READY=0
MAX_ATTEMPTS=60
ATTEMPT=0

while [ $READY -eq 0 ] && [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    echo "Checking Skyvern status (Attempt $ATTEMPT of $MAX_ATTEMPTS)..."
    
    # Check container status
    SKYVERN_STATUS=$(docker-compose ps -a skyvern | grep skyvern | awk '{print $4}')
    echo "Skyvern container status: $SKYVERN_STATUS"
    
    # Check container logs
    docker-compose logs --tail=50 skyvern
    
    # Try health check
    if curl -s http://localhost:3000/health > /dev/null; then
        READY=1
        echo "Skyvern health check passed"
    else
        echo "Skyvern health check failed"
        sleep 5
        ATTEMPT=$((ATTEMPT + 1))
    fi
done

if [ $READY -eq 0 ]; then
    echo "Error: Skyvern failed to become ready within timeout"
    docker-compose logs skyvern
    exit 1
fi

echo "Updating n8n credentials..."

# Get n8n API key
N8N_API_KEY=$(grep "N8N_API_KEY" .env | cut -d '=' -f2)

# Update n8n with Skyvern credentials
curl -X POST http://localhost:5678/api/v1/credentials \
  -H "Authorization: Bearer ${N8N_API_KEY}" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Skyvern",
    "type": "mcp",
    "data": {
      "host": "localhost",
      "port": 3000
    }
  }'

# Append Skyvern API key information to api_keys.txt
echo "" >> api_keys.txt
echo "Skyvern MCP Server:" >> api_keys.txt
echo "Host: localhost" >> api_keys.txt
echo "Port: 3000" >> api_keys.txt
echo "Uses n8n API key for authentication" >> api_keys.txt

echo "Skyvern setup complete!"
echo "MCP Server is accessible at http://localhost:3000"
echo "You can now use Skyvern automation in n8n workflows"

# Ensure proper permissions
chmod 600 api_keys.txt