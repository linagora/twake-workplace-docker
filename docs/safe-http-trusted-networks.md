# Letting cozy-stack reach the private network

Cozy-stack guards its outbound HTTP calls with an SSRF filter (`safehttp`). Any
request whose target resolves to a private or loopback address is refused with
`<ip> is not a public IP address`. That is the right default on the public
internet, but it breaks closed-network deployments: when the domains involved
resolve to local IPs, the addresses cozy-stack needs to reach are exactly the
ones the filter blocks.

The most visible casualty is **federated sharing**. When one instance shares
with another, cozy-stack connects to the recipient's URL
(`https://<user>.<BASE_DOMAIN>`). If that name resolves to a private or loopback
address, the share fails at the SSRF check. The same filter sits in front of
every other outbound request cozy-stack makes to a user-supplied URL.

## The setting

`SAFE_HTTP_TRUSTED_PRIVATE_NETWORKS` in `.env` is a whitespace-separated list of
CIDRs that `safehttp` is allowed to reach despite them being private or
loopback. It is rendered into `safe_http.trusted_private_networks` in
`cozy_stack/config/cozy.yaml`, which cozy-stack reads at startup. Invalid CIDRs
make cozy-stack refuse to boot, so a typo fails loudly instead of silently
disabling the exception.

```env
SAFE_HTTP_TRUSTED_PRIVATE_NETWORKS="10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 127.0.0.0/8"
```

## Choosing the CIDRs

Set this to the ranges the domains in your deployment actually resolve to. What
matters is the IP cozy-stack connects to, which is whatever DNS (or
`/etc/hosts`) returns for the recipient domain. Closed and air-gapped
deployments vary: some resolve their domains to RFC1918 addresses
(`10.x`, `172.16-31.x`, `192.168.x`), some to loopback (`127.x`). The default
covers all four so it works regardless, but you can trim it to only the ranges
you use.

A range only helps if something is actually listening at that address. Trusting
`127.0.0.0/8` lets cozy-stack reach a service on the same host's loopback (a
local reverse proxy, for instance); it does nothing if nothing listens there.

> WARNING: every CIDR here is an address cozy-stack will follow a user-supplied
> URL to, including the server's own loopback services (the admin API, other
> local daemons). Keep the list to what the deployment needs.

## Note for the local docker stack

In this repo's local setup the host `/etc/hosts` maps `*.${BASE_DOMAIN}` to
`127.0.0.1` (correct for the browser, since Traefik publishes 443 on the host).
That mapping leaks into the containers through the host resolver, so inside the
cozy-stack container the instance domains also resolve to `127.0.0.1`, where
nothing listens (cozy-stack is on `:8080`, Traefik is a separate container at
`172.27.0.100`). So a same-host share dials `127.0.0.1:443` and is refused at
the connection, before safehttp matters.

To make cross-instance traffic go through Traefik, the domains must resolve to
its address (`172.27.0.100`) inside the container: point the host `/etc/hosts`
entries at the bridge IP (works on Linux, where the bridge is routable from the
host; not on Docker Desktop), or run a small DNS resolver on the network that
answers `*.${BASE_DOMAIN}` with the Traefik IP. The whitelist is still required
on top of that, since `172.27.0.100` is a private address.

## Turning it off

Set it empty to restore cozy-stack's default (all private and loopback
addresses blocked):

```env
SAFE_HTTP_TRUSTED_PRIVATE_NETWORKS=""
```

Federated sharing and the other outbound features above will stop working on a
private-network deployment, which is the trade-off the SSRF filter exists to
make.

On a public, internet-facing deployment you should empty it: there the domains
resolve to public IPs, which safehttp already allows, so the allowlist buys
nothing and only widens SSRF exposure to your internal network. Keep entries
only on closed networks where the domains resolve to private or loopback IPs.
