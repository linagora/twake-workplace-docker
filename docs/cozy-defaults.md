# Cozy default context settings

In this stack, every instance provisioned through cozyProvision is created in the `default` context (see `COZY_CONTEXT_NAME` in `.env`). Cozy-stack reads context-keyed config from two top-level blocks in the rendered `cozy.yaml`: `authentication.default` and `contexts.default`. The first lives inline in `cozy_stack/config/cozy.yaml.template`. The second is composed at render time from `default-sharing.yaml` and `default-flags.yaml` (each overridable via a `*.local.yaml` sibling).

## Authentication: forced OIDC

```yaml
authentication:
  default:
    disable_password_authentication: true
    oidc:
      client_id: IDCOZY
      client_secret: secretcozy
      authorize_url: https://auth.${BASE_DOMAIN}/oauth2/authorize
      token_url:     https://auth.${BASE_DOMAIN}/oauth2/token
      userinfo_url:  https://auth.${BASE_DOMAIN}/oauth2/userinfo
      id_token_jwk_url: https://auth.${BASE_DOMAIN}/oauth2/jwks
      logout_url:    https://auth.${BASE_DOMAIN}/oauth2/logout
      ...
```

`disable_password_authentication: true` is what cozy-stack's `Instance.HasForcedOIDC()` returns. One observable consequence: the `user.created` RabbitMQ consumer accepts messages without a passphrase hash for instances in this context (it logs `skipping passphrase update for instance ... (forced OIDC context: default)`). Without the flag, cozy-stack nacks those messages with `missing passphrase hash`.

The `oidc:` block configures cozy-stack as an OIDC RP against LemonLDAP-NG (the URLs all point at `auth.${BASE_DOMAIN}`). For details on the LemonLDAP side and plugging in an external upstream OP, see [external-oidc.md](external-oidc.md).

## Feature flags

Defined in `cozy_stack/config/default-flags.yaml` (a YAML map of flag name to a list of `{ratio, value}` pairs). The wrapper splices that file into `contexts.default.features` of the rendered `cozy.yaml` at startup.

To override per deployment, copy the file alongside it as `default-flags.local.yaml` and edit. The wrapper picks the `.local.yaml` if it exists, otherwise the committed default. The local file is gitignored.

Inspect the flags cozy-stack actually loaded for the default context:

```bash
docker exec cozyt cozy-stack feature config --context default
```

Inspect the effective flags on a specific instance, with their source:

```bash
docker exec cozyt cozy-stack feature show --domain <user>.<BASE_DOMAIN> --source
```

In the `--source` output, instance-level flags (`io.cozy.settings.flags.instance`) are listed before config-level flags (`io.cozy.settings.flags.config`); when both define the same key the instance value wins.

To apply a change, re-render and reload:

```bash
cd cozy_stack
./compose-wrapper.sh render   # rewrite cozy.yaml from template + defaults
docker restart cozyt
```

## Sharing trust

Defined in `cozy_stack/config/default-sharing.yaml`:

```yaml
auto_accept_trusted: true
auto_accept_trusted_contacts: true
trusted_domains:
  - ${BASE_DOMAIN}
```

Same override pattern as the flags file: copy to `default-sharing.local.yaml` to override per deployment. `${BASE_DOMAIN}` is substituted by the wrapper at render time, so all instances inside the same deployment list each other's parent domain as trusted. With `auto_accept_trusted: true` and `auto_accept_trusted_contacts: true`, sharing invitations between users in the same workplace go through without each side manually confirming. Add more entries to `trusted_domains` to extend trust to other deployments.

## Resetting a polluted stack

The rendered `cozy.yaml` is gitignored, so it survives branch switches and is never updated by `git`. If an instance was ever brought up without a correct render (for example a bare `docker compose up` at the repo root instead of `./wrapper.sh up`, or with `../.env` not loaded so `BASE_DOMAIN` was empty), the bad state can hide in three independent layers. Clean them in order and stop as soon as your case is covered.

The wrapper now refuses to render a `cozy.yaml` that still contains `__DEFAULT_` markers, a literal `${BASE_DOMAIN}`, or an empty-domain URL like `https://auth./`. So re-rendering is the first thing to try: it either produces a clean file or fails loudly.

### Layer 1: the rendered config file

```bash
cd cozy_stack
rm -f config/cozy.yaml          # drop the stale or half-rendered file
./compose-wrapper.sh render     # re-render; aborts if the result is incomplete
```

Gotcha: if Docker was ever started while `config/cozy.yaml` was absent, it auto-creates a *directory* at that path. Check with `[ -d config/cozy.yaml ] && rm -rf config/cozy.yaml`, then re-render.

### Layer 2: the running container

cozy-stack reads `cozy.yaml` only at startup, so a running `cozyt` keeps the old config until recreated. This keeps the data volume.

```bash
cd cozy_stack
./compose-wrapper.sh up -d --force-recreate cozy-stack
docker exec cozyt cozy-stack feature config --context default   # verify defaults loaded
```

If the config file was the only problem and no instances exist yet, you are done.

### Layer 3: the data volume

A re-render does *not* touch anything already written into CouchDB: created instances, their instance-level flags, global defaults set via `cozy-stack features defaults`, and any per-app URLs baked in by the patcher (these may carry an empty `BASE_DOMAIN`, e.g. domains like `user1.` or URLs like `https://linshare./new/`).

Surgical (keep good instances, remove bad ones):

```bash
docker exec cozyt cozy-stack instances ls
docker exec cozyt cozy-stack instances rm --force user1.
docker exec cozyt cozy-stack feature flags --domain user1.${BASE_DOMAIN} '{"apps.hidden": null}'
```

Nuclear (clean slate, destroys all cozy instances and their files):

```bash
cd cozy_stack
./compose-wrapper.sh down
docker volume rm cozy_stack_cozy-data
./compose-wrapper.sh up -d        # re-renders automatically, recreates instances
```

`docker volume rm cozy_stack_cozy-data` is irreversible and wipes every user's drive in that cozy. Fine on a POC; never run it on a deployment with real data. Always bring the stack up through `./wrapper.sh up` or `cozy_stack/compose-wrapper.sh up`, never a bare `docker compose up` at the repo root, or the unrendered-config bug comes back.
