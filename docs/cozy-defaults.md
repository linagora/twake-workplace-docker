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
