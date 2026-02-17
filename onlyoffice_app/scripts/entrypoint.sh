#!/bin/sh
set -e

echo "▶ Waiting for Docker socket proxy..."
until docker ps >/dev/null 2>&1; do
  sleep 2
done
echo "✔ Docker API reachable"

wait_for_container() {
  name="$1"
  echo "▶ Waiting for container $name..."
  until docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null | grep -q true; do
    sleep 2
  done
  echo "✔ $name is running"
}

wait_for_container onlyoffice-documentserver

echo "▶ Applying OnlyOffice patch"
sh /scripts/patch-onlyoffice.sh

echo "🎉 Patching completed successfully"