# Public Hosting (off Tailscale) Playtest Checklist — cutover day

The R720 moves from the private tailnet to the public internet: TLS in front of the login
socket, invite-gated registration, the limiter back on, and a world address that is a
name. Design: `docs/design/public_hosting_plan.md`. Server slices 1 and 2 and client
slice 3 were built 2026-10-12 on `feat/public-hosting` in both repos; this sheet is the
cutover evening, run once the user's host sitting (slice 4) is done.

**Prerequisites, all three:** the server built from `feat/public-hosting` (or the deploy
branch once it is merged) running on the R720 with Caddy in front; the client exported
from the same branch; the router forwarding TCP 443 and UDP 7777. **Deploy order:** the
server first (an old client still registers while `PROJECTDAWN_REQUIRE_INVITE` is unset),
then the export. Migration `0012_invites.sql` is forward-only: once this server has booted
on `world.db`, an older binary refuses to start on it.

| Thing | Where | Notes |
|---|---|---|
| Boot line | `journalctl -u projectdawn` | must read `rate_limit=true require_invite=true dev_cmds=false`, then `world address resolved` with the DDNS name and the public IPv4 |
| Invite codes | `cd /opt/projectdawn && cargo run -p projectdawn-server --bin invite -- new 1 for <name>` (or the built binary) | one per tester, shown once |
| Throttle lines | `auth attempt rejected — rate limited` with `budget=Source/Global/Account` and the client IP | the IP must be the tester's, never `127.0.0.1` |
| Intent drops | `intents dropped — over the per-connection budget` | should never appear for an honest client |
| Client URL rule | Server field `name` means `wss://name:443`; `127.0.0.1:8765` stays `ws://` | a typed `ws://` or `wss://` is kept as is |

## Setup
- [ ] Server on the R720 from `feat/public-hosting` (or later), `.env` carrying `PROJECTDAWN_AUTH_BIND=127.0.0.1:8765`, `PROJECTDAWN_WORLD_ENDPOINT=<ddns name>:7777`, `PROJECTDAWN_REQUIRE_INVITE=1`, and NO `PD_NO_RATE_LIMIT`. notes:
- [ ] Boot line shows `rate_limit=true require_invite=true dev_cmds=false`, and `world address resolved` names the DDNS name and the public IPv4. notes:
- [ ] Caddy serving the DDNS name on 443 with `reverse_proxy 127.0.0.1:8765`; `curl -sI https://<name>/` answers (any HTTP status) with a valid certificate. notes:
- [ ] Client exported from `feat/public-hosting` (login screen stamp names the commit). notes:
- [ ] One invite code minted per tester (`invite new 1 for <name>`), sent with the zip. notes:

## 1 — From outside the house (phone hotspot, off the home network)
- [ ] **Type only the DDNS name in Server, Register with the code** → `Account created. Logging in...`, then character select, no certificate warning anywhere. notes:
- [ ] **Create a character, Play, Enter World, walk, cast** → the world works as it did on the tailnet. notes:
- [ ] **`/ping` from the hotspot, after a minute in the world** → `Round trip to the server: N ms, packet loss N%.` with a real number (tens of ms, not 0), and the server log's `player link` line for that character shows about the same `rtt_ms`. notes:
- [ ] **Port scan from outside** (`nmap -p 1-65535 <name>` from the hotspot machine, or an online scanner) → exactly 443/tcp and 7777/udp answer; 8765 and 22 do not. notes:

## 2 — Invite codes
- [ ] **Register with the invite field empty** → `An invite code is required to register.`, no account. notes:
- [ ] **Register with a made-up code** → `That invite code is not valid.` notes:
- [ ] **Register with the real code** → account created; `invite` (list) shows the code `redeemed ... by <username>`. notes:
- [ ] **Register a second account with the same code** → `That invite code is not valid.` (one code, one account). notes:
- [ ] **`invite revoke <unused code>`, then register with it** → refused; `invite revoke <redeemed code>` says it cannot be revoked and points at `admin_account ban`. notes:
- [ ] **Log in on later launches with the invite field empty** → works; the field is not needed again. notes:

## 3 — The old build is gone
- [ ] **Launch the October 9 zip, log in against the DDNS name** → refused with `version_mismatch` (the host raised `PROJECTDAWN_MIN_CLIENT_VERSION`). notes:
- [ ] **Launch the October 9 zip against `100.93.108.112:8765`** → cannot reach (the node shares are removed, and the auth port now binds loopback). notes:

## 4 — The limits, from a real address
- [ ] **Six wrong passwords in a row** → the sixth says `Too many login attempts. Please wait a minute and try again.`; the log line reads `budget=Source` with the tester's public IP, never `127.0.0.1`. notes:
- [ ] **Right password after the minute** → logs in; the next wrong password is refused at `auth_failed` (the success cleared the budget). notes:
- [ ] **A banned throwaway account (`admin_account ban`), WRONG password** → `auth_failed`, the same as any wrong password. notes:
- [ ] **The same account, RIGHT password** → `banned: <reason>`. notes:
- [ ] **Leave the launcher on character select for 11 minutes, then click Play** → it reconnects on its own and Play works (the idle close costs nothing). notes:

## 5 — A network change (optional; only if the home IP really moves, or by pointing the DDNS name at a wrong address for six minutes on purpose)
- [ ] **The address watch fires** → everyone in the world sees `The server's network address changed. Restarting now; your character is saved...`, is kicked with the Restart reason, and the service is back within a minute (`journalctl`: `restart requested — everyone checkpointed`, then a fresh boot line). notes:
- [ ] **Log back in** → the character stands where it was, with its inventory and coin. notes:

## 6 — Regression: an ordinary evening
- [ ] **Four testers play for thirty minutes** → zero `intents dropped` lines and zero `rate limited` lines for them in the log. notes:
- [ ] **A Stack All across full bags, fast dragging, a crafting-materials give** → nothing refused, no desync. notes:
- [ ] **A clean `/camp` and a window-X logout** → both behave as before. notes:

## Notes / observations
-
