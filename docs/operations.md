# Operations

`scripts/twake preflight` automates a sanity check across most of the items below — tooling, UFW forward policy, `ip_forward`, wildcard DNS, hairpin reachability. Run it once on a fresh host before `./wrapper.sh up`, and again any time the stack misbehaves in a way that smells like infrastructure.

## Host prerequisites

- **`jq`** and **`envsubst`** on the host (the auth wrapper uses both, the SCIM import script uses `jq`). The wrappers fail fast with a clear install hint if either is missing. On Debian/Ubuntu: `sudo apt-get install -y jq gettext-base`.
- **UFW** (if enabled) must allow container egress. Containers route through the FORWARD chain and the kernel's `ip_forward`, both of which Ubuntu's hardened defaults disable. Set `DEFAULT_FORWARD_POLICY=ACCEPT` in `/etc/default/ufw`, uncomment `net/ipv4/ip_forward=1` in `/etc/ufw/sysctl.conf`, then `ufw reload`. The host being able to reach a URL doesn't tell you containers can, since they use a different netns.
- **Container to host public IP must work (NAT hairpin).** Cozy-to-cozy sharing has each instance call other instances by their public hostname, e.g. `https://<other-user>.<BASE_DOMAIN>`. Inside the docker network those names resolve to the host's public IP, and the connection has to NAT out, hit the host's eth0, and come back to traefik. Cozy-stack's `safehttp` package refuses to dial private IPs (SSRF protection), so the workaround of pointing containers at an internal DNS that returns traefik's bridge IP does not work; the public IP path is the only one. On a fresh Debian/Ubuntu host the hairpin works after the UFW changes above. If your host firewall or routing rejects the loopback, sharing requests fail silently and fall back to email. Easiest verification: `docker exec cozyt curl -sS -o /dev/null -w "%{http_code}\n" https://<other-user>.<BASE_DOMAIN>/` should return a `3xx`.
- **Cozy-stack `1.6.50-rc1` or newer.** Older builds reject `user.created` RabbitMQ messages without a passphrase hash, even on contexts marked `disable_password_authentication: true`. Symptom in `cozyt` logs: `user.created: missing passphrase hash, nacking message`.

## Boot order

`./wrapper.sh up -d` starts every stack in the correct order and waits for `lemonldap-ng` to become healthy before bringing up the apps that depend on it. The order below is what the wrapper applies; it's only useful when starting individual stacks by hand or debugging the wrapper.

Start order:

1. `twake_db` — databases and message broker
2. `twake_auth` — Traefik + LemonLDAP-NG
3. `cozy_stack`
4. `onlyoffice_app`
5. `meet_app`
6. `calendar_app`
7. `chat_app`
8. `tmail_app`

Five stacks depend on `lemonldap-ng` being healthy before they start:

- `chat_app` — Synapse loads the OIDC discovery doc at boot and refuses to start if the IdP is unreachable.
- `cozy_stack` — confidential OIDC client (`IDCOZY`) with `disable_password_authentication=true`, so OIDC is the only login path.
- `meet_app` — confidential client (`visio`) that exchanges the auth code with `client_secret` server-side.
- `tmail_app`, `calendar_app` — public clients with lazy introspection, gated as a precaution so the first login is never racing the IdP startup.

To start the stacks manually:

```bash
cd twake_db       && ./compose-wrapper.sh up -d                 && cd ..
cd twake_auth     && ./compose-wrapper.sh up -d                 && cd ..
cd cozy_stack     && ./compose-wrapper.sh up -d                 && cd ..
cd onlyoffice_app && docker compose --env-file ../.env up -d    && cd ..
cd meet_app       && ./compose-wrapper.sh up -d                 && cd ..
cd calendar_app   && ./compose-wrapper.sh up -d                 && cd ..
cd chat_app       && ./compose-wrapper.sh up -d                 && cd ..
cd tmail_app      && ./compose-wrapper.sh up -d                 && cd ..
```

Wait for `lemonldap-ng` to report `healthy` (`docker ps`) before continuing past `twake_auth`.

## Synapse data ownership

The `matrixdotorg/synapse` image drops to uid 991 at startup regardless of the compose `user:` directive. Files in the bind-mounted `/data` must be readable by that uid or synapse crashes with `PermissionError: '/data/homeserver.yaml'`. The init container chowns `/data`. On a fresh checkout that predates that fix:

```bash
sudo chown -R 991:991 chat_app/synapse
```

## Video calls (LiveKit media)

`meet_app` runs LiveKit for the actual audio and video. LiveKit hands each browser an ICE candidate IP to send media to. By default (`LIVEKIT_USE_EXTERNAL_IP=false`) it advertises its internal container IP, which is fine on a single local host but unroutable from anywhere else. The symptom on a public deployment is a call that connects (the signaling websocket is up, participants appear) but carries no audio or video.

On a public host, set in `.env`:

```env
LIVEKIT_USE_EXTERNAL_IP=true
```

LiveKit then auto-detects the host's public IP via STUN and advertises that instead. Media is muxed over a single UDP port, so the firewall only needs three ports open:

- `7880/tcp`, signaling
- `7881/tcp` and `7881/udp`, media

Recreate the stack after the change (`cd meet_app && ./compose-wrapper.sh up -d`). The wrapper re-renders `config/livekit.yaml` from the template on every `up`.

If a call is still silent with `use_external_ip: true`, check which address LiveKit settled on: `docker logs visio-livekit | grep nodeIP`. Behind 1:1 NAT, STUN auto-detection can pick the wrong IP. Pin it explicitly by adding a `node_ip` line under `rtc:` in `meet_app/config/livekit.yaml.template`:

```yaml
rtc:
  node_ip: <public-ip>
```

## Container egress at runtime

These containers reach external hosts at runtime, not just at build:

- LemonLDAP fetches the OIDC discovery doc on render, JWKS at every token verification.
- The visio-backend's entrypoint runs `apk add curl` on each boot for its healthcheck. Block alpine mirrors and the container is permanently unhealthy.
- Cozy-stack reaches the configured OP for the OIDC dance.

If egress is locked down, either bake the tools into the images or replace network-dependent healthchecks with stdlib alternatives.
