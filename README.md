# Automation Station :)
This is a set of scripts for Docker that automatically sets up n8n and NocoDB with PostgreSQL and Redis backends. The setup works natively on OSX or Ubuntu and provides installation, uninstallation, and reset capabilities.

## Features

- Automatic installation of latest versions from GitHub:
  - n8n (workflow automation)
  - NocoDB (no-code database platform)
  - PostgreSQL 15 (database backend)
  - Redis 7 (caching layer)
- Automatic user account setup (user: demouser, pass: DemoUser132!)
- Automatic CRM project creation in NocoDB
- Automatic API token generation (saved to api_keys.txt)
- Complete uninstallation capability
- Reset to default base installation
- Health checks for all services

## Requirements

- Docker and Docker Compose installed
- curl (for API interactions)
- jq (for JSON processing)

## System Architecture

The setup includes:
- NocoDB with PostgreSQL backend for data persistence
- Redis for caching and improved performance
- n8n configured with PostgreSQL backend for workflow storage
- All services connected via Docker network
- Health checks for PostgreSQL and Redis
- Service dependencies properly configured

## Installation

To install n8n and NocoDB:

```bash
./install.sh
```

This will:
1. Pull the latest images
2. Start all services with proper health checks
3. Create the demo user account
4. Set up the CRM project
5. Generate and save the API token

## Accessing the Services

After installation:
- NocoDB: http://localhost:8080
- n8n: http://localhost:5678

Default credentials for both services:
- Username: demouser
- Password: DemoUser132!

The API token will be saved in api_keys.txt

## Uninstallation

To completely remove the installation:

```bash
./uninstall.sh
```

This will:
1. Stop all containers
2. Remove all containers and volumes
3. Remove the API token file

## Reset to Default

To reset to a fresh installation while preserving Docker volumes:

```bash
./reset.sh
```

This will:
1. Stop the services
2. Remove containers (preserving volumes)
3. Restart the services with health checks
4. Recreate the demo user and project
5. Generate a new API token

## Docker Compose Configuration

The services are configured in docker-compose.yml with:
- NocoDB running on port 8080
- PostgreSQL for data persistence
- Redis for caching
- n8n running on port 5678
- Persistent volumes for all services
- Bridged network for service communication
- Health checks for database services

## Database Configuration

PostgreSQL is configured with:
- Database name: nocodb
- Username: postgres
- Password: configured via environment variable
- Health check: pg_isready
- Persistent volume for data

Redis is configured with:
- Password authentication enabled
- Persistent volume for data
- Health check: redis-cli ping

## Security Notes

- Default credentials should be changed in production
- API tokens should be kept secure
- PostgreSQL password should be changed in production
- Redis password should be changed in production
- All sensitive data is configured through environment variables
