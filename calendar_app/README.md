# Twake Calendar Stack -- Local Setup Guide

This guide explains how to start the Twake Calendar stack locally in the
correct order.

------------------------------------------------------------------------

## Prerequisites

-   Docker
-   Docker Compose
-   Linux
-   Ports 80 / 443 available

------------------------------------------------------------------------

## Step 1: Start Databases

Navigate to the database directory and start the services:

``` bash
cd twake_db
docker-compose up -d
cd ..
```

------------------------------------------------------------------------

## Step 2: Start Authentication & Proxy Layer

``` bash
cd twake_auth
docker-compose up -d
cd ..
```

------------------------------------------------------------------------

## Step 3: Configure /etc/hosts

The stack uses `*.twake.local` domains. These need to point to your **Traefik container IP** (the gateway for all services).

### 1️⃣ Find Traefik container IP

Run this command to get the IP of the Traefik container:

```bash
docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' traefik
```

Assume it returns:

```
172.27.0.2
```

### 2️⃣ Edit /etc/hosts

```bash
sudo nano /etc/hosts
```

Add the following lines, replacing `172.27.0.2` with your Traefik IP:

```text
172.27.0.2  tcalendar-side-service.twake.local sabre-dav.twake.local
172.27.0.2  calendar.twake.local calendar-ng.twake.local contacts.twake.local account.twake.local excal.twake.local
```

Save and exit.

> ✅ This ensures all requests to `*.twake.local` go through Traefik, which handles routing and TLS for the services.

------------------------------------------------------------------------

## Step 4: Start Calendar Application

``` bash
cd calendar_app
docker compose up -d
```

------------------------------------------------------------------------

## Step 5: Import Root CA Certificate (IMPORTANT)

The side service requires trusting the custom Root CA.


``` bash
cd calendar_app
chmod +x patch-calendar.sh
./patch-calendar.sh

```

------------------------------------------------------------------------

## Done ✅

You can now access the applications:

-   Calendar: https://calendar.twake.local
-   New calendar: https://calendar-ng.twake.local
-   Contacts: https://contacts.twake.local/contacts/
-   Account: https://account.twake.local


------------------------------------------------------------------------


