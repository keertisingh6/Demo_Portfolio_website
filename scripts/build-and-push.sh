#!/usr/bin/env bash
# Build the deployment-demo Docker image for amd64 + arm64 and push to Docker Hub.
# Uses buildx so the same image tag works on x86 and ARM (e.g. Graviton, Apple Silicon).
# Usage: ./scripts/build-and-push.sh [DOCKER_HUB_USERNAME]
#   or:  DOCKER_USER=myusername ./scripts/build-and-push.sh
# If push seems stuck (slow network): try one platform first, e.g. PLATFORMS=linux/arm64 ./scripts/build-and-push.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
IMAGE_NAME="deployment-demo"
TAG="${TAG:-latest}"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm64}"

# Docker Hub username: from argument, env, or extract from docker-compose.yml
DOCKER_USER="${1:-$DOCKER_USER}"
if [ -z "$DOCKER_USER" ]; then
  DOCKER_USER=$(grep -E '^\s+image:\s+' "$PROJECT_DIR/docker-compose.yml" 2>/dev/null | sed -E 's/.*image:[[:space:]]+([^\/]+)\/.*/\1/' | head -1)
fi
if [ -z "$DOCKER_USER" ]; then
  echo "Error: Docker Hub username required."
  echo "Usage: $0 DOCKER_HUB_USERNAME"
  echo "   or: DOCKER_USER=myusername $0"
  exit 1
fi

FULL_IMAGE="${DOCKER_USER}/${IMAGE_NAME}:${TAG}"

echo "=============================================="
echo "  Build & Push to Docker Hub (multi-platform)"
echo "=============================================="
echo "  Image:     $FULL_IMAGE"
echo "  Platforms: $PLATFORMS"
echo "  Dir:       $PROJECT_DIR"
echo "=============================================="
echo ""

echo "[1/3] Setting up buildx..."
if ! docker buildx version >/dev/null 2>&1; then
  echo "Error: docker buildx is required. Install Docker Buildx or use Docker Desktop."
  exit 1
fi
# Multi-platform push requires the docker-container driver (default driver doesn't support it)
BUILDER_NAME="deployment-demo-builder"
if ! docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  echo "  Creating multi-platform builder '$BUILDER_NAME' (one-time)..."
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
fi
docker buildx use "$BUILDER_NAME" 2>/dev/null || true

echo ""
echo "[2/3] Building and pushing ($PLATFORMS)..."
echo "      (Pushing layers to Docker Hub can take 2-5 min — please wait, do not cancel)"
echo ""
docker buildx build \
  --progress=plain \
  --platform "$PLATFORMS" \
  --tag "$FULL_IMAGE" \
  --file "$PROJECT_DIR/Dockerfile" \
  --push \
  "$PROJECT_DIR"

echo ""
echo "[3/3] Verifying manifest (multi-platform)..."
docker buildx imagetools inspect "$FULL_IMAGE" 2>/dev/null || echo "  Pushed. Server will pull the correct arch (amd64 or arm64)."

echo ""
echo "=============================================="
echo "  Done."
echo "  Run on server: docker pull $FULL_IMAGE"
echo "  Then:          docker compose up -d"
echo "=============================================="