
#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-nginx-cicd-demo:local}"
CONTAINER_NAME="nginx-cicd-demo"
PORT="${PORT:-8080}"

echo "Building Docker image..."
docker build -t "$IMAGE" "$ROOT"

echo "Removing previous container..."
docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting container..."
docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  -p "$PORT:80" \
  "$IMAGE"

echo "Checking application..."
for i in {1..20}; do
  if curl --fail --silent "http://localhost:$PORT/health" >/dev/null; then
    echo "Deployment successful!"
    echo "Application: http://localhost:$PORT"
    exit 0
  fi
  sleep 1
done

echo "Health check failed!"
docker logs "$CONTAINER_NAME"
exit 1
