# Temporary patch image for ldap-rest until v0.3.2 is published.
#
# Builds the cozyProvision plugin (PR linagora/ldap-rest#63) from source,
# then drops the resulting tarball into a slim runtime so the SCIM lifecycle
# hooks (POST /instances on cozy-stack admin + AMQP publishes on the auth
# and b2b exchanges) are available in this deployment.
#
# Once 0.3.2 is released this whole directory can be removed and the
# `build:` directive in twake_auth/docker-compose.yml swapped back to
# `image: yadd/ldap-rest:0.3.2`.

ARG LDAP_REST_REPO=https://github.com/linagora/ldap-rest.git
ARG LDAP_REST_REF=master

# ---------- builder: clone the patched ldap-rest branch and pack it ----------
FROM node:22-alpine AS builder

ARG LDAP_REST_REPO
ARG LDAP_REST_REF

RUN apk add --no-cache git make

WORKDIR /src
RUN git clone --depth 1 --branch "${LDAP_REST_REF}" "${LDAP_REST_REPO}" . \
 && npm ci \
 && npm run build \
 && npm pack \
 && mv ldap-rest-*.tgz /tmp/ldap-rest.tgz

# ---------- runtime ----------
FROM node:22-alpine

WORKDIR /app

# wget keeps parity with upstream yadd/ldap-rest:0.3.x (used by healthcheck)
RUN apk add --no-cache wget

# Install the patched ldap-rest tarball. optionalDependencies pulls in
# @linagora/rabbitmq-client; we want it because the cozyProvision plugin
# uses it when DM_RABBITMQ_URL is set.
COPY --from=builder /tmp/ldap-rest.tgz /tmp/ldap-rest.tgz
RUN npm install --no-package-lock /tmp/ldap-rest.tgz \
 && rm -f /tmp/ldap-rest.tgz \
 && npm cache clean --force

EXPOSE 8081

CMD ["npx", "ldap-rest"]
