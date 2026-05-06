# Operations

## Host prerequisites

- **`jq`** and **`envsubst`** on the host (the auth wrapper uses both, the SCIM import script uses `jq`). The wrappers fail fast with a clear install hint if either is missing. On Debian/Ubuntu: `sudo apt-get install -y jq gettext-base`.
- **UFW** (if enabled) must allow container egress. Containers route through the FORWARD chain and the kernel's `ip_forward`, both of which Ubuntu's hardened defaults disable. Set `DEFAULT_FORWARD_POLICY=ACCEPT` in `/etc/default/ufw`, uncomment `net/ipv4/ip_forward=1` in `/etc/ufw/sysctl.conf`, then `ufw reload`. The host being able to reach a URL doesn't tell you containers can, since they use a different netns.
- **Cozy-stack `1.6.50-rc1` or newer.** Older builds reject `user.created` RabbitMQ messages without a passphrase hash, even on contexts marked `disable_password_authentication: true`. Symptom in `cozyt` logs: `user.created: missing passphrase hash, nacking message`.

## Synapse data ownership

The `matrixdotorg/synapse` image drops to uid 991 at startup regardless of the compose `user:` directive. Files in the bind-mounted `/data` must be readable by that uid or synapse crashes with `PermissionError: '/data/homeserver.yaml'`. The init container chowns `/data`. On a fresh checkout that predates that fix:

```bash
sudo chown -R 991:991 chat_app/synapse
```

## Container egress at runtime

These containers reach external hosts at runtime, not just at build:

- LemonLDAP fetches the OIDC discovery doc on render, JWKS at every token verification.
- The visio-backend's entrypoint runs `apk add curl` on each boot for its healthcheck. Block alpine mirrors and the container is permanently unhealthy.
- Cozy-stack reaches the configured OP for the OIDC dance.

If egress is locked down, either bake the tools into the images or replace network-dependent healthchecks with stdlib alternatives.
