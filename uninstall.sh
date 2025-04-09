#!/bin/bash

echo "Starting uninstallation of n8n and Baserow..."

# Stop and remove all containers
docker-compose down -v

# Remove API keys file
rm -f api_keys.txt

echo "Uninstallation complete! All containers, volumes, and configuration have been removed."