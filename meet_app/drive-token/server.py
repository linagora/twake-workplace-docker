"""Stands in for the Cloudery route Meet calls to write into a user's Drive.

POST /api/public/instances/<fqdn>/drive_token returns {"token": <jwt>}, a cli
token scoped to io.cozy.files minted by the cozy-stack admin API.
"""

import base64
import hmac
import json
import os
import re
import urllib.error
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STACK_ADMIN_URL = os.environ["COZY_ADMIN_URL"].rstrip("/")
ADMIN_AUTH = "Basic " + base64.b64encode(
    f":{os.environ['COZY_ADMIN_PASSPHRASE']}".encode()
).decode()
TOKEN = os.environ["DRIVE_TOKEN_SECRET"]
INSTANCE_SUFFIX = "." + os.environ["BASE_DOMAIN"]
ROUTE = re.compile(r"^/api/public/instances/([a-z0-9.-]+)/drive_token$")


class Handler(BaseHTTPRequestHandler):
    def do_POST(self):
        match = ROUTE.match(self.path)
        if not match:
            return self.reply(404, {"error": "not found"})
        if not hmac.compare_digest(
            self.headers.get("Authorization", "").encode(), f"Bearer {TOKEN}".encode()
        ):
            return self.reply(401, {"error": "unauthorized"})
        fqdn = match.group(1)
        # The admin API mints tokens for any instance of the stack: only the
        # Workplace users' instances are reachable through here.
        if not fqdn.endswith(INSTANCE_SUFFIX):
            return self.reply(403, {"error": "instance outside BASE_DOMAIN"})

        query = urllib.parse.urlencode(
            {
                "Domain": fqdn,
                "Audience": "cli",
                "Scope": "io.cozy.files",
                "Subject": "drive",
            }
        )
        request = urllib.request.Request(
            f"{STACK_ADMIN_URL}/instances/token?{query}",
            method="POST",
            headers={"Authorization": ADMIN_AUTH},
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as resp:
                token = resp.read().decode().strip()
        except urllib.error.HTTPError as err:
            return self.reply(err.code, {"error": err.read().decode()[:500]})
        except urllib.error.URLError as err:
            return self.reply(502, {"error": str(err.reason)})
        self.reply(200, {"token": token})

    def reply(self, status, body):
        payload = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


ThreadingHTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
