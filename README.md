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
127.0.0.1  oauthcallback.twake.local manager.twake.local auth.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local
127.0.0.1  user1.twake.local user1-home.twake.local user1-linshare.twake.local user1-drive.twake.local user1-settings.twake.local user1-mail.twake.local user1-chat.twake.local user1-notes.twake.local user1-dataproxy.twake.local
127.0.0.1  user2.twake.local user2-home.twake.local user2-linshare.twake.local user2-drive.twake.local user2-settings.twake.local user2-mail.twake.local user2-chat.twake.local user2-notes.twake.local user2-dataproxy.twake.local
127.0.0.1  user3.twake.local user3-home.twake.local user3-linshare.twake.local user3-drive.twake.local user3-settings.twake.local user3-mail.twake.local user3-chat.twake.local user3-notes.twake.local user3-dataproxy.twake.local
127.0.0.1  chat.twake.local matrix.twake.local tom.twake.local fed.twake.local traefik.twake.local calendar-ng.twake.local
```

### 3. Trust the self-signed CA certificate

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

The root `.env` file defines `BASE_DOMAIN`, `LDAP_BASE_DN`, and `MAIL_DOMAIN`. Each component's `compose-wrapper.sh` uses `envsubst` to regenerate its configuration from `.template` files whenever it starts, so no domain is hardcoded. SSL certificates are stored in `twake_auth/traefik/ssl/`.

Two deployment modes are supported:

- [**Local development**](#local-development-no-public-dns): uses `twake.local` with `/etc/hosts` entries and a self-signed CA. This is what the [Quick Start](#quick-start) walks through.
- [**Public DNS deployment**](#public-dns-deployment): uses a real domain (e.g. `mydomain.fr`) with a valid Let's Encrypt wildcard certificate.

### Local development (no public DNS)

The default configuration. Keep the default values in `.env` and configure your `/etc/hosts` as shown in [Quick Start step 2](#2-configure-dns). Certificates are auto-generated by `twake_auth/generate-cert.sh` (self-signed CA + wildcard server cert) the first time `twake_auth` is brought up. You must then trust the CA in your browser, as described in [Quick Start step 3](#3-trust-the-self-signed-ca-certificate).

### Public DNS deployment

Use this mode when deploying on a server reachable from the Internet, with a domain you control (referred to below as `mydomain.fr`: replace with your own).

#### 1. DNS

Create a **wildcard record** `*.mydomain.fr` (A and/or AAAA) pointing to the public IP of the host running this stack. Make sure **TCP ports 80 and 443** are reachable from the Internet (firewall / security group / NAT).

#### 2. Update `.env`

Replace every occurrence of the local domain with your public domain:

```env
BASE_DOMAIN=mydomain.fr
LDAP_BASE_DN=dc=mydomain,dc=fr
MAIL_DOMAIN=mydomain.fr
```

#### 3. Obtain a wildcard certificate via certbot (DNS-01)

A wildcard certificate for `*.mydomain.fr` requires the **DNS-01** challenge. Install the certbot plugin matching your DNS provider (e.g. `python3-certbot-dns-cloudflare`, `…-ovh`, `…-route53`) and run:

```bash
sudo certbot certonly \
  --dns-<provider> \
  --dns-<provider>-credentials /path/to/credentials.ini \
  -d "*.mydomain.fr" \
  -d "mydomain.fr"
```

See the [certbot DNS plugins documentation](https://eff-certbot.readthedocs.io/en/latest/using.html#dns-plugins) for provider-specific instructions.

#### 4. Install the certificate

Copy the Let's Encrypt files into Traefik's SSL directory, overwriting the placeholders:

```bash
sudo cp /etc/letsencrypt/live/mydomain.fr/fullchain.pem \
        twake_auth/traefik/ssl/twake-server-fullchain.pem
sudo cp /etc/letsencrypt/live/mydomain.fr/privkey.pem \
        twake_auth/traefik/ssl/twake-server.key
```

> ⚠️ **Do not run `twake_auth/generate-cert.sh` in this mode.** It would overwrite the certificate you just installed.
>
> The `twake_auth/compose-wrapper.sh` script auto-runs `generate-cert.sh` when `traefik/ssl/twake-server.pem` or `traefik/ssl/root-ca.crt` are missing. As long as those two files already exist on disk (they are committed in the repo), regeneration will be skipped: do **not** delete them. A proper flag to disable cert generation in public DNS mode will be added later.

Renew the certificate periodically (certbot typically installs a systemd timer) and re-run the copy above, then restart Traefik: `docker restart reverse-proxy`.

With a valid Let's Encrypt certificate, you do not need to trust a custom CA in your browser: [Quick Start step 3](#3-trust-the-self-signed-ca-certificate) can be skipped.

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

- **Iframes not loading in Cozy Stack**: Make sure the self-signed CA certificate is trusted by both your OS and your browser.
- **Services failing to start**: Check that the `twake-network` Docker network exists and that no other service is using ports 80/443.
- **Health check failures**: Some services (chat, tmail) depend on LemonLDAP::NG being healthy. Wait for it to be ready before starting dependent services, or use `./wrapper.sh` which handles ordering automatically.

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to get involved.

## License

This project is licensed under the **GNU Affero General Public License v3.0**: see the [LICENSE](LICENSE) file for details.

## Links

- [Twake.ai](https://twake.ai): Official website
- [Linagora](https://linagora.com): Company behind Twake.ai
