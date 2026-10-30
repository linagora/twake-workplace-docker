# Twake Chat side service

`twake-chat-side-service` gives Twake Chat its call tokens. Chat finds it in the
well-known of Synapse (`org.matrix.msc4143.rtc_foci`) and asks
`https://matrix-rtc.${BASE_DOMAIN}/sfu/get`. The service checks that the caller is
in the room, as a Synapse application service, and asks Meet for the LiveKit
token of the call. Its own deployment guide:
[`docs/deploy.md`](https://github.com/linagora/twake-chat-side-service/blob/7240d4ed5049258a1d99e5371d85976e5efb9f90/docs/deploy.md).

- Meet needs its external API (`EXTERNAL_API_ENABLED`, `APPLICATION_ENABLED`),
  `APPLICATION_ALLOW_USER_CREATION`, and an application with the scopes
  `rooms:create` and `rooms:livekit_token`. `meet_app` sets none of them.
- In `.env`, set `TWAKE_CHAT_SIDE_SERVICE_AS_TOKEN` and
  `TWAKE_CHAT_SIDE_SERVICE_HS_TOKEN` (`openssl rand -hex 32`) and the three
  `TWAKE_CHAT_SIDE_SERVICE_MEET_*`: the id and secret of that application, and
  the email of the owner of the call rooms. Then start `chat_app`. Without the AS
  token, Synapse keeps its usual configuration and the service is not part of
  the stack; without the Meet settings, `docker compose` stops and names the
  missing one.
- The AS token lets the service act as any user of Synapse: keep it as secret as
  an admin token.
- `TWAKE_CHAT_SIDE_SERVICE_IMAGE` replaces the image, such as with a local build.
- The Meet of `meet_app` is the upstream `lasuite/meet-backend`, which has no
  `livekit-token/` route: the service answers 502 until the Meet fork is deployed.
- On a running stack, after changing these settings: `./compose-wrapper.sh up -d`
  in `chat_app` (it renders the Synapse configuration, creates the service and
  recreates chat-react when its profile is on), then
  `docker restart chat_app-synapse-1`: Synapse reads
  its configuration and the registrations at startup only.
- After removing the AS token, `./compose-wrapper.sh down --remove-orphans`
  removes the service's container.
