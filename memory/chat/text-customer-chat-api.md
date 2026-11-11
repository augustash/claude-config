---
name: Text (LiveChat) Customer Chat API in your own window
description: Credentials, token minting, availability and real-time quirks of Text's (formerly LiveChat) APIs when the reader chats in your own UI instead of the widget.
metadata:
  type: reference
---

Text (text.com, formerly LiveChat Inc.) lets a site run the reader's side of a live chat
in its own window while agents answer in Text's app. Verified end to end on Enterprise
Minnesota, 2026-11-10. Used by the [site-chat](../../skills/site-chat/SKILL.md) skill.

## Credentials: two kinds, and where to make them

- **The developer console redirects away** (platform.text.com/console sent us to the AI
  agent launch guide). Both credentials are made in the main app under **API access**.
- **Personal access token** (Basic `account_id:PAT`): Agent Chat and Configuration APIs,
  e.g. `list_archives`, `list_routing_statuses`. Scopes can't be edited after creation.
- **A PAT cannot mint customer tokens.** That needs an OAuth client (backend type) with
  **Customer tokens and identity** (`customers:own`), authorized once per environment
  (authorization code + PKCE at `accounts.livechat.com`, exchange at `/v2/token`).
  The agent token lasts 8h; the refresh token did **not** rotate on refresh.
- The redirect URI must match exactly; register one per environment.

## Minting a reader's token

`POST https://accounts.livechat.com/v2/customer/token` with `Authorization: Bearer
<agent token>` and a **JSON** body `{grant_type: "agent_token", client_id,
response_type: "token", organization_id}`. **Form-encoded returns 401
`identity_exception`**, the shape the docs suggest. Pass `entity_id` to keep the same
reader. Customer tokens last 4h.

## Is anyone available?

`GET api.livechatinc.com/v3.6/customer/action/get_dynamic_configuration?license_id=…&group_id=0`
needs no auth. `livechat.online_group_ids` lists online groups; **when nobody is
accepting, the key is absent, not empty**. Bots count as online, so it only means "a
person" with Text's AI agent switched off and dev seats not accepting. Set dev seats'
after-login status to don't-accept, and turn the AI agent off in the app.

## Real-time

The browser connects to `wss://api.livechatinc.com/v3.6/customer/rtm/ws?organization_id=…`,
sends `login` with `{token: "Bearer <customer token>"}`, pings every 15s. Agent messages,
typing and read receipts arrive instantly, so no polling and no host long connections.
Text pushes an automatic `incoming_greeting` (rich message) on chat start; ignore it or
have it turned off. Finished chats come back via Agent Chat `list_archives` with the PAT,
so a nightly pull needs no webhook endpoint.

Seats: one paid seat per answering person plus one for our dev account. With one
answering seat, routing and rotation are moot.
