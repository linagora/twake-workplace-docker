# ldap-rest patch (cozyProvision)

Temporary build context for the `ldap-rest` service. The Dockerfile here
clones the `feat/twake-cozy-provision` branch of
[`linagora/ldap-rest`](https://github.com/linagora/ldap-rest) (open as
[PR #63](https://github.com/linagora/ldap-rest/pull/63)) and produces an
image equivalent to `yadd/ldap-rest:0.3.1` with the new
`core/twake/cozyProvision` plugin baked in.

That plugin hooks the SCIM lifecycle:

- **`scimusercreatedone`** → `POST /instances` on the cozy-stack admin
  API (`http://cozyt:6060`) to provision a new instance, then
  publishes `auth` / `user.created` on RabbitMQ.
- **`scimuserdeletedone`** → publishes `b2b` / `domain.user.deleted` on
  RabbitMQ so peer cozy instances drop the deleted user's contact card.

Configuration env vars (set in `twake_auth/docker-compose.yml`):

| Var                        | Source                                                        |
| -------------------------- | ------------------------------------------------------------- |
| `DM_COZY_ADMIN_URL`        | `http://cozyt:6060`                                           |
| `DM_COZY_ADMIN_USER`       | `admin`                                                       |
| `DM_COZY_ADMIN_PASSPHRASE` | `${COZY_ADMIN_PASSPHRASE}` (`.env`)                           |
| `DM_COZY_ORG_ID`           | `${COZY_ORG_ID}` (`.env`)                                     |
| `DM_COZY_ORG_DOMAIN`       | `${BASE_DOMAIN}` (`.env`)                                     |
| `DM_RABBITMQ_URL`          | `amqp://${RABBITMQ_USER}:${RABBITMQ_PASSWORD}@rabbitmq:5672/` |

## Removing this patch

Once `ldap-rest` 0.3.2 (or whatever version ships PR #63) is published
to npm and a corresponding `yadd/ldap-rest:<tag>` image is pushed:

1. In `twake_auth/docker-compose.yml`, replace the `build:` block with
   `image: yadd/ldap-rest:<tag>`.
2. Delete this directory (`twake_auth/ldap-rest/`).
3. The env vars in `.env` and the plugin entry in `DM_PLUGINS` stay as
   they are — they describe the runtime, not the patch.

## Build args

The Dockerfile exposes two build args if you ever need to point it at a
different fork or branch:

- `LDAP_REST_REPO` — defaults to `https://github.com/linagora/ldap-rest.git`
- `LDAP_REST_REF` — defaults to `feat/twake-cozy-provision`
