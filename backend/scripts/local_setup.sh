#!/bin/bash
# Local development environment setup
set -euo pipefail

echo "=== Setting up Geeky backend local development ==="

# Check prerequisites
command -v python3 >/dev/null 2>&1 || { echo "Python 3.12+ required"; exit 1; }
command -v docker >/dev/null 2>&1 || { echo "Docker required"; exit 1; }
command -v docker-compose >/dev/null 2>&1 || command -v docker compose >/dev/null 2>&1 || { echo "Docker Compose required"; exit 1; }

# Create .env from example if not exists
if [ ! -f .env ]; then
    cp .env.example .env
    echo "Created .env from .env.example — please edit with your API keys"
fi

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements-dev.txt

# Download spaCy model
python -m spacy download en_core_web_sm

echo ""
echo "=== Setup complete ==="
echo ""
echo "To start development:"
echo "  1. Edit .env with your API keys"
echo "  2. docker-compose up -d  (starts ChromaDB + Redis)"
echo "  3. source .venv/bin/activate"
echo "  4. uvicorn app.main:app --reload"
echo ""
echo "Or run everything in Docker:"
echo "  docker-compose up"
