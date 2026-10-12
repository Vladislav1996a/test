#!/usr/bin/env bash
set -Eeuo pipefail

# Example: IMAGE=ghcr.io/owner/repo:abc123 PORT=8080 bash scripts/deploy.sh
: "${IMAGE:?Set IMAGE to a Docker image available in your registry}"
CONTAINER_NAME="${CONTAINER_NAME:-nginx-cicd-demo}"
PORT="${PORT:-8080}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "PORT must be an integer between 1 and 65535" >&2
  exit 1
fi

echo "Pulling $IMAGE"
docker pull "$IMAGE"

# Preserve existing container for rollback if it exists.
BACKUP="${CONTAINER_NAME}-backup"
if docker container inspect "$BACKUP" >/dev/null 2>&1; then
  docker rm -f "$BACKUP" >/dev/null
fi
if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
  docker rename "$CONTAINER_NAME" "$BACKUP"
  docker stop "$BACKUP" >/dev/null
fi

restore_previous() {
  echo "Deployment failed. Restoring previous container if available." >&2
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  if docker container inspect "$BACKUP" >/dev/null 2>&1; then
    docker rename "$BACKUP" "$CONTAINER_NAME"
    docker start "$CONTAINER_NAME" >/dev/null
  fi
}
trap restore_previous ERR

docker run -d --name "$CONTAINER_NAME" --restart unless-stopped \
  -p "${PORT}:80" "$IMAGE" >/dev/null

# Check actual published HTTP endpoint, not merely running container state.
ready=0
for attempt in $(seq 1 20); do
  if curl --fail --silent --max-time 2 "http://127.0.0.1:${PORT}/health" | grep -qx 'ok'; then
    ready=1
    break
  fi
  sleep 2
done
if (( ready == 0 )); then
  echo "Healthcheck failed for http://127.0.0.1:${PORT}/health" >&2
  false
fi
trap - ERR
if docker container inspect "$BACKUP" >/dev/null 2>&1; then
  docker rm "$BACKUP" >/dev/null
fi
echo "Deployed $IMAGE to http://localhost:${PORT}"
