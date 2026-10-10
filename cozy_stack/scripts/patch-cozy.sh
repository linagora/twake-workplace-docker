#!/bin/sh
set -e

# Use environment variable or fallback
CONTAINER="${CONTAINER:-cozyt}"

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
COZY_STACK="/usr/local/bin/cozy-stack"

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
EXISTING_INSTANCES=\$(\$COZY_STACK instances ls | awk '{print \$1}')

create_instance() {
  DOMAIN="\$1"
  EMAIL="\$2"
  PUBLIC_NAME="\$3"
  if echo "\$EXISTING_INSTANCES" | grep -qx "\$DOMAIN"; then
    echo "✔ Instance \$DOMAIN already exists"
    # Also repairs the instances created with a quoted email and no public
    # name, which common-settings rejects.
    cozy-stack instances modify \
      --email "\$EMAIL" \
      --public-name "\$PUBLIC_NAME" \
      "\$DOMAIN"
  else
    echo "➕ Creating instance \$DOMAIN"
    cozy-stack instances add \
      --apps home,drive,notes,settings,dataproxy \
      --email "\$EMAIL" \
      --public-name "\$PUBLIC_NAME" \
      --context-name default \
      "\$DOMAIN"
  fi
}

# apps install fails when the app is already there, which made a second run of
# the patcher exit on "Application with same slug already exists".
install_app() {
  SLUG="\$1"
  APP_DOMAIN="\$2"
  if cozy-stack apps show "\$SLUG" --domain "\$APP_DOMAIN" >/dev/null 2>&1; then
    echo "✔ \$SLUG already installed on \$APP_DOMAIN"
  else
    cozy-stack apps install "\$SLUG" --domain "\$APP_DOMAIN"
  fi
}

# Same users and names as twake_db/ldap/bootstrap/users.ldif.template
create_instance "user1.$BASE_DOMAIN" "user1@$BASE_DOMAIN" "User One"
create_instance "user2.$BASE_DOMAIN" "user2@$BASE_DOMAIN" "User Two"
create_instance "user3.$BASE_DOMAIN" "user3@$BASE_DOMAIN" "User Three"



echo "▶ Adding optional apps and Applying feature flags..."
for DOMAIN in user1.$BASE_DOMAIN user2.$BASE_DOMAIN user3.$BASE_DOMAIN; do
  if echo ",\$ENABLED_APPS," | grep -q ",linshare,"; then
    echo "▶ Installing linshare app for \$DOMAIN"
    install_app linshare "\$DOMAIN"
    cozy-stack feature flags --domain "\$DOMAIN" \
      '{"linshare.embedded-app-url": "https://linshare.$BASE_DOMAIN/new/"}'
  fi

  if echo ",\$ENABLED_APPS," | grep -q ",mail,"; then
    echo "▶ Installing mail app for \$DOMAIN"
    install_app mail "\$DOMAIN"
    cozy-stack feature flags --domain "\$DOMAIN" \\
      '{"mail.embedded-app-url": "${COZY_MAIL_APP_URL:-https://mail.$BASE_DOMAIN}"}'
  fi  
  
  if echo ",\$ENABLED_APPS," | grep -q ",chat,"; then
    echo "▶ Installing chat app for \$DOMAIN"
    install_app chat "\$DOMAIN"
    cozy-stack feature flags --domain "\$DOMAIN" \
      '{"chat.embedded-app-url": "https://chat.$BASE_DOMAIN"}'
  fi

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"home.add-tile.add-shortcut": "true"}'

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"home.apps.only-one-list": "true"}'

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"apps.hidden": ["dataproxy", "settings"]}'
  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"cozy.hide-sharing-cozy-to-cozy": "true"}'

  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"cozy.search.enabled": "true"}' 
  
  cozy-stack feature flags --domain "\$DOMAIN" \
    '{"cozy.searchbar.enabled": "true"}'    
done

for USERID in user1 user2 user3; do
  cozy-stack instances modify "\$USERID.$BASE_DOMAIN" --oidc_id "\$USERID"
done
echo "▶ Applying global feature defaults..."
cozy-stack features defaults \
  '{"drive.office": {"enabled": true, "write": true}}'

cozy-stack features defaults \
  '{"home.wallpaper-personalization": {"enabled": true}}'   

# echo "▶ Creating shortcuts..."
# for DOMAIN in user1.$BASE_DOMAIN user2.$BASE_DOMAIN user3.$BASE_DOMAIN; do
#   /usr/local/bin/create-shortcut.sh \
#     "\$DOMAIN" \
#     /usr/local/bin/example-shortcut.json \
#     http://localhost:6060 \
#     "https://\$DOMAIN"
# done

echo "✅ Cozy patch completed"
EOF

