#!/bin/bash
set -e

CONTAINER="cozyt"

USERS=(
  "user1:user1@twake.local"
  "user2:user2@twake.local"
  "user3:user3@twake.local"
)


echo "▶ Checking Cozy container..."
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "❌ Container $CONTAINER is not running"
  exit 1
fi

echo "▶ Running Cozy patch inside container..."

docker exec -i "$CONTAINER" bash <<'EOF'
set -e

create_instance() {
  DOMAIN="$1"

 
    echo "➕ Add Linshare for instance $DOMAIN"
    cozy-stack apps install linshare --domain "$DOMAIN"    
 
}

# Create instances
create_instance user1.twake.local 
create_instance user2.twake.local 
create_instance user3.twake.local 

echo "▶ Applying feature flags..."

for DOMAIN in user1.twake.local user2.twake.local user3.twake.local; do
  cozy-stack feature flags --domain "$DOMAIN" \
    '{"linshare.embedded-app-url": "https://linshare.twake.local/new/"}'
done



echo "✅ Cozy patch completed"
EOF
