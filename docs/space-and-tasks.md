# Twake Space and Twake Tasks (organization mode)

`space_app` runs [Twake Space](https://github.com/linagora/twake-space) on
`space.${BASE_DOMAIN}` and `tasks_app` runs
[Twake Tasks](https://github.com/linagora/twake-tasks) on `tasks.${BASE_DOMAIN}`.
A space has tabs, each one an app in a frame (Tasks, Mail, Chat, Drive), with
an overlay frame over the whole page for the app's windows and dialogs.

```bash
./wrapper.sh up --space -d                  # pulls in tasks, mail, chat, calendar, meet, auth, db
space_app/seed-space.sh "Demo"              # user1 admin, user2 editor
space_app/seed-space.sh "Roadmap" user2 user1 user3
```

## Organization mode

Twake Space and Twake Tasks refuse a user without an organization (the
`org_id` claim, HTTP 403).

- LDAP: `ldap-ensure` puts every account in `ORGANIZATION_ID` (`.env`,
  `twake-demo` by default), user1 as its owner (see the README).
- LemonLDAP exports it as `org_id` and `org_role`, and `entryUUID` as `uuid`,
  to the public clients `twakespace` and `twaketasks`. Their backends introspect
  the tokens with the confidential clients `twakespace-backend` and
  `twaketasks-backend`.
- RabbitMQ: the `space` and `admin-panel` exchanges join
  `RABBITMQ_DECLARE_EXCHANGES`.

The users stay under `ou=users`: the B2B tree (`ou=b2b`, an entry per
organization) is not set up, so ldap-rest's spaces plugin, and the
organization and user routes of the private B2B plugin that Twake Space calls,
are not either. As a result:

- a space cannot be created from the Twake Space UI (`POST /spaces` goes
  through ldap-rest);
- `space_app/seed-space.sh` stands in for ldap-rest and the Mail side service:
  it writes the organization in Twake Space's database (mail on), creates a
  team mailbox in TMail, publishes `twake.space.created` (Tasks creates the
  project and tells Twake Space) and the Mail resource
  (`com.twake.mail.space.provisioned.v1`);
- the nightly reconciliation of Tasks fails on ldap-rest and changes nothing.

## Images

- The Twake Space images on ghcr.io are private for now: `docker login ghcr.io`
  with an account that can read them, or build them from the repository and
  set `TWAKE_SPACE_BACKEND_IMAGE` and `TWAKE_SPACE_FRONTEND_IMAGE`:

  ```bash
  docker build -f apps/backend/Dockerfile -t twake-space-backend:main .
  docker build -f apps/frontend/Dockerfile -t twake-space-frontend:main .
  ```

  Until they are public, a plain `./wrapper.sh up` and `--full` leave
  `space_app` out: start it with `--space`.
- `TWAKE_TASKS_*_IMAGE` pin other Twake Tasks images.

## Tabs

- Tasks: `/embed/projects/<id>` of `tasks_app`, always on.
- Mail: the team mailbox facade of the React Twake Mail
  (`/embed/team-mailboxes/<root mailbox id>`), which the Flutter Twake Mail
  has not. Set `TWAKE_SPACE_MAIL_URL` to that app, or the tab says Mail is
  not set up. Team mailboxes need `acl.enabled=true` in
  `tmail_app/config/cassandra.properties`.
- Chat: `/embed/rooms/<Matrix space id>` of the React Twake Chat. Set
  `TWAKE_SPACE_CHAT_URL` to that app, or the tab says Chat is not set up. The
  `MATRIX_*` settings of the backend turn the tab on, and tom-bridge gives the
  ids of the Matrix spaces.
  - tom-bridge creates the Matrix space of each space and its General room
    ([linagora/ToM-Bridge#10](https://github.com/linagora/ToM-Bridge/pull/10),
    not released): set `TOM_BRIDGE_SPACES=true` and `TOM_BRIDGE_IMAGE` to an
    image that has it. Its registration reserves the `#twake-space-*` aliases.
  - tom-bridge also adds `@twakespace` (its `twakeSpaceUserId`) to each Matrix
    space. On a new stack nothing creates that account: tom-bridge logs at error
    level that it cannot join, and the members still get the space. On a stack
    that ran the former Twake Space application service, the account still
    exists and joins each new space at power level 50. Deactivating it is an
    option, with an admin token:
    `POST /_synapse/admin/v1/deactivate/@twakespace:${BASE_DOMAIN}`.
- Drive: each person's Drive (`<slug>-drive.${BASE_DOMAIN}`), which Twake
  Space may frame (`CSP_FRAME_SRC`).
- Calendar: `/embed/calendars/<team calendar id>` of `calendar_app`. The side
  service gives each space a team calendar from the `twake.space.*` events
  (`twakespace.enabled`), shares it with the members and tells Twake Space
  (`com.twake.calendar.space.provisioned.v1`). A space seeded before the side
  service ran has no team calendar until its next space event (see
  Upgrading).
- Meetings: the space header's video menu schedules a meeting in the team
  calendar, whose Meet room the side service creates through Meet's external
  API, and joins a room of `meet_app` in Twake Space's call window. The
  backend of `meet_app` registers the side service's Application at start,
  limited to the users of `MAIL_DOMAIN`.

## Upgrading

On a stack that ran before the Calendar tab:

- Generate `MEET_APPLICATION_JWT_SECRET_KEY` and `CALENDAR_MEET_CLIENT_SECRET`
  in `.env` (see the README): `meet_app` and `calendar_app` refuse to start
  without them.
- The side service moves to 2.5.0.1 and sabre to 2.5.0.1. Its event search
  index needs the steps of its
  [upgrade instructions](https://github.com/linagora/twake-calendar-side-service/blob/31fd14d8dbf4c1dc4b4316651f572a48a996a780/upgrade-instructions.md)
  for 2.4.3 (new fields and analyzer, then a reindex), on the OpenSearch of
  `tmail_app`. Without them, delegates and subscribers miss older events in
  search.
- Existing spaces get their team calendar from a replay of their
  `twake.space.created` event, sent to the side service's queue alone so that
  Tasks does not create a second project. The event is the one
  `seed-space.sh` publishes, with the space's id and members:

  ```bash
  R="docker exec rabbitmq rabbitmqadmin"
  $R declare exchange name=space-replay type=direct durable=false
  $R declare binding source=space-replay destination=tcalendar:twake-space routing_key=twake.space.created
  $R publish exchange=space-replay routing_key=twake.space.created payload="$EVENT"
  $R delete exchange name=space-replay
  ```

## Hosts

With `twake.local`, add `space.twake.local tasks.twake.local` to `/etc/hosts`.
