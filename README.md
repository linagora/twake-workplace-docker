# Twake.AI Kickstart

[Twake.ai](https://twake.ai) is an open-source digital workplace from [LINAGORA](https://linagora.com) that unifies messaging, mail, file sharing, document editing, calendar, video conferencing, and a personal cloud behind a single sign-on.

**Twake.AI Kickstart** is the Docker Compose stack that deploys a complete Twake.ai instance on a laptop or a server — for developers exploring the platform, sysadmins evaluating it, or anyone wanting a hands-on run in minutes.

## What you get

Once the stack is up, end users have access to:

- **Chat** — real-time messaging with file and image share
- **Mail** — JMAP mailbox with a web client
- **Drive** — secure file sharing and storage
- **Docs** — collaborative document editing
- **Calendar** — shared calendaring
- **Meet** — WebRTC video conferencing

Authentication and routing are handled transparently behind a single sign-on portal.

## What runs under the hood

The stack is split into nine Docker Compose projects grouped by layer:

- **Data layer (`twake_db`)** — PostgreSQL, MongoDB, CouchDB, OpenLDAP, Valkey/Redis, RabbitMQ
- **Auth & proxy (`twake_auth`)** — Traefik (reverse proxy + SSL), LemonLDAP-NG (SSO and OIDC provider), Docker socket proxy
- **Apps** — `chat_app` (Matrix Synapse + Tom server), `tmail_app` (JMAP mail), `linshare_app` (file sharing + admin UIs + ClamAV), `onlyoffice_app` (document editing), `calendar_app` (shared calendar), `meet_app` (LiveKit + Django backend + frontend), `cozy_stack` (personal cloud platform)

Each project has its own `docker-compose.yml` and a `compose-wrapper.sh` that re-renders configuration files from the root `.env` on every start, so no domain value is hardcoded.

## Prerequisites

- Docker and Docker Compose v2+
- ~8 GB RAM available to Docker
- ~20 GB free disk space (roughly 30 container images)
- Ports 80 and 443 free on the host
- `jq` and `envsubst` on the host (the wrappers fail fast with an install hint if missing — on Debian/Ubuntu: `sudo apt-get install -y jq gettext-base`)

For production hardening (UFW forward policy, `ip_forward`, NAT hairpin, container egress) see [`docs/operations.md`](docs/operations.md).

## Run

The stack runs identically in two configurations: locally for evaluation, or on a public domain for shared deployment.

### Locally (default, `twake.local`)

1.  **Create the shared Docker network:**

    ```bash
    docker network create twake-network --subnet=172.27.0.0/16
    ```

2.  **Add the `/etc/hosts` entries:**

    <details>
    <summary>Click to expand the host entries</summary>

    ```
    127.0.0.1  linshare.twake.local admin-linshare.twake.local upload-request-linshare.twake.local meet.twake.local onlyoffice.twake.local calendar.twake.local contacts.twake.local account.twake.local excal.twake.local mail.twake.local jmap.twake.local
    127.0.0.1  oauthcallback.twake.local manager.twake.local auth.twake.local ldap-rest.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local
    127.0.0.1  user1.twake.local user1-home.twake.local user1-linshare.twake.local user1-drive.twake.local user1-settings.twake.local user1-mail.twake.local user1-chat.twake.local user1-notes.twake.local user1-dataproxy.twake.local
    127.0.0.1  user2.twake.local user2-home.twake.local user2-linshare.twake.local user2-drive.twake.local user2-settings.twake.local user2-mail.twake.local user2-chat.twake.local user2-notes.twake.local user2-dataproxy.twake.local
    127.0.0.1  user3.twake.local user3-home.twake.local user3-linshare.twake.local user3-drive.twake.local user3-settings.twake.local user3-mail.twake.local user3-chat.twake.local user3-notes.twake.local user3-dataproxy.twake.local
    127.0.0.1  chat.twake.local matrix.twake.local tom.twake.local fed.twake.local traefik.twake.local calendar-ng.twake.local
    ```

    </details>

3.  **Trust the self-signed CA** at [`twake_auth/traefik/ssl/root-ca.pem`](twake_auth/traefik/ssl/root-ca.pem) in your OS *and* browser trust stores. Trusting it in the browser alone is not enough — some iframes fail otherwise.

4.  **Start the stack:**

    ```bash
    ./wrapper.sh up -d
    ```

    Wait a few minutes; `docker ps` should eventually show every container in a `healthy` state. Run `./wrapper.sh --help` for other operations (`down`, scoped `up`, …).

    To start only some apps instead of the whole stack, pass app flags. For example `./wrapper.sh up -d --mail --chat` brings up just mail and chat, automatically pulling in the shared database and auth they depend on.

    | Flag | App |
    | --- | --- |
    | `--mail` | Mail |
    | `--chat` | Chat |
    | `--drive` | Drive |
    | `--meet` | Meet |
    | `--calendar` | Calendar |
    | `--office` | OnlyOffice documents |
    | `--full` | Everything |

    On `down`, an app flag stops only that app and leaves the shared services running for whatever else is up.

5.  **Open** `https://user1.twake.local` and log in with the demo credentials (see *Login & next steps*).

### On a public domain (`mydomain.fr`)

1.  **Create a wildcard DNS record:** `*.mydomain.fr` `A` → host's public IP. Make sure TCP port 443 is reachable from the Internet (firewall, security group, NAT).

2.  **Update `.env`:**

    ```env
    BASE_DOMAIN=mydomain.fr
    LDAP_BASE_DN=dc=mydomain,dc=fr
    MAIL_DOMAIN=mydomain.fr
    CERT_MODE=letsencrypt
    ```

3.  **Obtain a wildcard certificate via DNS-01.** HTTP-01 cannot issue wildcards. Install the certbot plugin for your DNS provider (`python3-certbot-dns-cloudflare`, `python3-certbot-dns-ovh`, `python3-certbot-dns-route53`, …) and run:

    ```bash
    sudo certbot certonly --manual \
      -d "*.mydomain.fr" \
      -d "mydomain.fr"
    ```

    See the [certbot DNS plugins documentation](https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins) for provider-specific setup. Alternatively, [acme.sh](https://github.com/acmesh-official/acme.sh) works with any supported DNS API. Certbot stores the certificates at `/etc/letsencrypt/live/mydomain.fr/`.

4.  **Start the stack:**

    ```bash
    ./wrapper.sh up -d
    ```

    `twake_auth/compose-wrapper.sh` detects `CERT_MODE=letsencrypt`, copies the Let's Encrypt certificates from `/etc/letsencrypt/live/mydomain.fr/` into `twake_auth/traefik/ssl/`, and restarts the reverse proxy. No manual file copying is needed. Your browser already trusts Let's Encrypt.

5.  **Set up renewal.** Certbot installs a systemd timer that auto-renews certificates before they expire. After each renewal, re-copy them into Traefik with a post-renewal hook at `/etc/letsencrypt/renewal-hooks/post/restart-traefik.sh`:

    ```bash
    #!/bin/bash
    cd /path/to/twake-workplace-docker/twake_auth && ./compose-wrapper.sh up -d
    ```

6.  **Enable video calls.** Audio and video (meet) need LiveKit to advertise the host's public IP to browsers. Add `LIVEKIT_USE_EXTERNAL_IP=true` to `.env` and open `7880/tcp` plus `7881/tcp+udp` in the firewall. Left at the default (`false`), a call connects to signaling but stays silent on a public host. See [`docs/operations.md`](docs/operations.md#video-calls-livekit-media) for the reasoning and the NAT fallback.

## External SSO (optional)

Authentication ships preconfigured against the bundled LDAP — nothing to do for evaluation. To delegate authentication to an existing identity provider (Keycloak, your in-house OP, …), set `AUTH_MODE=OpenIDConnect` and the four `OIDC_*` variables in `.env`. See [`twake_auth/README.md`](twake_auth/README.md) for the integration overview and [`docs/external-oidc.md`](docs/external-oidc.md) for the OP-side requirements and troubleshooting.

## Login & next steps

Three demo accounts are seeded into the local LDAP:

| Workspace                   | Login   | Password |
| :-------------------------- | :------ | :------- |
| `https://user1.twake.local` | `user1` | `user1`  |
| `https://user2.twake.local` | `user2` | `user2`  |
| `https://user3.twake.local` | `user3` | `user3`  |

For deeper operational topics, see the operator docs:

- [`docs/cookbook.md`](docs/cookbook.md) — day-to-day commands and debugging
- [`docs/CLI.md`](docs/CLI.md) — `scripts/twake` operator CLI reference
- [`docs/operations.md`](docs/operations.md) — host hardening, boot order, version floors
- [`docs/scim-import.md`](docs/scim-import.md) — bulk user provisioning over SCIM
- [`docs/cozy-defaults.md`](docs/cozy-defaults.md) — cozy context settings (feature flags, sharing trust)
- [`docs/safe-http-trusted-networks.md`](docs/safe-http-trusted-networks.md): letting cozy-stack reach the private network (federated sharing)
- [`docs/external-oidc.md`](docs/external-oidc.md) — external OIDC integration

If something is wrong, run `scripts/twake preflight` first, then check [`docs/operations.md`](docs/operations.md) and [`docs/cookbook.md`](docs/cookbook.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

GNU Affero General Public License v3.0 — see [`LICENSE`](LICENSE).

## Links

- [Twake.ai](https://twake.ai) — official website
- [Linagora](https://linagora.com) — company behind Twake.ai
