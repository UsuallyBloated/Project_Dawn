# GM Access (per-account `is_gm`) Playtest Checklist — 2026-07-17

Verifies the Phase 1 keystone: dev/GM commands are gated on `is_dev || is_gm`, so a server
started WITHOUT `PD_DEV_CMDS` grants dev tools to a **GM account only**, while a plain account is
refused. Built server-only 2026-07-17 (server commit `82f55a9`): NO client/DLL/wire change, so
**no re-export and no gdext rebuild** — just run the latest server.

**Build / run prerequisites:**
- Server on branch `fix/xp-leveling-overflow` (current tree has the `is_gm` gate + `grant_gm`).
- Two of your accounts exist (`grant_gm` with no args lists them).
- Start the server with dev commands **OFF** — the whole point. From `F:\Projects\server`:
  `Remove-Item Env:\PD_DEV_CMDS -EA Ignore; cargo run -p projectdawn-server *>&1 | Tee-Object -FilePath server.log`.
  Confirm the boot line reads `dev_cmds=false`.
- Grant GM to ONE account, in a second window:
  `cargo run -p projectdawn-server --bin grant_gm -- <username> on`.

Server.log anchors: boot `dev_cmds=false`; a GM world login logs `GM account connected`.

## Setup
- [ ] **Start the server with `PD_DEV_CMDS` unset** → boot log shows `dev_cmds=false`. notes:
- [ ] **`grant_gm -- <gmuser> on`** → prints "Set GM … now true"; running `grant_gm` (list) shows
  `[GM]` on that account. notes:
- [ ] **A second, non-GM account is ready** to log in with. notes:

## 1 — GM account gets the tools
- [ ] **Log in on the GM account** (a fresh login, after the grant). notes:
- [ ] **`/give <item name> 1`** in chat → the item appears in your inventory (server granted it). notes:
- [ ] **Test Panel Full Heal** → HP/MP actually refill and STAY (no snap-back). notes:
- [ ] **Test Panel Level Up** → you gain a server-authoritative level. notes:
- [ ] **Dev-spawn a mob** → it appears as a real world mob (killable, drops loot, gives XP). notes:

## 2 — Plain account is refused (the security check)
- [ ] **Log in on the NON-GM account.** notes:
- [ ] **`/give <item name> 1`** → NO item appears (server ignored it). notes:
- [ ] **Test Panel Full Heal** → the bar may twitch client-side then snaps back (server did nothing). notes:
- [ ] **Test Panel Level Up** → no level gained. notes:
- [ ] **server.log** shows no give / heal / level applied for this account. notes:

## 3 — Revoke works
- [ ] **`grant_gm -- <gmuser> off`**, then the GM account **re-logs** → its dev commands no
  longer work (back to plain). notes:

## 4 — Regression: local dev mode is unchanged
- [ ] **Restart the server WITH `$env:PD_DEV_CMDS='1'`** (boot log `dev_cmds=true`). notes:
- [ ] **The NON-GM account can now use `/give` etc.** — dev mode makes everyone a dev, exactly as
  before this change. notes:

## 5 — The `grant_gm` tool itself
- [ ] **`grant_gm`** (no args) lists every account with `[GM]` markers. notes:
- [ ] **Granting an already-GM account** prints "already GM"; **a bad username** errors cleanly. notes:
- [ ] **A grant while that character is ALREADY logged in** does NOT take effect until it re-logs
  (the flag is read at world-token mint). notes:

## Notes / observations
-
