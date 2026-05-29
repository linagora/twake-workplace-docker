# Cross-instance sharing

When a user shares a drive or folder with another user, the owner's cozy-stack
opens an HTTPS connection to the recipient instance by its public hostname
(`https://<recipient>.${BASE_DOMAIN}`) and pushes the sharing over a direct
stack-to-stack call. If that call cannot complete, cozy-stack silently falls
back to sending an email invitation; on a deployment with no working SMTP the
share then never reaches the recipient and stays `pending`.

Auto-acceptance (no manual click, no email) is already wired in this stack:
`contexts.default.sharing` sets `auto_accept_trusted` and
`auto_accept_trusted_contacts` to true with `${BASE_DOMAIN}` as a trusted domain
(see [cozy-defaults.md](cozy-defaults.md)), and every provisioned instance shares
the same `org_id` / `org_domain` so users count as trusted contacts of each
other. What is left to the operator is making the direct stack-to-stack call
succeed.

## The four invariants

The stack-to-stack PUT to `https://<recipient>.${BASE_DOMAIN}` succeeds only when
all four hold. Most sharing problems are one of these failing.

1. **Resolves.** The recipient hostname resolves to an IP from *inside* the
   cozy container (not just on the host; containers use a different netns).
2. **Reachable at a public IP.** cozy-stack's `safehttp` refuses to dial
   RFC-1918 addresses (`10/8`, `172.16/12`, `192.168/16`) as SSRF protection,
   and this check has no override: a private address is rejected even in
   development mode. Loopback (`127.0.0.1`) is rejected too on a production
   build, but is allowed in development mode. So the recipient must be reachable
   at a public IP, or, on a single host only, at loopback with the stack in
   development mode.
3. **Hairpin.** Packets actually arrive. On a single host the recipient
   hostname resolves to that host's own public IP, so the connection has to NAT
   out and come back (the hairpin path). `scripts/twake preflight` checks this.
4. **Certificate trusted.** cozy-stack uses the system trust store with no
   "skip verification" option. The recipient's TLS certificate must chain to a
   CA present in the cozy container's trust store. The entrypoint runs
   `update-ca-certificates` over `cozy_stack/config/root-ca.crt`, so a private
   CA mounted there is trusted; a publicly-issued certificate (Let's Encrypt)
   is trusted out of the box.

### One verification that covers all four

From inside the container, against any other instance:

```bash
docker exec cozyt curl -sS -o /dev/null -w "%{http_code}\n" \
  https://<other-user>.${BASE_DOMAIN}/
```

A `3xx` with **no** `-k` flag means all four invariants hold. If it only works
with `-k`, the certificate (invariant 4) is not trusted. A connect timeout
means the hairpin (invariant 3). A fast "connection refused" or a "not a public
IP" error in the cozy logs means the address is private or loopback on a
production build (invariant 2). `scripts/twake preflight` runs this same probe
(it covers invariants 1 to 4); a green preflight means sharing should work.

## Topologies

### Public domain (the supported path)

The wildcard `*.${BASE_DOMAIN}` resolves to a public IP. This is the only
topology that works across multiple hosts and the only one to use for anything
beyond a throwaway demo.

- Confirm DNS is actually public, not split-horizon: `nslookup
  <sub>.${BASE_DOMAIN} 1.1.1.1` must answer, not return `NXDOMAIN`. A name that
  resolves only on the host (local resolver or `/etc/hosts`) gives the host's
  own public IP via the hairpin on a single box, but does not work across hosts.
- Certificate: `CERT_MODE=letsencrypt` for a publicly-trusted leaf, or mount
  your CA at `cozy_stack/config/root-ca.crt` and have every instance
  certificate chain to it.
- Single host: ensure the hairpin works (`twake preflight`; UFW
  `DEFAULT_FORWARD_POLICY=ACCEPT`, `ip_forward=1`, see
  [operations.md](operations.md)).
- Production build. No development mode.

### Single host, loopback only (demo)

A self-contained demo on one machine, not multi-host and not production. Use it
only when no public domain is available.

- Hostnames resolve to `127.0.0.1` (`/etc/hosts`).
- cozy-stack must run in [development mode](#development-mode): loopback is
  rejected on a production build.
- Nothing listens on `127.0.0.1:443` inside the cozy container's network
  namespace (the reverse proxy is a separate container, on a private IP that
  `safehttp` blocks). So a TCP forwarder is needed in that namespace from
  `127.0.0.1:443` to the reverse proxy (TLS and SNI pass through, so the real
  certificate is served), plus a second forwarder for the accept callback to
  cozy-stack's own port. This is scaffolding for a demo, not a deployment.

### Private LAN, no public IP (not supported)

A domain that resolves to a private LAN address (`192.168.x`, `10.x`, `172.16.x`)
cannot work with the stock stack: `safehttp` rejects RFC-1918 addresses before
the development-mode bypass, so there is no flag or DNS trick that unblocks it.
Pointing the container DNS at the reverse proxy's bridge IP fails for the same
reason. The options are a public IP (above) or the single-host loopback demo.

## Development mode

Development mode is needed only by the single-host loopback demo; the
public-domain path stays on a production build. It is a runtime flag, no
rebuild: serving with `--dev` makes `safehttp` allow loopback dials (it does
**not** allow private IPs, and it does **not** change OIDC login). Keep it off
on any internet-facing deployment, it also relaxes transport security such as
the `Secure` flag on session cookies.

The cozy service is started by the entrypoint as `cozy-stack serve`. Override
that command to append `--dev` with a compose override file, so the tracked
`docker-compose.yml` is untouched:

```yaml
# cozy_stack/docker-compose.dev.yml
services:
  cozy-stack:
    command: ["cozy-stack", "serve", "--dev"]
```

```bash
cd cozy_stack
docker compose --env-file ../.env \
  -f docker-compose.yml -f docker-compose.dev.yml \
  up -d --no-deps --force-recreate cozy-stack
docker exec cozyt sh -c 'cat /proc/1/cmdline | tr "\0" " "'   # expect: cozy-stack serve --dev
```

## When a share is stuck

Recipient doesn't see a share that was created: the direct PUT failed and the
code fell back to email. Confirm and locate the failing invariant:

```bash
docker logs --since 10m cozyt 2>&1 \
  | grep -iE 'sharing-trust|trusted|auto-accept|sendmail|public IP|safehttp' \
  | grep -vE 'response: |request: '
```

`Member ... trusted` followed by `Auto-accepting ...` means the share reached
the recipient and the trust rule fired. A `sendmail` job or a "not a public IP"
error means the direct call never landed; work back through the four invariants
with the `curl` check above.

### Diagnosing DNS and resolution

Most "fell back to email" cases are invariant 1 or 2: the recipient name either
does not resolve inside the cozy container, or resolves to a private IP. Three
checks, from the most decisive down.

**What the cozy container resolves** (this is the resolution sharing actually
uses, the host's view does not matter):

```bash
docker exec cozyt getent hosts <other-user>.${BASE_DOMAIN}
```

- A **public IP** means resolution is fine; if sharing still fails the problem
  is the hairpin (invariant 3) or the certificate (invariant 4).
- A **private IP** (`10.x`, `172.16.x` to `172.31.x`, `192.168.x`) is the root
  cause: `safehttp` rejects it and there is no override. The domain needs to
  resolve to a public IP. See [Topologies](#topologies).
- **No output** means the container cannot resolve the name at all (for example
  the records exist only in the host's `/etc/hosts` or a split-horizon resolver
  the container does not use).

**Whether the zone is public** (catches split-horizon, where names resolve on
the host but not on the internet, so other hosts can never reach them):

```bash
nslookup <other-user>.${BASE_DOMAIN} 1.1.1.1
nslookup -type=NS ${BASE_DOMAIN} 1.1.1.1
```

`NXDOMAIN`, or an NS lookup that returns nothing, means the zone is not
delegated in public DNS. Such a deployment is local-only; cross-host sharing
cannot work until the domain is a real, delegated public zone with a wildcard
`A` record `*.${BASE_DOMAIN}` pointing at the host's public IP.

**Whether the host itself resolves it** (to compare against the container, and
confirm the wildcard is in place):

```bash
getent hosts <other-user>.${BASE_DOMAIN}
```

If the host resolves it but the container (first check) does not, the records
live somewhere the container does not consult; publish them in DNS rather than
in the host's `/etc/hosts`.
