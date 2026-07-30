# Troubleshooting

Real-world traps hit while running the kickstart end-to-end. Each entry
lists the symptom, the root cause and the fix, so `grep` on the error
string lands directly on the resolution.

## LemonLDAP-NG ignores changes to `lmConf-1.json`

**Symptom.** You edit
`twake_auth/config/lmConf-1.json.ldap.template` (add an OIDC client,
change a portal option, tweak CSP), re-render via
`compose-wrapper.sh render`, restart the `lemonldap-ng` container — and
LLNG behaves as if nothing changed. `docker exec lemonldap-ng cat
/var/lib/lemonldap-ng/conf/lmConf-1.json` shows your new value, yet the
running portal serves the old one.

**Cause.** The LemonLDAP-NG conf backend is not "the mounted file". It
picks the file with the highest `cfgNum` field across every
`lmConf-N.json` sitting in the `/var/lib/lemonldap-ng/conf/` volume.
Any Manager UI edit (or previous automatic reload) writes a
`lmConf-2.json`, `lmConf-3.json`, … each with an incremented `cfgNum`.
Once you have `lmConf-7.json` with `cfgNum=7` in the volume, editing
`lmConf-1.json` back on the host (even mounted read-only) is ignored
until either the mounted file's `cfgNum` exceeds 7 or the higher-
numbered files are removed.

**Fix.** Either bump `cfgNum` in the rendered `lmConf-1.json` high
enough to beat what's in the volume:

```bash
# in the rendered file, before docker restart lemonldap-ng
jq '.cfgNum = 100' twake_auth/config/lmConf-1.json > /tmp/x && mv /tmp/x twake_auth/config/lmConf-1.json
```

or purge the stale higher-numbered files from inside the container:

```bash
docker exec lemonldap-ng bash -c 'rm -f /var/lib/lemonldap-ng/conf/lmConf-[2-9]*.json'
docker restart lemonldap-ng
```

Then verify with `docker exec lemonldap-ng ls /var/lib/lemonldap-ng/conf/`
that only your file remains, and re-check the affected portal
behaviour.

## Twake Calendar first-login shows a 404 loop

**Symptom.** A newly OIDC-provisioned user opens the Twake Calendar
frontend (`calendar-ng.<BASE_DOMAIN>`) and sees "Something went wrong
— Request failed with status code 404 Not Found: GET
https://tcalendar-side-service.<BASE_DOMAIN>/dav/calendars/<uid>.json".
The side-service logs read:

```
c.l.c.r.a.OidcEndpointsInfoResolver - Created user: <email>
c.l.c.r.DavProxy - Proxying DAV request GET /dav/calendars/<uid>.json
com.linagora.calendar.dav.CalendarNotFoundException: Calendar not found: <uid>/<uid>
```

The Mongo `esn_docker.users` collection contains the new user, but the
Mongo `sabre.calendarinstances` collection stays empty for that
principal. Sabre-dav returns 404 for the calendar-home the frontend
requests.

**Cause.** Calendar-home auto-provisioning is triggered by
`sabre-dav → side-service` callback, keyed on the `ESN_HOST` env of
the sabre-dav container. That env is templated as
`ESN_HOST=tcalendar-side-service.${BASE_DOMAIN}` in
`calendar_app/docker-compose.yml`. If the compose is invoked without
`--env-file ../.env` (e.g. `docker compose up sabre_dav` straight from
the sub-compose directory, common after a `docker compose pull` to
bump an image), `${BASE_DOMAIN}` resolves to the empty string. sabre
comes up with `ESN_HOST=tcalendar-side-service.` (trailing dot,
truncated hostname) and every callback fails silently.

**Fix.** Always drive the sub-compose through the top-level
`wrapper.sh` (which passes `--env-file ../.env`), or symlink each
sub-compose to the root `.env` so `docker compose` picks it up
automatically:

```bash
for d in cozy_stack twake_auth calendar_app onlyoffice_app tmail_app meet_app linshare_app; do
  ln -sf ../.env "$d/.env"
done
```

Then verify the container after any recreate:

```bash
docker exec sabre_dav printenv ESN_HOST   # should print tcalendar-side-service.<full-BASE_DOMAIN>
```

If a user was already partially provisioned during the broken window,
also clear the incomplete state so the next OIDC callback
re-provisions cleanly:

```bash
docker exec mongodb mongosh -u mongoroot -p password --authenticationDatabase admin --eval '
  db.getSiblingDB("esn_docker").users.deleteMany({ email: "<email>" });
  db.getSiblingDB("sabre").calendarinstances.deleteMany({ principaluri: /<uid>/ });
'
docker restart tcalendar-side-service   # drop the side-service in-memory cache keyed on the deleted <uid>
```

The user must also drop the browser session on the frontend
subdomain — Cozy logout does not clear the localStorage-held JWT on
`calendar-ng.<BASE_DOMAIN>`. Easiest is an incognito window.

## Twake Calendar rejects users whose mail domain is unknown

**Symptom.** OIDC login flows for a user whose email domain is *not*
`${BASE_DOMAIN}` fail on the very first `/api/user` call, or
side-service logs

```
c.l.c.r.a.OidcEndpointsInfoResolver - Failed to provisioning user: <email>
com.linagora.calendar.storage.exception.DomainNotFoundException: <domain> does not exist
```

**Cause.** The side-service keeps a per-domain allow-list. Only the
`${BASE_DOMAIN}` (mail domain of the kickstart) is registered on
first boot. Anyone federating in from a different mail domain (the
common case with external OIDC identity providers, e.g. LemonLDAP-NG
against corporate LDAP) is rejected.

**Fix.** Register the additional domain(s) via the side-service
web-admin API:

```bash
docker exec tcalendar-side-service curl -sX PUT http://localhost:8000/domains/<domain>
docker exec tcalendar-side-service curl -s   http://localhost:8000/domains
# ["<BASE_DOMAIN>","<domain>"]
```

There is no UI for this in the kickstart. Bootstrap the domain list
before you first click into the Calendar tile with an external user.

## `linagora/sabre-dav` vs `linagora/esn-sabre`

**Confusion.** The GitHub repo `github.com/linagora/sabre-dav` last
saw a commit in 2022 and is a fork of the abandoned
`fruux/sabre-dav` PHP library. Following its docs to "update the
CalDAV backend" is a dead end.

The image that this stack actually runs is
`linagora/esn-sabre`, built from `github.com/linagora/esn-sabre` —
still actively maintained (weekly releases, cadenced at each
`branch-master` tag on Docker Hub). Bump via the tag on the
`calendar_app/sabre_dav` image, not by rebuilding from the sabre-dav
repo.

The "esn-" prefix is legacy naming (OpenPaaS/ESN heritage) — the
project is the one to track.
