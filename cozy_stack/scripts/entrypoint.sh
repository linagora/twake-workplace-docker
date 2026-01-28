#!/bin/sh
set -e

# --------------------------
# Entrypoint for patcher-cozy
# --------------------------

# Use the CONTAINER env variable from Docker Compose
CONTAINER="${CONTAINER:-cozyt}"   # fallback to 'cozyt' if not set
ADD_INSTANCES_SCRIPT="/scripts/patch-cozy.sh"
ADD_SHORTCUTS_SCRIPT="/scripts/add-shortcut.sh"

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
if [ -f "$ADD_INSTANCES_SCRIPT" ]; then
  echo "▶ Applying Cozy patch"
  ENABLE_APPS="${ENABLE_APPS}" sh /scripts/patch-cozy.sh

  echo "🎉 Cozy patch completed successfully"
else
  echo "❌ Patch script $ADD_INSTANCES_SCRIPT not found!"
  exit 1
fi

# Apply the shortcuts creation
if [ -f "$ADD_SHORTCUTS_SCRIPT" ]; then
  echo "▶ Applying Shortcut apps creation"
  ENABLE_APPS="${ENABLE_APPS}" sh /scripts/add-shortcut.sh

  echo "🎉 Shortcut apps creation completed successfully"
else
  echo "❌ Patch script $ADD_SHORTCUTS_SCRIPT not found!"
  exit 1
fi
