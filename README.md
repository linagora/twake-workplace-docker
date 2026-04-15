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
- **Email**: Full JMAP email via [Twake Mail](https://twake-mail.com/)
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

### 3. Visio Application (`visio_app`)

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

### 5. Drive Application (`drive_app`)

- **Cozy Stack**: Personal cloud and drive platform server

### 6. OnlyOffice Application (`onlyoffice_app`)

- **OnlyOffice**: Document editing and collaboration server

### 7. Calendar Application (`calendar_app`)

- **Calendar**: Shared calendar service

### 8. Mail Application (`mail_app`)

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

### 1. Create the shared network

```bash
docker network create twake-network --subnet=172.27.0.0/16
```

### 2. Configure DNS

Add the following entries to your `/etc/hosts` file (adapt if you changed `BASE_DOMAIN` in `.env`):

```bash
# Authentication & proxy (twake_auth)
127.0.0.1  auth.twake.local manager.twake.local traefik.twake.local oauthcallback.twake.local

# Chat (chat_app)
127.0.0.1  chat.twake.local matrix.twake.local tom.twake.local fed.twake.local

# Mail (mail_app)
127.0.0.1  mail.twake.local jmap.twake.local

# Calendar (calendar_app)
127.0.0.1  calendar.twake.local calendar-ng.twake.local contacts.twake.local account.twake.local excal.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local

# Visio (visio_app)
127.0.0.1  meet.twake.local

# LinShare (linshare_app)
127.0.0.1  linshare.twake.local admin-linshare.twake.local upload-request-linshare.twake.local

# OnlyOffice (onlyoffice_app)
127.0.0.1  onlyoffice.twake.local

# Drive / Cozy Stack (drive_app) - per-user subdomains
127.0.0.1  user1.twake.local user1-home.twake.local user1-drive.twake.local user1-linshare.twake.local user1-mail.twake.local user1-chat.twake.local user1-settings.twake.local user1-notes.twake.local user1-dataproxy.twake.local
127.0.0.1  user2.twake.local user2-home.twake.local user2-drive.twake.local user2-linshare.twake.local user2-mail.twake.local user2-chat.twake.local user2-settings.twake.local user2-notes.twake.local user2-dataproxy.twake.local
127.0.0.1  user3.twake.local user3-home.twake.local user3-drive.twake.local user3-linshare.twake.local user3-mail.twake.local user3-chat.twake.local user3-settings.twake.local user3-notes.twake.local user3-dataproxy.twake.local
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

- The root `.env` file defines `BASE_DOMAIN`, `LDAP_BASE_DN`, and `MAIL_DOMAIN`. The default domain is `twake.local`.
- Each component's `compose-wrapper.sh` uses `envsubst` to generate configuration from `.template` files: no hardcoded domains.
- SSL certificates are stored in `twake_auth/traefik/ssl/`.
- To log in to the Linagora Docker registry (required for LinShare images), authenticate before starting services.

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
cd drive_app && ./compose-wrapper.sh up -d && cd ..

# 4. OnlyOffice
cd onlyoffice_app && docker compose --env-file ../.env up -d && cd ..

# 5. Meet
cd visio_app && ./compose-wrapper.sh up -d && cd ..

# 6. Calendar
cd calendar_app && ./compose-wrapper.sh up -d && cd ..

# 7. Chat (requires lemonldap-ng healthy)
cd chat_app && ./compose-wrapper.sh up -d && cd ..

# 8. TMail (requires lemonldap-ng healthy)
cd mail_app && ./compose-wrapper.sh up -d && cd ..
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
