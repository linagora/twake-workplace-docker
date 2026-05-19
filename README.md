# Twake.AI Kickstart

[Twake.ai](https://twake.ai) is an open-source Digital Workplace developed by [LINAGORA](https://linagora.com). It brings together all the tools your team needs in a single platform: messaging, email, file sharing, collaborative document editing, calendar, video conferencing, and a personal cloud, all unified behind a single sign-on.

**Twake.AI Kickstart** provides a ready-to-run Docker Compose infrastructure to deploy a complete Twake.ai instance on your local machine or development server. It is designed to help developers, sysadmins, and evaluators get hands-on experience with the platform in minutes.

## Table of Contents

- [Features](#features)
- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Configuration](#configuration)
- [Deployment Instructions](#deployment-instructions)
- [Test Credentials](#test-credentials)
- [Troubleshooting](#troubleshooting)
- [Operator documentation](#operator-documentation)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Chat**: Real-time messaging powered by Matrix/Synapse
- **Email**: Full JMAP email via TMail
- **File Sharing**: Secure file transfer and storage with LinShare
- **Document Editing**: Collaborative editing with OnlyOffice
- **Calendar**: Shared calendaring
- **Video Conferencing**: WebRTC meetings with LiveKit
- **Personal Cloud**: Individual workspace powered by Cozy Stack
- **Single Sign-On**: Unified authentication with LemonLDAP::NG
- **Reverse Proxy**: Automatic routing and SSL via Traefik

## Architecture Overview

The stack is split into modular components, each managed via its own Docker Compose file:

### 1. Database Layer (`twake_db`)

Centralized data storage services used by other components.

- **PostgreSQL**: Main relational database for LinShare and Meet
- **MongoDB**: Document store for LinShare
- **CouchDB**: Database for Cozy Stack
- **OpenLDAP**: Directory service for user management
- **Valkey (Redis)**: In-memory data store
- **RabbitMQ**: Message broker for inter-service events

### 2. Authentication & Proxy Layer (`twake_auth`)

Handles entry points and security.

- **Traefik**: Reverse proxy with routing via `twake-network` and SSL management
- **LemonLDAP::NG**: Web Single Sign-On (SSO) and OIDC provider
- **Docker Socket Proxy**: Securely exposes the Docker socket to Traefik

### 3. Meet Application (`meet_app`)

Video conferencing component.

- **LiveKit**: Real-time video and audio server
- **Django Backend**: APIs and logic for meetings
- **Frontend**: Web interface for video calls

### 4. LinShare Application (`linshare_app`)

Secure file sharing and storage.

- **Backend**: Tomcat-based server
- **UI User**: Web interface for general users
- **UI Admin**: Administration web interface
- **UI Upload Request**: Interface for external upload requests
- **ClamAV**: Antivirus scanning for uploaded files

### 5. Cozy Stack (`cozy_stack`)

- **Cozy Stack**: Personal cloud platform server

### 6. OnlyOffice Application (`onlyoffice_app`)

- **OnlyOffice**: Document editing and collaboration server

### 7. Calendar Application (`calendar_app`)

- **Calendar**: Shared calendar service

### 8. TMail Application (`tmail_app`)

- **TMail**: JMAP email service

### 9. Chat Application (`chat_app`)

- **Matrix Synapse**: Federated messaging server
- **Tom Server**: Identity and vault server

### Component Structure

Each component is defined as a separate Docker Compose project and includes:

- A `docker-compose.yml` file defining its services
- A wrapper script (`compose-wrapper.sh`) that generates configuration files dynamically based on the domain settings in the root `.env` file

## Prerequisites

- **Docker** and **Docker Compose** (v2+) installed
- At least **8 GB of RAM** available for Docker
- About **20 GB of free disk space** for Docker images (~30 container images across all services)
- Ports **80** and **443** available on the host

## Quick Start

This walkthrough deploys the stack on your local machine using the default `twake.local` domain and a self-signed CA. If you are deploying on a server with a public domain name, follow [Configuration → Public DNS deployment](#public-dns-deployment) instead.

### 1. Create the shared network

```bash
docker network create twake-network --subnet=172.27.0.0/16
```

### 2. Configure DNS

Add the following entries to your `/etc/hosts` file:

```
127.0.0.1  linshare.twake.local admin-linshare.twake.local upload-request-linshare.twake.local meet.twake.local onlyoffice.twake.local calendar.twake.local contacts.twake.local account.twake.local excal.twake.local mail.twake.local jmap.twake.local
127.0.0.1  oauthcallback.twake.local manager.twake.local auth.twake.local ldap-rest.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local
127.0.0.1  user1.twake.local user1-home.twake.local user1-linshare.twake.local user1-drive.twake.local user1-settings.twake.local user1-mail.twake.local user1-chat.twake.local user1-notes.twake.local user1-dataproxy.twake.local
127.0.0.1  user2.twake.local user2-home.twake.local user2-linshare.twake.local user2-drive.twake.local user2-settings.twake.local user2-mail.twake.local user2-chat.twake.local user2-notes.twake.local user2-dataproxy.twake.local
127.0.0.1  user3.twake.local user3-home.twake.local user3-linshare.twake.local user3-drive.twake.local user3-settings.twake.local user3-mail.twake.local user3-chat.twake.local user3-notes.twake.local user3-dataproxy.twake.local
127.0.0.1  chat.twake.local matrix.twake.local tom.twake.local fed.twake.local traefik.twake.local calendar-ng.twake.local
```

### 3. Trust the self-signed CA certificate

> **This step applies to local development only (self-signed mode).** If you are deploying with a Let's Encrypt certificate, skip this step — your browser already trusts Let's Encrypt.

This setup uses a self-signed Certificate Authority. You **must** add it to your OS and browser trust store to avoid TLS errors and broken iframes.

The certificate is located at: [`twake_auth/traefik/ssl/root-ca.pem`](twake_auth/traefik/ssl/root-ca.pem)

### 4. Start all services

```bash
./wrapper.sh up -d
```

This starts all components in the correct dependency order. Wait a few minutes for all services to become healthy.

### 5. Access the platform

Open your browser and navigate to one of the test workspaces (see [Test Credentials](#test-credentials) below).

## Configuration

The root `.env` file is the single place to configure the stack. Key variables:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `BASE_DOMAIN` | `twake.local` | Domain used for all service subdomains |
| `LDAP_BASE_DN` | `dc=twake,dc=local` | LDAP base DN (must match `BASE_DOMAIN`) |
| `MAIL_DOMAIN` | `twake.local` | Domain used for email addresses |
| `CERT_MODE` | `self-signed` | Certificate mode: `self-signed` or `letsencrypt` |

Each component's `compose-wrapper.sh` uses `envsubst` to regenerate its configuration from `.template` files on every start, so no domain value is hardcoded. SSL certificates are stored in `twake_auth/traefik/ssl/`.

Two deployment modes are supported:

- [**Local development**](#local-development-no-public-dns): uses `twake.local` with `/etc/hosts` entries and a self-signed CA. This is what the [Quick Start](#quick-start) walks through.
- [**Public DNS deployment**](#public-dns-deployment): uses a real domain (e.g. `mydomain.fr`) with a valid Let's Encrypt wildcard certificate.

### Local development (no public DNS)

The default configuration. Keep the default values in `.env` and configure your `/etc/hosts` as shown in [Quick Start step 2](#2-configure-dns). Certificates are auto-generated by `twake_auth/generate-cert.sh` (self-signed CA + wildcard server cert) the first time `twake_auth` is brought up. You must then trust the CA in your browser, as described in [Quick Start step 3](#3-trust-the-self-signed-ca-certificate).

### Public DNS deployment

Use this mode when deploying on a server reachable from the Internet, with a domain you control (referred to below as `mydomain.fr`: replace with your own).

#### 1. DNS

Create a **wildcard A record** `*.mydomain.fr` pointing to the public IP of the host running this stack. Make sure **TCP port 443** is reachable from the Internet (firewall / security group / NAT).

#### 2. Update `.env`

```env
BASE_DOMAIN=mydomain.fr
LDAP_BASE_DN=dc=mydomain,dc=fr
MAIL_DOMAIN=mydomain.fr
CERT_MODE=letsencrypt
```

#### 3. Obtain a wildcard certificate (DNS-01 challenge)

Wildcard certificates (`*.mydomain.fr`) require the **DNS-01** challenge — HTTP-01 will not work. Install the certbot plugin for your DNS provider (e.g. `python3-certbot-dns-cloudflare`, `python3-certbot-dns-ovh`, `python3-certbot-dns-route53`) and run:

```bash
# Example for OVH (replace with your provider's plugin name and credentials path)
sudo certbot certonly --manual \
  -d "*.mydomain.fr" \
  -d "mydomain.fr"
```

See the [certbot DNS plugins documentation](https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins) for provider-specific setup.

Alternatively, you can use [acme.sh](https://github.com/acmesh-official/acme.sh) with any supported DNS API.

Once issued, certbot stores the certificates at `/etc/letsencrypt/live/mydomain.fr/`.

#### 4. Start the stack

```bash
./wrapper.sh up -d
```

`twake_auth/compose-wrapper.sh` detects `CERT_MODE=letsencrypt` and automatically copies the Let's Encrypt certificates from `/etc/letsencrypt/live/mydomain.fr/` into `twake_auth/traefik/ssl/`, then restarts the reverse proxy. No manual file copying is needed.

> **Skip [Quick Start step 3](#3-trust-the-self-signed-ca-certificate)** — with a valid Let's Encrypt certificate your browser trusts it automatically.

#### 5. Certificate renewal

Certbot installs a systemd timer that auto-renews certificates before they expire. After each renewal, re-copy the updated certificates into Traefik by running:

```bash
cd twake_auth && ./compose-wrapper.sh up -d
```

This re-copies the renewed certificates and restarts Traefik automatically.

To automate this, add a certbot post-renewal hook at `/etc/letsencrypt/renewal-hooks/post/restart-traefik.sh`:

```bash
#!/bin/bash
cd /path/to/twake-workplace-docker/twake_auth && ./compose-wrapper.sh up -d
```

## Deployment Instructions

### Using the wrapper script (recommended)

```bash
# Start all services
./wrapper.sh up -d

# Start a specific component
./wrapper.sh up twake_db -d

# Stop all services
./wrapper.sh down

# Show usage
./wrapper.sh --help
```

### Starting components individually

If you prefer to start components one by one, follow this order:

```bash
# 1. Databases
cd twake_db && ./compose-wrapper.sh up -d && cd ..

# 2. Authentication & Proxy
cd twake_auth && ./compose-wrapper.sh up -d && cd ..

# 3. Cozy Stack
cd cozy_stack && ./compose-wrapper.sh up -d && cd ..

# 4. OnlyOffice
cd onlyoffice_app && docker compose --env-file ../.env up -d && cd ..

# 5. Meet
cd meet_app && ./compose-wrapper.sh up -d && cd ..

# 6. Calendar
cd calendar_app && ./compose-wrapper.sh up -d && cd ..

# 7. Chat (requires lemonldap-ng healthy)
cd chat_app && ./compose-wrapper.sh up -d && cd ..

# 8. TMail (requires lemonldap-ng healthy)
cd tmail_app && ./compose-wrapper.sh up -d && cd ..
```

### Verify deployment

```bash
docker ps
```

## Test Credentials

| Workspace                   | Login   | Password |
| :-------------------------- | :------ | :------- |
| `https://user1.twake.local` | `user1` | `user1`  |
| `https://user2.twake.local` | `user2` | `user2`  |
| `https://user3.twake.local` | `user3` | `user3`  |

## Troubleshooting

- **Iframes not loading in Cozy Stack**: Make sure the self-signed CA certificate is trusted by both your OS and your browser (local mode only).
- **TLS errors in browser (local mode)**: The self-signed CA at `twake_auth/traefik/ssl/root-ca.pem` must be added to your system trust store and browser. Simply trusting it in the browser is not enough for some iframes.
- **`generate-cert.sh` fails with "Let's Encrypt certs not found"**: Run certbot first to issue the wildcard certificate before starting the stack. Check that `/etc/letsencrypt/live/<BASE_DOMAIN>/` exists and is readable.
- **Services failing to start**: Check that the `twake-network` Docker network exists (`docker network ls`) and that no other service is using ports 80/443.
- **Health check failures**: Some services (chat, tmail) depend on LemonLDAP::NG being healthy. Wait for it to be ready before starting dependent services, or use `./wrapper.sh` which handles ordering automatically.

## Operator documentation

Deeper operational notes live in [`docs/`](docs/README.md):

- [`operations.md`](docs/operations.md): host prerequisites, boot ordering, version floors
- [`scim-import.md`](docs/scim-import.md): bulk-importing users via SCIM, end-to-end verification
- [`external-oidc.md`](docs/external-oidc.md): plugging in an external OpenID Connect provider
- [`cozy-defaults.md`](docs/cozy-defaults.md): cozy default context settings (passphrase bypass, feature flags, sharing trust)
- [`cookbook.md`](docs/cookbook.md): day-to-day commands for listing state, cleaning up, inspecting RabbitMQ, and debugging

Operator CLI: [`scripts/twake`](scripts/twake) wraps preflight checks, SCIM user lifecycle, drift reporting, and RabbitMQ tapping behind a single entry point with per-subcommand `--help`. See [`scripts/README.md`](scripts/README.md).

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to get involved.

## License

This project is licensed under the **GNU Affero General Public License v3.0**: see the [LICENSE](LICENSE) file for details.

## Links

- [Twake.ai](https://twake.ai): Official website
- [Linagora](https://linagora.com): Company behind Twake.ai
