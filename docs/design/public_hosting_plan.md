# Off Tailscale: the R720 on the public internet

> **Status: PLANNED 2026-10-08, not started.** Written in plan mode and kept for a later build
> session. Slice 0 is the user's, at their own router; nothing in this plan gives Claude router
> access.

## Context

The user wants to leave Tailscale for good: "When this project is complete we won't be
using Tailscale. Let's get it to that point sooner rather than later." The way to do that
is a port forward on the home router, which puts the server on the open internet. CLAUDE.md
makes that conditional: the "Public-host hardening checklist (mandatory before any exposure
beyond Tailscale)" To-Do has to be done before the port opens.

**Decided (user, 2026-10-08):** dynamic home IP plus DDNS (no static IP); domain purchase
**on hold**; registration by **invite code**; **one cutover day** for every tester, with
Tailscale kept only for the operator's SSH.

**What the code says today (verified):**
- The login socket is plain `ws://` (`scripts/login.gd:402`). Inside Tailscale WireGuard
  encrypts it; on the internet every password and every connect token would travel readable.
- The auth server (`auth/mod.rs`, `tokio_tungstenite::accept_async`) has **no message-size
  cap, no handshake timeout, no per-IP connection cap**, and **no registration gate**.
- The login rate limiter exists but is switched off on the R720 (`PD_NO_RATE_LIMIT=1`).
- The world address reaches clients inside the signed connect token as a fixed IP
  (`world/mod.rs::mint_connect_token`, `PROJECTDAWN_WORLD_ENDPOINT` parsed as a
  `SocketAddr`), and renet's netcode server takes its public address once, at construction,
  then refuses any token naming another (`renetcode-2.0.0/src/server.rs` ~259,
  `NotInHostList`; no setter). **A changed home IP therefore needs a server restart.** Every
  live connection breaks the moment the IP changes anyway, so the plan makes that restart
  safe rather than trying to avoid it.
- The world UDP channel needs no extra encryption: renet runs netcode in Secure mode
  (boot log "renet 2.0, Secure"), which encrypts and authenticates every packet with keys
  carried in the connect token. That is safe once the token itself travels over TLS, which is
  this plan's job. (`server_design.md` line 96 says "DTLS or QUIC for gameplay"; it will be
  corrected.)

## The shape

```
player ──TLS (wss, TCP 443)──> router ──> Caddy on the R720 ──> auth 127.0.0.1:8765
player ──netcode UDP 7777────> router ──> world 0.0.0.0:7777
operator ──SSH over Tailscale only (unchanged)
```

- **Name:** a free DDNS hostname (DuckDNS, e.g. `projectdawn.duckdns.org`), kept pointed at
  the home IP by a 5-minute updater on the R720. This honours the domain hold: nothing is
  bought, and a bought domain later is one DNS record plus one Caddyfile line, no code.
- **TLS:** Caddy terminates `wss://` on 443 and proxies to the auth server, which binds
  loopback only. Caddy gets and renews the Let's Encrypt certificate by itself through the
  TLS-ALPN challenge on 443, so port 80 stays closed and renewals never restart the game
  server (there is no graceful shutdown).
- **Router:** forward TCP 443 and UDP 7777 to the R720's reserved LAN address. Nothing else.

## Slices

### Slice 0. Find the blockers (user only, about an hour; nothing changes yet)
**Claude never touches the router.** The user logs into their own router's admin page, does
the steps below by hand, and reports back two things: whether the two addresses in step 2
match, and the reserved LAN address from step 3. No credential, screenshot or remote access
is shared; every router change in this plan (here and in slice 4) is the user's own hands.
**Found 2026-10-08 (from the R720):** the outside world sees a public IPv4 (`98.50.18.x`,
Comcast; not a CGNAT or private range), and the R720 has its own **global IPv6 address**
(`2601:…`). Still to confirm in the router: its WAN page shows the same `98.50.18.x`
(if it shows `100.64`-`100.127` or a private range, CGNAT or double NAT is in the way).
**IPv6 consequence for slices 1 and 4:** over IPv6 there is no NAT and no port forward; the
R720 is directly addressable, so UFW alone guards it. Decide deliberately: either publish an
AAAA record and allow 443/7777 on IPv6 too (the limiter's /64 keying then matters from day
one), or keep the DDNS name IPv4-only and keep UFW denying all IPv6 inbound except SSH on
`tailscale0`. Either way, verify from outside that nothing else answers on the IPv6 address.
1. The user's own router login (the runbook's open **H6** has waited on it since August).
2. **CGNAT check:** compare the WAN address shown on the router's status page with
   `curl -s ifconfig.me` run on the R720. If they differ, the ISP shares one public IP between
   customers and no port forward can work; the plan then needs the ISP's public-IP option or
   a relay, and stops here until that is settled.
3. **H6:** reserve the R720's LAN address (MAC `b8:ca:3a:f7:35:92`).
4. **Hairpin check:** whether the router lets a LAN machine reach the public IP (NAT
   loopback). If not, the operator plays from home through a hosts-file line pointing the
   DDNS name at the LAN address.
5. Create the DuckDNS name and token.

### Slice 1. Harden the login service (server, Claude; about 1.5 days; tests for each)
- **Socket limits** in `auth/mod.rs`: `accept_async_with_config` with a 64 KB message and
  frame cap (default is 64 MB), a 10 s handshake timeout, an idle timeout, and a per-IP cap on
  concurrent connections.
- **Real client IP behind Caddy:** `accept_hdr_async` reads `X-Forwarded-For` **only when the
  TCP peer is loopback** (Caddy); from anywhere else the header is ignored, so a forged one
  buys nothing. The limiter keys on that address.
- **Rate limiter back on** (`LoginRateLimiter`): key IPv6 by its /64, add a global cap on
  attempts per window, and add a per-account budget (the hardening list's items 1, 3, 4).
- **Ban answer (item 2):** a banned account currently answers differently and faster. Make a
  ban look like any failed login until the password has been verified, at the same Argon2
  cost, so the answer is never an oracle for "this account exists".
- **Invite codes (decided):** migration adding an `invites` table (code, created, redeemed
  by, revoked); `Register` gains a required `invite` field (auth is JSON, so an old client
  gets a clear "needs an invite code" refusal); the code is checked and burned **in the same
  transaction** that creates the account, so one code makes one account even under a race.
  New ops bin `invite` (`new [n]`, `list`, `revoke <code>`) beside `admin_account`; codes are
  128-bit random, shown once. The migration is forward-only like every other; an older binary
  will not boot on the migrated `world.db` (noted on the deploy).

### Slice 2. The world side (server, Claude; about half a day)
- `PROJECTDAWN_WORLD_ENDPOINT` accepts `host:port`; the server resolves the name at boot
  for the token and for netcode's host list.
- **Address watch:** re-resolve every 5 minutes; on a change, tell every player ("The server
  is restarting for a network change"), run the 60 s checkpoint path immediately
  (`save_stores_atomic` for every connection, the same write the checkpoint uses), and exit
  non-zero so systemd restarts it with the new address. The restart saves everything first,
  so nobody loses progress (players reconnect after about a minute).
- **Intent rate caps** (item 4 and finding 10c): per-connection token buckets on the
  inventory family and the cosmetic broadcasts (Hit / Miss / CastStart fan-outs), dropped
  silently past the cap, as a forged client is the only one that reaches it.

### Slice 3. The client (Claude; half a day; one export)
- `login.gd`: connect with `wss://` for any host that is not `127.0.0.1` / `localhost`
  (those keep `ws://` for the local dev server); a bare name means port 443. Godot's
  `WebSocketPeer` verifies the certificate against its built-in CA bundle, so no setting
  changes.
- An **invite code** field on the Register panel.
- The default server field becomes the DDNS name.
- `README_FOR_TESTERS.md` loses its Tailscale steps.

### Slice 4. The host (user runs the commands Claude writes, and sets the router forward by hand; about 2 hours)
- Install Caddy (Ubuntu package); a five-line Caddyfile: the DDNS name, `reverse_proxy
  127.0.0.1:8765`.
- `.env`: `PROJECTDAWN_AUTH_BIND=127.0.0.1:8765`,
  `PROJECTDAWN_WORLD_ENDPOINT=<ddns name>:7777`, **remove `PD_NO_RATE_LIMIT`**.
- DuckDNS updater as a systemd timer.
- UFW: allow `443/tcp` and `7777/udp`; SSH stays allowed **only on `tailscale0`** (it is
  Tailscale-only today; the plan keeps it that way).
- Router: forward TCP 443 and UDP 7777 to the reserved address.
- **Outside test before anyone is told:** from a phone hotspot (off the home network), log in,
  enter the world, move, cast. Then a port scan from outside shows exactly 443 and 7777.

### Slice 5. Cutover day (one announced evening)
Redeploy (slices 1 and 2), export (slice 3), mint an invite code per tester, send the new
build and code, remove the Tailscale node shares, raise `PROJECTDAWN_MIN_CLIENT_VERSION` so
an old build gets a clear refusal. **Candidate date: the Oct 22 bump day** already on the
planner (the trade window's protocol bump needs every tester on a new build anyway); one
build change for the testers instead of two.

## Exploit ledger (becomes the test list)
1. Passwords and connect tokens never cross the internet unencrypted (wss only; the auth port
   itself is not exposed, Caddy is).
2. A forged `X-Forwarded-For` from outside changes nothing (only loopback is trusted).
3. Password guessing is metered per IP, per /64, per account and globally.
4. A huge or slow-loris login connection is cut off (size cap, handshake and idle timeouts,
   per-IP connection cap).
5. No account without an invite; one code makes one account, even when two registrations race.
6. A ban is not an account-existence oracle.
7. A home IP change loses no progress (checkpoint before the restart).
8. Nothing but 443/tcp and 7777/udp is reachable from outside; SSH never is.

## Paperwork in the same pass
The To-Do's "Public-host hardening checklist" entry (rewritten as this plan's slices; TLS and
items 1 to 4 built, items marked "later" in `server_design.md` stay later); `server_design.md`
(TLS line, the netcode note, the "friends-only alpha via Tailscale" scope line); CLAUDE.md
"Hosted server" (no longer Tailscale-only); `systems_overview.md`; `docs/reference/commands.md`
(the `invite` bin); `docs/deployment/` (untracked: `server_operations.md`,
`inviting_a_player.md` rewritten without Tailscale shares); the schedule detail (new build and
operate rows, a cutover row); a new `public_hosting_checklist.md` from the template.

## Verification
- `cargo test`: unit tests for the limiter keys (/64, global, per account), the
  forwarded-for trust rule, invite burn; integration tests for oversize and slow handshakes,
  a forged header from a non-loopback peer, register without / with a reused / with a revoked
  code, a ban answering like a wrong password, and the address-watch path (a changed
  resolution triggers the checkpoint and a clean exit). Each test written to fail first.
- Client: a headless probe for the `ws` / `wss` choice and the invite field.
- Host: the hotspot test and the outside port scan above; the boot line shows
  `rate_limit=true`, `dev_cmds=false`, the DDNS name as world endpoint.
- Playtest: `public_hosting_checklist.md` on cutover day, with a tester outside the home
  network.

## Order and size
Slice 0 first (it can kill the plan if the ISP uses CGNAT). Then slices 1 to 3 in the build
lane (about 2.5 Claude days, no user time), slice 4 as one sitting (about 2 hours), slice 5 on
the chosen day. Nothing in slices 1 to 3 changes the running R720 until the cutover deploy.
