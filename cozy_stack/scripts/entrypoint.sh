#!/bin/sh
set -e

# --------------------------
# Entrypoint for patcher-cozy
# --------------------------

# Use the CONTAINER env variable from Docker Compose
CONTAINER="${CONTAINER:-cozyt}"   # fallback to 'cozyt' if not set
PATCH_SCRIPT="/scripts/patch-cozy.sh"

echo "▶ Waiting for Docker API..."
until docker ps >/dev/null 2>&1; do
  sleep 2
done
echo "✔ Docker API reachable"

# Wait for container to be running
echo "▶ Waiting for container $CONTAINER..."
until docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null | grep -q true; do
  sleep 2
done
echo "✔ $CONTAINER is running"

# Wait for cozy-stack HTTP server to be ready
echo "▶ Waiting for Cozy HTTP server to be ready..."
until docker exec "$CONTAINER" cozy-stack status 2>/dev/null | grep -q "OK, the HTTP server is ready"; do
  sleep 3
done
echo "✔ Cozy HTTP server is ready"

# Apply the patch
if [ -f "$PATCH_SCRIPT" ]; then
  echo "▶ Applying Cozy patch"
  sh /scripts/patch-cozy.sh

  echo "🎉 Cozy patch completed successfully"
else
  echo "❌ Patch script $PATCH_SCRIPT not found!"
  exit 1
fi
