# twake_auth — authentication

This stack ships LemonLDAP-NG as the SSO portal for everything else (cozy, tmail, calendar, …). The portal authenticates users itself, against either:

- **the local LDAP** that we populate via SCIM (the default), or
- **an external OIDC provider** that already owns the user's identity.

The choice is a single `.env` variable. The pieces inside the container, and the integration with the downstream apps, don't change.

## When to pick which

Internal LDAP is what you want for self-contained deployments — demo environments, single-tenant POCs, anything where the LDAP we provision is the source of truth for who can log in.

External OIDC is for federated deployments where your users already live in another identity system and you don't want to copy passwords into the local LDAP. The external provider validates credentials and issues a token; LemonLDAP-NG accepts the token, extracts the `sub` claim, and looks up the matching user in the local LDAP for attributes (`mail`, `displayName`, …) the downstream apps consume.

The local LDAP is therefore still required even in external-SSO mode — the SCIM gateway is how you populate it. See `scripts/README.md` for that.

## What you have to do at the OP

Register an OIDC client with the external provider and have ready:

- **Redirect URI** — `https://auth.<BASE_DOMAIN>/?openidconnectcallback=1`
- **Grant type** — `authorization_code`
- **Scopes** — `openid profile email`
- **Client authentication method** — `client_secret_post`

The OP gives you back a client ID, a client secret, and an issuer URL. Those go in `.env`.

You also have to provision your users into the local LDAP with `uid` equal to whatever the OP returns as `sub`. The simplest way is the SCIM endpoint already documented in `scripts/README.md` — for a user whose OP-side `sub` is `alice`, send a SCIM `POST` with `userName: "alice"`. If your OP's `sub` is opaque (a UUID, an internal id), and you'd rather match users by email or username, change the OIDC mapping in `twake_auth/config/lmConf-1.json.oidc.template` (`oidcOPMetaDataExportedVars.<OP>.uid`) to the claim you want.

## How the user identity flows

LemonLDAP-NG stores the principal user id in a session attribute called `_user`. With `AUTH_MODE=OpenIDConnect`, the value comes from whichever OIDC claim is mapped to `uid` in `oidcOPMetaDataExportedVars.<OP>` (we map `uid: sub` by default, so `_user` is the OP's `sub`). With `AUTH_MODE=LDAP`, `_user` is the LDAP `uid` returned by the bind step.

The OIDC template pins lemonldap's `whatToTrace` to `_user` directly. lemonldap-ng's default macro for `_whatToTrace` would otherwise append `@<oidc-op>` to disambiguate users across multiple auth sources — useful in federations, but it produces a `sub` claim that no longer matches the bare `uid` we provisioned in the local LDAP. Pinning to `_user` means the same value travels end-to-end:

```
OP's sub  →  lemonldap _user  →  whatToTrace  →  sub claim on the tokens
                                                  lemonldap issues to cozy /
                                                  tmail / calendar / …
```

That value matches the `oidc_id` set on each per-user cozy instance during SCIM provisioning, so apps recognise the session without manual fix-ups. If you change the OIDC `uid` mapping, double-check downstream apps still see the value they expect.

## Configuring `.env`

Five keys control the auth backend. All four `OIDC_*` values are ignored when `AUTH_MODE=LDAP`, so the defaults below are safe to ship as-is:

```
AUTH_MODE=LDAP
OIDC_OP_NAME=
OIDC_OP_DISCOVERY_URL=
OIDC_CLIENT_ID=
OIDC_CLIENT_SECRET=
```

To switch to external SSO:

```
AUTH_MODE=OpenIDConnect
OIDC_OP_NAME=staging
OIDC_OP_DISCOVERY_URL=https://your-op.example.org/.well-known/openid-configuration
OIDC_CLIENT_ID=<from the OP>
OIDC_CLIENT_SECRET=<from the OP>
```

`OIDC_OP_NAME` is just a label you pick — it becomes the JSON key under `oidcOPMetaData{ExportedVars,Options,JSON}` in the rendered config and shows up in the lemonldap logs. Use anything short and stable.

## Switching modes

Run the wrapper. It picks the right template based on `AUTH_MODE`, fetches the discovery doc at startup if you're going OIDC, and renders `lmConf-1.json`:

```bash
./compose-wrapper.sh up -d
```

If lemonldap-ng has been up before in the other mode, **wipe its config volume first**. Once lemonldap boots it caches its config inside the container as `lmConf-2.json` and refuses to pick up changes to the bind-mounted `lmConf-1.json` until that cached file is gone:

```bash
docker compose --env-file ../.env stop lemonldap
docker compose --env-file ../.env rm -fv lemonldap
./compose-wrapper.sh up -d
```

To render the config without touching the container (handy while iterating on `.env`):

```bash
./compose-wrapper.sh render
```

## Caveats

- The OP discovery document is fetched once at `up` time. If the OP rotates its endpoints (`token_endpoint`, `jwks_uri`, …) you have to re-render to pick up the new doc.
- The `userDB` stays on `LDAP` in OIDC mode; the OP only owns authentication, not the user attributes downstream apps consume. If a user can authenticate at the OP but isn't present in the local LDAP, lemonldap responds with `Wrong credentials`. That's by design — provision via SCIM first.
