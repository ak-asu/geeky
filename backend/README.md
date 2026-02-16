# Geeky Backend

FastAPI backend for the Geeky educational platform.

## Quick Start

### Prerequisites
- Python 3.12+
- Docker & Docker Compose

### Local Development

```bash
# 1. Setup environment
./scripts/local_setup.sh

# 2. Edit .env with your API keys
cp .env.example .env

# 3. Start all services
docker-compose up

# 4. Open Swagger UI
# http://localhost:8000/docs
```

### Running Tests

```bash
pytest tests/ -v
```

### Project Structure

```
app/
  api/          # REST API routes (thin layer)
  models/       # Pydantic schemas
  services/     # Business logic (Protocol-based)
  repositories/ # Data access (Firestore)
  integrations/ # External service clients
  workers/      # Celery tasks
```

### Architecture

Every external dependency is behind a Python `Protocol` interface.
To swap a technology, change ONE function in `app/dependencies.py`.

See `plan.md` for implementation progress and `../CLAUDE.md` for code rules.
