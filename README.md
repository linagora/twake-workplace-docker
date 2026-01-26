# Twake POC Repository

This repository contains the infrastructure and services for Twake POC. The system is composed of several modular components, each managed via its own `docker-compose` file.

## Architecture Overview

The POC is split into 5 operational layers:

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



## Prerequisites

*   **Docker** and **Docker Compose** installed.

## Deployment Instructions

### 1. Create the Network
Before starting any services, create the shared network:
```bash
docker network create twake-network --subnet=172.27.0.0/16
```

### 2. Start Services
It is recommended to start the components in the following order to ensure dependencies (databases, auth) are ready before the applications.

#### Step 1: Start Databases
In order to pull Linshare components, you need to be logged in to Linagora Docker registry.
Navigate to the database directory and start the services:
```bash
cd twake_db
docker compose up -d
cd ..
```

#### Step 2: Start Authentication & Proxy Layer
```bash
cd twake_auth
docker compose up -d
cd ..
```

#### Step 3: Start Meet Application
```bash
cd meet_app
docker compose up -d
cd ..
```

#### Step 4: Start LinShare Application
```bash
cd linshare_app
docker compose up -d
cd ..
```

#### Step 5: Start OnlyOffice Application
```bash
cd onlyoffice_app
docker compose up -d
cd ..
```
#### Step 6: Start Calendar Application
```bash
cd calendar_app
docker compose up -d
cd ..
```
#### Step 7: Start TMail Application
```bash
cd tmail_app
docker compose up -d
cd ..
```

#### Step 8: Start Cozy Stack
```bash
cd cozy_stack
docker compose up -d
cd ..
```



### 3. Verify Deployment
Check that all services are running:
```bash
docker ps
```

## Configuration

*   **Domains**: The stack is configured for `*.twake.local` domains. Configure your `/etc/hosts` with:

```bash
127.0.0.1  linshare.twake.local admin-linshare.twake.local upload-request-linshare.twake.local meet.twake.local onlyoffice.twake.local calendar.twake.local contacts.twake.local account.twake.local excal.twake.local mail.twake.local jmap.twake.local
127.0.0.1  oauthcallback.twake.local manager.twake.local auth.twake.local tcalendar-side-service.twake.local sabre-dav.twake.local
127.0.0.1  user1.twake.local user1-home.twake.local user1-linshare.twake.local user1-drive.twake.local user1-settings.twake.local user1-mail.twake.local
127.0.0.1  user2.twake.local user2-home.twake.local user2-linshare.twake.local user2-drive.twake.local user2-settings.twake.local user2-mail.twake.local
127.0.0.1  user3.twake.local user3-home.twake.local user3-linshare.twake.local user3-drive.twake.local user3-settings.twake.local user3-mail.twake.local
```

*   **Certificates**: SSL certificates are expected in `twake_auth/traefik/ssl/`.

## Quick Start Guide

Once everything is running, follow these steps:

### Note
For this twake workplace docker compose version, we are not integrating Linshare in the twake home.
If you want to integrate Linshare in the twake home, you need to run this patch : [cozy_stack/patch-cozy.sh](cozy_stack/patch-cozy.sh)

### Configure LinShare

1. Browse to `https://admin-linshare.twake.local` and log in using:
   - **Email**: `root@localhost.localdomain`
   - **Password**: `adminlinshare`

2. Create a domain:
   - Select **Create domain**
   - Fill in the name field
   - Click **Save**

3. Configure the domain:
   - Select **Domain**
   - Click on the suggested domain
   - Select **User Providers**
   - Click on **Create new provider**
   - Select **OIDC**
   - Fill in the **Associated domain identifier** with `domain_discriminator` and save

### Browser self-signed certificate

Add the self-signed certificate to your browser:

[twake_auth/traefik/ssl/root-ca.pem](twake_auth/traefik/ssl/root-ca.pem)

To access cozy stack instances, use the following credentials:

| Workplace | Login | Password |
| :--- | :--- | :--- |
| `https://user1.twake.local` | `user1` | `user1` |
| `https://user2.twake.local` | `user2` | `user2` |
| `https://user3.twake.local` | `user3` | `user3` |
      