#!/bin/bash

echo "Setting up Skyvern integration..."

# Clone Skyvern repository
if [ ! -d "skyvern" ]; then
    git clone https://github.com/skyvern-ai/skyvern.git
    cd skyvern
    # Checkout latest stable tag or commit if needed
    # git checkout <tag/commit>
    cd ..
fi

# Create Skyvern service configuration
cat << 'EOF' > docker-compose.skyvern.yml
version: '3.8'

services:
  skyvern:
    build: 
      context: ./skyvern
      dockerfile: Dockerfile
    container_name: skyvern
    restart: unless-stopped
    environment:
      - PYTHONUNBUFFERED=1
      - MCP_SERVER_ENABLED=true
      - MCP_SERVER_PORT=3000
      - N8N_URL=http://n8n:5678
      - N8N_API_KEY=${N8N_API_KEY}
      - NOCODB_URL=http://nocodb:8080
      - NOCODB_API_KEY=${NOCODB_API_KEY}
    ports:
      - "3000:3000"  # MCP Server port
    networks:
      - app_network
    volumes:
      - ./skyvern:/app
      - skyvern_data:/data

volumes:
  skyvern_data:

networks:
  app_network:
    external: true
    name: n8n_baserow_app_network
EOF

# Update .env file with Skyvern configuration
if [ ! -f ".env" ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Add Skyvern environment variables if not present
if ! grep -q "SKYVERN_" .env; then
    cat << 'EOF' >> .env

# Skyvern Configuration
SKYVERN_MCP_ENABLED=true
SKYVERN_MCP_PORT=3000
EOF
fi

# Merge Skyvern compose file with main compose file
if ! grep -q "skyvern:" docker-compose.yml; then
    echo "Merging Skyvern configuration with main docker-compose.yml..."
    docker-compose -f docker-compose.yml -f docker-compose.skyvern.yml config > docker-compose.combined.yml
    mv docker-compose.combined.yml docker-compose.yml
fi

echo "Creating MCP server configuration..."

# Create MCP server configuration file
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

echo "Starting Skyvern services..."

# Start services
docker-compose up -d skyvern

echo "Skyvern setup complete!"
echo "MCP Server is accessible at http://localhost:3000"
echo "You can now use Skyvern automation in n8n workflows"