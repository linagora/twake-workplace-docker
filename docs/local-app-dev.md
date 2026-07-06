# Local cozy-web app development

Serve a locally-built cozy-web app (e.g. `cozy-contacts`) inside the real
HTTPS + SSO stack, with `yarn watch` rebuilds visible on reload.

## What boots

Only the cozy subset: `twake_db` (CouchDB) + `twake_auth` (Traefik HTTPS +
LemonLDAP-NG SSO) + `cozy_stack`. Not chat/mail/meet/etc.

## One-time host prerequisites

- `/etc/hosts` entries for `*.${BASE_DOMAIN}` (see the main README hosts block).
- Trust the Traefik root-CA (`twake_auth/.../root-ca.crt`) for green HTTPS.
- `docker network create twake-network --subnet=172.27.0.0/16`.

## Boot with your app

Set your app in `.env` (both keys are already declared there, empty by default):

```bash
# twake-workplace-docker/.env
COZY_DEV_APP_SLUG=contacts
COZY_DEV_APP_BUILD=/absolute/path/to/cozy-contacts/build
```

Load `.env` into your shell so `${BASE_DOMAIN}` and the dev vars resolve in every
command below, keep a watch build running so `build/` stays fresh, and bring up
the subset (`compose-wrapper.sh` also sources `.env`, so it picks up the dev
vars on its own):

```bash
cd twake-workplace-docker
set -a && . ./.env && set +a          # export BASE_DOMAIN + COZY_DEV_APP_*
( cd /absolute/path/to/cozy-contacts && yarn watch ) &   # cozy-scripts / rsbuild watch
cd cozy_stack && ./compose-wrapper.sh up -d --wait
```

## Provision a user + instance (SCIM, not `instances add`)

```bash
scripts/twake users add user1 --email user1@example.org \
  --given-name Test --family-name User
scripts/twake users list        # expect status `ok`
```

Install your local app into that instance (idempotent; live in `--dev`):

```bash
cozy_stack/scripts/install-dev-app.sh --slug contacts --domain user1.${BASE_DOMAIN}
```

Browse it at `https://user1-contacts.${BASE_DOMAIN}` and log in via SSO.

## Seed data (ACH, reuse the app's fixtures)

```bash
TOKEN=$(docker exec cozyt cozy-stack instances token-cli user1.${BASE_DOMAIN} io.cozy.contacts)
ACH import /path/to/cozy-contacts/fixtures/contacts.json \
  -u https://user1.${BASE_DOMAIN} -t "$TOKEN"
```

## Teardown

```bash
scripts/twake users destroy user1 --yes
cd cozy_stack && ./compose-wrapper.sh down -v
```
