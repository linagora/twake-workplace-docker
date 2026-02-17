# Twake POC Repository

This repository contains the infrastructure and services for Twake POC. The system is composed of several modular components, each managed via its own `docker-compose` file.

## Architecture Overview

The POC is split into the following operational layers:

### 1. Database Layer (`twake_db`)
Centralized data storage services used by other components.
*   **PostgreSQL**: Main relational database for Linshare and Meet.
*   **MongoDB**: Document store for LinShare.
*   **CouchDB**: Database for Cozy Stack.
*   **OpenLDAP**: Directory service for user management.
*   **Valkey (Redis)**: In-memory data store

### 2. Authentication & Proxy Layer (`twake_auth`)
Handles entry points and security.
*   **Traefik**: Reverse proxy. Handles routing to all services via `twake-network` and manages SSL.
*   **LemonLDAP::NG**: Web Single Sign-On (SSO).
*   **Docker Socket Proxy**: Securely exposes the Docker socket to Traefik.

### 3. Meet Application (`meet_app`)
The video conferencing component.
*   **LiveKit**: Real-time video and audio server.
*   **Django Backend**: APIs and logic for meetings.
*   **Frontend**: Web interface for video calls.

### 4. LinShare Application (`linshare_app`)
Secure file sharing and storage.
*   **Backend**: Tomcat-based server.
*   **UI User**: Web interface for general users.
*   **UI Admin**: Administration web interface.
*   **UI Upload Request**: Interface for external upload requests.
*   **ClamAV**: Antivirus scanning for uploaded files.

### 5. Cozy Stack (`cozy_stack`)
*   **Cozy Stack**: Personal cloud platform server.

### 6. OnlyOffice Application (`onlyoffice_app`)
*   **OnlyOffice**: Document editing and collaboration.

### 7. Calendar Application (`calendar_app`)
*   **Calendar**: Calendar application.

### 8. TMail Application (`tmail_app`)
*   **TMail**: Email application.

### Component's Structure 
Each component (application) in the PoC repository is defined as a separate Docker Compose project.

Every application includes:
- a docker-compose.yml file that defines its services.
- a wrapper script responsible for generating the required configuration files for those services.

The wrapper generates configuration files dynamically based on the domain specifications defined in the root .env file of the project.

## Prerequisites

*   **Docker** and **Docker Compose** installed.


## Configuration

*   **Domains**: The stack is configured for `*.twake.local` domain. Configure your `/etc/hosts` with:

```bash
127.0.0.1  linshare.twake.local admin-linshare.twake.local upload-request-linshare.twake.local meet.twake.local onlyoffice.twake.local calendar.twake.local contacts.twake.local account.twake.local excal.twake.local mail.twake.local jmap.twake.local
127.0.0.1  oauthcallback.twake.local manager.twake.local auth.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local
127.0.0.1  user1.twake.local user1-home.twake.local user1-linshare.twake.local user1-drive.twake.local user1-settings.twake.local user1-mail.twake.local user1-chat.twake.local user1-notes.twake.local user1-dataproxy.twake.local
127.0.0.1  user2.twake.local user2-home.twake.local user2-linshare.twake.local user2-drive.twake.local user2-settings.twake.local user2-mail.twake.local user2-chat.twake.local user2-notes.twake.local user2-dataproxy.twake.local
127.0.0.1  user3.twake.local user3-home.twake.local user3-linshare.twake.local user3-drive.twake.local user3-settings.twake.local user3-mail.twake.local user3-chat.twake.local user3-notes.twake.local user3-dataproxy.twake.local
```
## Deployment Instructions

### 1. Create the Network
Before starting any services, create the shared network:
```bash
docker network create twake-network --subnet=172.27.0.0/16
```

### 2. Start Services
- In order to pull Linshare components, you need to be logged in to Linagora Docker registry.
- Modify the .env file to update the domain name, the default is `twake.local`.
- To start the services, use the following script:

```bash
./wrapper.sh up -d
```
- If you want to start the components one by one, you can use the following commands:
```bash
./wrapper.sh up -d dirname
```
example:
```bash
./wrapper.sh up -d twake_db
```
- To see how to use the wrapper script, run:
```bash
./wrapper.sh --help
```

- If you want to start the services one by one, you can use the following commands:
#### Step 1: Start Databases

- Navigate to the database directory and start the services:
```bash
cd twake_db
./compose-wrapper.sh up -d
cd ..
```

#### Step 2: Start Authentication & Proxy Layer
```bash
cd twake_auth
./compose-wrapper.sh up -d
cd ..
```

#### Step 3: Start Meet Application
```bash
cd meet_app
./compose-wrapper.sh up -d
cd ..
```

#### Step 4: Start LinShare Application
```bash
cd linshare_app
./compose-wrapper.sh up -d
cd ..
```

#### Step 5: Start OnlyOffice Application
```bash
cd onlyoffice_app
docker compose --env-file ../.env  up -d
cd ..
```
#### Step 6: Start Calendar Application
```bash
cd calendar_app
./compose-wrapper.sh up -d
cd ..
```
#### Step 7: Start TMail Application
```bash
cd tmail_app
./compose-wrapper.sh up -d
cd ..
```

#### Step 8: Start Cozy Stack
```bash
cd cozy_stack
./compose-wrapper.sh up -d
cd ..
```
#### Step 9: Start Chat Application
```bash
cd chat_app
./compose-wrapper.sh up -d
cd ..
```


### 3. Verify Deployment
Check that all services are running:
```bash
docker ps
```

*   **Certificates**: SSL certificates are expected in `twake_auth/traefik/ssl/`.

## Quick Start Guide

Once everything is running:


### Browser self-signed certificate

This POC uses a self-signed Certificate Authority (CA).

When Cozy Stack integrates external applications (Mail,LinShare, etc.), they are loaded inside **iframes**.  
If the CA is **not trusted by the browser**, browsers will block or partially break these iframes due to TLS and security restrictions.

To avoid iframe loading issues, mixed-content warnings, and blocked resources, you **must trust the CA certificate** used by the reverse-proxy (Traefik).

#### What to do

Add the self-signed certificate to your browser:

[twake_auth/traefik/ssl/root-ca.pem](twake_auth/traefik/ssl/root-ca.pem)

To access cozy stack instances, use the following credentials:

| Workplace | Login | Password |
| :--- | :--- | :--- |
| `https://user1.twake.local` | `user1` | `user1` |
| `https://user2.twake.local` | `user2` | `user2` |
| `https://user3.twake.local` | `user3` | `user3` |
      