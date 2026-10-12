#!/usr/bin/env bash
set -Eeuo pipefail
# Run locally for a complete build + deployment, without a registry.
# Example: PORT=8080 bash scripts/build-and-deploy.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IMAGE="${IMAGE:-nginx-cicd-demo:local}"
export IMAGE

docker build -t "$IMAGE" "$ROOT"
bash "$ROOT/scripts/deploy.sh"
