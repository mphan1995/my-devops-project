#!/usr/bin/env bash
set -euo pipefail

REGISTRY="${REGISTRY:-localhost:5000}"
IMAGE="${IMAGE:-myapp}"
TAG="${TAG:-latest}"

echo "Deploying $REGISTRY/$IMAGE:$TAG to staging..."

docker pull "$REGISTRY/$IMAGE:$TAG"
docker stop "$IMAGE" || true
docker rm "$IMAGE" || true
docker run -d --name "$IMAGE" -p 8080:8080 "$REGISTRY/$IMAGE:$TAG"
