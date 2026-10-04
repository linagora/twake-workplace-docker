#!/bin/sh
# Makes the tom-bridge bot (@twp_bot) a Synapse admin, so that it can update
# the profiles through the admin API. Idempotent; runs in the Synapse image
# before the bridge starts.
set -e

until python -c 'import urllib.request; urllib.request.urlopen("http://synapse:8008/health")' 2>/dev/null; do
  echo "Waiting for Synapse..."
  sleep 2
done

# Synapse reserves the application service sender, so the bot is registered
# through the application service API with its as_token, then promoted in the
# database (as in the ToM-Bridge development environment).
python - <<'PY'
import json, os, urllib.error, urllib.request
import psycopg2

registration = open("/config/tom-bridge-registration.yaml").read().splitlines()
fields = {k.strip(): v.strip().strip('"') for k, _, v in (l.partition(":") for l in registration) if v}
localpart, token = fields["sender_localpart"], fields["as_token"]

request = urllib.request.Request(
    "http://synapse:8008/_matrix/client/v3/register",
    data=json.dumps({"username": localpart, "type": "m.login.application_service"}).encode(),
    headers={"Authorization": "Bearer " + token, "Content-Type": "application/json"},
)
try:
    urllib.request.urlopen(request)
    print("registered @%s" % localpart)
except urllib.error.HTTPError as e:
    body = json.loads(e.read() or b"{}")
    if body.get("errcode") != "M_USER_IN_USE":
        raise
    print("@%s already registered" % localpart)

user_id = "@%s:%s" % (localpart, os.environ["BASE_DOMAIN"])
conn = psycopg2.connect(host="postgres", dbname="synapse", user="synapse", password="synapse!1")
with conn, conn.cursor() as cur:
    cur.execute("UPDATE users SET admin = 1 WHERE name = %s", (user_id,))
    if cur.rowcount != 1:
        raise SystemExit("%s not found in the Synapse database" % user_id)
print("%s is a Synapse admin" % user_id)
PY
