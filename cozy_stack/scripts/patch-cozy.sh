#!/bin/sh
set -e

# Use environment variable or fallback
CONTAINER="${CONTAINER:-cozyt}"

# List of users as plain space-separated string
USERS="user1:user1@twake.local user2:user2@twake.local user3:user3@twake.local"

ENABLE_APPS="${ENABLE_APPS:-}"
ENABLE_APPS=$(echo "$ENABLE_APPS" | sed 's/"//g')
echo "▶ Enabled apps: $ENABLE_APPS"
echo "▶ Checking Cozy container..."
if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  echo "❌ Container $CONTAINER is not running"
  exit 1
fi

echo "▶ Running Cozy patch inside container..."

docker exec -i -e ENABLED_APPS="$ENABLE_APPS" "$CONTAINER" sh <<EOF
set -e

# Use full path to cozy-stack
COZY_STACK="/usr/bin/cozy-stack"

# Base apps that are always installed
BASE_APPS="home,drive,settings"

if [ -n "\$ENABLED_APPS" ]; then
  # Combine base apps with enabled apps
  APPS_LIST="\$BASE_APPS,\$ENABLED_APPS"
else
  # Only base apps
  APPS_LIST="\$BASE_APPS"
fi

echo "▶ Apps to install: \$APPS_LIST"

echo "▶ Fetching existing instances..."
EXISTING_INSTANCES=\$(\$COZY_STACKs instances ls | awk '{print \$1}')

create_instance() {
  DOMAIN="\$1"
  EMAIL="\$2"
  APPS_LIST="\$3"
  if echo "\$EXISTING_INSTANCES" | grep -qx "\$DOMAIN"; then
    echo "✔ Instance \$DOMAIN already exists"
  else
    echo "➕ Creating instance \$DOMAIN"
    cozy-stack instances add \
      --apps \"\$APPS_LIST\" \
      --email \"\$EMAIL\" \
      --context-name default \
      "\$DOMAIN"
  fi
}

# Loop over users using plain sh
for user in $USERS; do
  DOMAIN=\$(echo "\$user" | cut -d: -f1).twake.local
  EMAIL=\$(echo "\$user" | cut -d: -f2)
  create_instance "\$DOMAIN" "\$EMAIL" "\$APPS_LIST"
done

echo "▶ Applying feature flags..."
for DOMAIN in user1.twake.local user2.twake.local user3.twake.local; do
  if echo ",\$ENABLED_APPS," | grep -q ",linshare,"; then
    cozy-stack feature flags --domain "\$DOMAIN" \
      '{"linshare.embedded-app-url": "https://linshare.twake.local/new/"}'
  fi
  #cozy-stack feature flags --domain "\$DOMAIN" \
    #'{"linshare.embedded-app-url": "https://linshare.twake.local/new/"}'


  if echo ",\$ENABLED_APPS," | grep -q ",mail,"; then
    cozy-stack feature flags --domain "\$DOMAIN" \\
      '{"mail.embedded-app-url": "https://mail.twake.local"}'
  fi  

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"home.add-tile.add-shortcut": "true"}'

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"home.apps.only-one-list": "true"}'
done

echo "▶ Applying global feature defaults..."
cozy-stack features defaults \
  '{"drive.office": {"enabled": true, "write": true}}'

# echo "▶ Creating shortcuts..."
# for DOMAIN in user1.twake.local user2.twake.local user3.twake.local; do
#   /usr/local/bin/create-shortcut.sh \
#     "\$DOMAIN" \
#     /usr/local/bin/example-shortcut.json \
#     http://localhost:6060 \
#     "https://\$DOMAIN"
# done

echo "✅ Cozy patch completed"
EOF

