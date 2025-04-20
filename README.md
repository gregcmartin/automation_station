# :robot: Automation Station :robot:
This is a set of scripts for Docker that automatically sets up n8n and NocoDB with PostgreSQL and Redis backends. The setup works natively on OSX or Ubuntu and provides installation, uninstallation, and reset capabilities.

## Features

- Automatic installation of latest versions from GitHub:
  - n8n (workflow automation)
  - NocoDB (open source airtable replacement)
  - PostgreSQL 15 (database backend)
  - Redis 7 (caching layer)
- Optional Skyvern integration for browser automation
- Optional Firecrawl integration for web crawling and scraping
- Optional Crawl4AI integration for advanced web crawling with n8n integration
- Optional Browser Use integration for containerized browser automation
- Optional ChromaDB integration for vector database and similarity search
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
- Git (for Skyvern integration)

## System Architecture

The setup includes:
- NocoDB with PostgreSQL backend for data persistence
- Redis for caching and improved performance
- n8n configured with PostgreSQL backend for workflow storage
- Optional Skyvern service for browser automation
- Optional Crawl4AI service for web crawling
- Optional Browser Use service for containerized browser automation
- Optional ChromaDB service for vector database operations
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

### Optional: Skyvern Integration

To add Skyvern browser automation capabilities:

```bash
./setup-skyvern.sh
```

This will:
1. Clone the Skyvern repository
2. Set up Skyvern with MCP server enabled
3. Configure integration with n8n and NocoDB
4. Add browser automation capabilities to your workflows

The Skyvern MCP server will be accessible at http://localhost:3000 and can be used directly in n8n workflows.

### Optional: Firecrawl Integration

To add Firecrawl web crawling capabilities:

```bash
./setup-firecrawl.sh
```

This will:
1. Clone the Firecrawl repository
2. Set up Firecrawl with Docker configuration
3. Configure integration with the existing network
4. Add web crawling and scraping capabilities to your setup

The Firecrawl service will be accessible at http://localhost:3001.

### Optional: ChromaDB Integration

To add ChromaDB vector database capabilities:

```bash
./setup-chromadb.sh
```

This will:
1. Set up ChromaDB with Docker configuration
2. Configure direct integration with n8n
3. Add vector database and similarity search to your n8n workflows
4. Set up persistent storage for embeddings

The ChromaDB service will be accessible at http://localhost:3004.

### Optional: Browser Use Integration

To add Browser Use automation capabilities:

```bash
./setup-browser-use.sh
```

This will:
1. Set up Browser Use with Docker configuration
2. Configure direct integration with n8n
3. Add containerized browser automation to your n8n workflows
4. Set up secure browser environment with proper permissions

The Browser Use service will be accessible at http://localhost:3003.

### Optional: Crawl4AI Integration

To add Crawl4AI web crawling capabilities:

```bash
./setup-crawl4ai.sh
```

This will:
1. Set up Crawl4AI with Docker configuration
2. Configure direct integration with n8n
3. Add advanced web crawling capabilities to your n8n workflows

The Crawl4AI service will be accessible at http://localhost:3002.

## Updating Services

To update all services to their latest versions:

```bash
./update.sh
```

This will:
1. Pull the latest Docker images for n8n, NocoDB, PostgreSQL, and Redis
2. Update Skyvern if installed (via git pull)
3. Restart all services with the new versions
4. Display current versions of core services
5. Verify all services are running properly

## Accessing the Services

After installation:
- NocoDB: http://localhost:8080 (uses core credentials)
- n8n: http://localhost:5678 (uses core credentials)
- Skyvern MCP (if installed): http://localhost:3000 (uses core credentials)
- Firecrawl (if installed): http://localhost:3001 (no authentication required)
- Crawl4AI (if installed): http://localhost:3002 (uses n8n API key)
- Browser Use (if installed): http://localhost:3003 (uses n8n API key)
- ChromaDB (if installed): http://localhost:3004 (default: admin:admin)

Default credentials:
Core services (NocoDB, n8n, Skyvern):
- Username: demouser
- Password: DemoUser132!

Optional services:
- ChromaDB: admin:admin (change in production)
- Crawl4AI & Browser Use: use n8n API key from api_keys.txt
- Firecrawl: no authentication required

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
- Skyvern (optional) running on port 3000
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

## Skyvern Configuration

When enabled, Skyvern is configured with:
- MCP server running on port 3000
- Integration with n8n workflows
- Shared credentials with n8n and NocoDB
- Browser automation capabilities
- Persistent volume for automation data

## Firecrawl Configuration

When enabled, Firecrawl is configured with:
- Web crawler running on port 3001
- Integration with Docker network
- Persistent volume for crawled data
- Production-ready configuration

## Security Notes

- Default credentials should be changed in production
- API tokens should be kept secure
- PostgreSQL password should be changed in production
- Redis password should be changed in production
- All sensitive data is configured through environment variables
- Skyvern MCP server should be properly secured in production

## ChromaDB Configuration

When enabled, ChromaDB is configured with:
- Vector database running on port 3004
- Direct integration with n8n workflows
- DuckDB + Parquet storage backend
- REST API implementation
- Basic authentication enabled
- Persistent volume for embeddings data
- Health checks enabled
- Production-ready configuration
- Default credentials (admin:admin) should be changed in production

## Browser Use Configuration

When enabled, Browser Use is configured with:
- Browser automation service running on port 3003
- Direct integration with n8n workflows
- Secure containerized Chrome/Chromium environment
- Shared memory configuration for stability
- System permissions for browser operations
- Health checks enabled
- Persistent volume for automation data
- Production-ready configuration

## Crawl4AI Configuration

When enabled, Crawl4AI is configured with:
- Web crawler running on port 3002
- Direct integration with n8n workflows
- Persistent volume for crawled data
- Health checks enabled
- Production-ready configuration
