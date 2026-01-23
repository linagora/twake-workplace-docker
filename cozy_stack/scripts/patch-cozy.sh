#!/bin/sh
set -e

# Use environment variable or fallback
CONTAINER="${CONTAINER:-cozyt}"

# List of users as plain space-separated string
USERS="user1:user1@twake.local user2:user2@twake.local user3:user3@twake.local"

LINSHARE_URL="https://linshare.twake.local/new"

echo "▶ Checking Cozy container..."
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "❌ Container $CONTAINER is not running"
  exit 1
fi

echo "▶ Running Cozy patch inside container..."

docker exec -i "$CONTAINER" sh <<'EOF'
set -e

echo "▶ Fetching existing instances..."
EXISTING_INSTANCES=$(cozy-stack instances ls | awk '{print $1}')

create_instance() {
  DOMAIN="$1"
  EMAIL="$2"

  if echo "$EXISTING_INSTANCES" | grep -qx "$DOMAIN"; then
    echo "✔ Instance $DOMAIN already exists"
  else
    echo "➕ Creating instance $DOMAIN"
    cozy-stack instances add \
      --apps home,linshare,drive,mail,settings \
      --email "$EMAIL" \
      --context-name default \
      "$DOMAIN"
  fi
}

# Loop over users using plain sh
for user in user1:user1@twake.local user2:user2@twake.local user3:user3@twake.local; do
  DOMAIN=$(echo "$user" | cut -d: -f1).twake.local
  EMAIL=$(echo "$user" | cut -d: -f2)
  create_instance "$DOMAIN" "$EMAIL"
done

echo "▶ Applying feature flags..."
for DOMAIN in user1.twake.local user2.twake.local user3.twake.local; do
  cozy-stack feature flags --domain "$DOMAIN" \
    '{"linshare.embedded-app-url": "https://linshare.twake.local/new/"}'

  cozy-stack feature flags --domain "$DOMAIN" \
    '{"mail.embedded-app-url": "https://mail.twake.local/"}'

  cozy-stack feature flags --domain "$DOMAIN" \
    '{"home.add-tile.add-shortcut": "true"}'

  cozy-stack feature flags --domain "$DOMAIN" \
    '{"home.apps.only-one-list": "true"}'
done

echo "▶ Applying global feature defaults..."
cozy-stack features defaults \
  '{"drive.office": {"enabled": true, "write": true}}'

echo "▶ Creating shortcuts..."
for DOMAIN in user1.twake.local user2.twake.local user3.twake.local; do
  /usr/local/bin/create-shortcut.sh \
    "$DOMAIN" \
    /usr/local/bin/example-shortcut.json \
    http://localhost:6060 \
    "https://$DOMAIN"
done

echo "✅ Cozy patch completed"
EOF
