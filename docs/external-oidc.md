# External OIDC integration

LemonLDAP-NG can delegate authentication to an external OpenID Connect provider while keeping the local LDAP as the user attribute store. This page covers how to plug in a provider and what they have to support.

## What the provider has to support

The integration relies on the standard OIDC bits, nothing exotic:

- A reachable `.well-known/openid-configuration` discovery document.
- `authorization_code` grant.
- ID tokens signed with `RS256` (read from the `jwks_uri` in the discovery doc).
- `client_secret_post` for token endpoint authentication.
- Scopes `openid`, `profile`, `email`.
- A claim usable as the username: either `sub` directly (when it's a stable handle like `alice`) or another claim (`preferred_username`, `email`, …) you point LemonLDAP at when `sub` is opaque (see [When the OP's `sub` is a UUID](#when-the-ops-sub-is-a-uuid)).

Any provider that ticks those boxes works: tested with the in-house LemonLDAP-NG OP (the `sign-up` portal at Linagora) and with Keycloak. Other compliant providers (Authentik, Dex, …) should work; you may need to adjust the claim mapping if their `sub` shape differs.

## Register the client at the OP

Before configuring the stack, register an OIDC client at the provider with:

| Setting | Value |
| --- | --- |
| Redirect URI | `https://auth.<BASE_DOMAIN>/?openidconnectcallback=1` |
| Grant types | `authorization_code` |
| Token endpoint auth method | `client_secret_post` |
| Scopes | `openid profile email` |

Note the resulting **client ID**, **client secret**, and the **discovery URL**.

## Configure the stack

In `.env`:

```ini
AUTH_MODE=OpenIDConnect
OIDC_OP_NAME=<short label, e.g. "company">
OIDC_OP_DISCOVERY_URL=<https://your-op/.well-known/openid-configuration>
OIDC_CLIENT_ID=<from the OP>
OIDC_CLIENT_SECRET=<from the OP>
```

`OIDC_OP_NAME` is a stable label that becomes a JSON key in the rendered config and shows up in logs. Pick something short.

Bring the auth stack up:

```bash
cd twake_auth
./compose-wrapper.sh up -d
```

The wrapper picks the OIDC template, fetches the discovery doc, and splices it into `lmConf-1.json` along with the client credentials. If switching from `LDAP` to `OpenIDConnect` mode on a running stack, see [`twake_auth/README.md`](../twake_auth/README.md) for the cached-config wipe step.

## Provision users

Each user that should be able to log in has to exist in the local LDAP with `uid` equal to the OP's `sub` for that user. Use the SCIM import (see [scim-import.md](scim-import.md)). If the OP's `sub` is opaque (a UUID), don't provision the UUID into LDAP, match on a friendly claim instead (see below).

## When the OP's `sub` is a UUID

Some providers (Keycloak, Authentik, Entra ID, …) put an opaque UUID in `sub`. LemonLDAP uses `sub` as the login identifier by default, so it would search LDAP for a UUID `uid` and every login would fail with `Wrong credentials`. Point LemonLDAP at a human-readable claim from the ID token (`preferred_username`, `email`, …) instead, and provision LDAP with that value.

Set `oidcOPMetaDataOptionsUserAttribute` in `twake_auth/config/lmConf-1.json.oidc.template`, under the `${OIDC_OP_NAME}` key (it's empty by default, which means `sub`):

```json
"oidcOPMetaDataOptionsUserAttribute" : "preferred_username",
```

LemonLDAP reads this claim straight from the decoded ID token payload, so the claim has to be present in the ID token. The resulting login identifier (`$user`) is matched against LDAP through the `LDAPFilter` (`(uid=$user)` or `(mail=$user)`). Provision each user with `uid` equal to that claim, not the `sub` UUID. The same value also has to land in cozy's `oidc_id` for that instance, otherwise the redirect loop in [Common failures](#common-failures) appears.

## Disabling TLS verification to the OP

If the external SSO provider serves HTTPS with a certificate the server doesn't trust (private CA, self-signed staging endpoint), LemonLDAP's calls to the discovery, JWKS, token, and userinfo endpoints fail at the TLS handshake. The fix is to install the OP's CA on the LemonLDAP container; only when that isn't possible, turn certificate checking off.

Set `lwpSslOpts` (empty by default, near the bottom of `twake_auth/config/lmConf-1.json.oidc.template`) to disable both peer and hostname verification:

```json
"lwpSslOpts" : {
   "SSL_verify_mode" : 0,
   "verify_hostname" : 0
},
```

This is global to every outbound HTTPS call LemonLDAP makes and removes protection against man-in-the-middle, so keep it to trusted networks and prefer trusting the CA in production.

## Applying template changes

Both edits above live in the template, not the rendered `config/lmConf-1.json`, which `compose-wrapper.sh render` overwrites on every `up`. The wrapper only splices the client ID, secret, and discovery doc into the rendered file, so it leaves these fields intact. After editing the template, re-render and recreate LemonLDAP:

```bash
cd twake_auth
./compose-wrapper.sh render
docker compose --env-file ../.env rm -fv lemonldap
./compose-wrapper.sh up -d
```

## Common failures

**"Error during authentication with OpenID Provider".** Generic error page. The real cause is in `docker logs lemonldap-ng`. Two patterns to recognise:

- A successful `User <name> connected from OpenIDConnect` followed by a failed `Bad (or expired) token` for the same state means the OIDC dance worked but the callback URL was replayed (browser back button, a downstream redirect loop, or a frontend that triggers the flow twice). State tokens are single-use; the first completion wins. If a redirect loop is involved, cozy is rejecting the LemonLDAP-issued ID token (see below).
- `Wrong credentials` after a successful OP authentication means the OP's `sub` doesn't match any LDAP entry. Either the user wasn't imported, or you're matching the wrong claim.

**Redirect loop between LemonLDAP and cozy.** Almost always `oidc_id` mismatch on the cozy instance. Verify:

```bash
docker exec cozyt cozy-stack instances ls --json | jq 'select(.domain == "<user>.<BASE_DOMAIN>")'
```

Either `oidc_id` doesn't match the OP's `sub` for that user, or the cozy context for the instance doesn't have `disable_password_authentication: true` in `cozy.yaml`. Easiest fix is to destroy the instance and re-import; legacy instances created before the OIDC fields existed need a one-shot `cozy-stack instances modify <domain> --oidc-id <sub>`.

**Container can't reach the OP** but the host can. Two different netns. See the UFW notes in [operations.md](operations.md).

## OP discovery is fetched once

The wrapper grabs the OP's discovery document at `up` time and inlines it. If the OP rotates endpoints or signing keys advertised through discovery, re-render and recreate LemonLDAP:

```bash
./compose-wrapper.sh render
docker compose --env-file ../.env rm -fv lemonldap
./compose-wrapper.sh up -d
```
