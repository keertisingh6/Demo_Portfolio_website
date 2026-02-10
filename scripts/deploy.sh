#!/bin/bash
# Run on EC2 (from the directory that contains docker-compose.yml).
# Pulls latest image, restarts the app. Set image name in docker-compose.yml.

set -e

echo "🔹 Pulling latest Docker image"
docker compose pull

echo "🔹 Stopping old containers (if any)"
docker compose down || true

echo "🔹 Starting application"
docker compose up -d

echo "✅ Application deployed"
docker compose ps