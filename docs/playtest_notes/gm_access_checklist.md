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
- [x] **Start the server with `PD_DEV_CMDS` unset** → boot log shows `dev_cmds=false`. notes:
- [x] **`grant_gm -- <gmuser> on`** → prints "Set GM … now true"; running `grant_gm` (list) shows
  `[GM]` on that account. notes:
- [x] **A second, non-GM account is ready** to log in with. notes:

## 1 — GM account gets the tools
- [x] **Log in on the GM account** (a fresh login, AFTER the grant — the flag is read at login);
  server.log logs `GM account connected`. notes:
- [x] **`/give <item name> 1`** in chat (use a name specific enough to match ONE item; an ambiguous
  substring just lists candidates and bails) → the item appears in your inventory. notes:
- [x] **Test Panel "Give Selected Item"** (pick one from the list) → it lands in your bags. notes:
- [x] **Test Panel "Level Up"** (or **"Grant 250 XP"**) → you gain a server-authoritative level / XP. notes:
- [x] **Take some damage first** (spawn a mob and let it hit you), then **Test Panel "Full Heal"**
  → HP/MP refill and STAY (no snap-back). notes:
- [x] **Test Panel "Spawn Normal"** → a real world mob appears (killable, drops loot, gives XP). notes:

## 2 — Plain account is refused (the security check)
- [x] **Log in on the NON-GM account** → server.log does NOT log `GM account connected` for it. notes:
- [x] **`/give <item name> 1`** → the client optimistically prints "Requested … from server", but
  **NO item actually appears** (the server ignored it — the chat line is not proof it worked). notes:
- [x] **Test Panel "Level Up" / "Grant 250 XP"** → no level gained, no XP. notes:
- [x] **Take some damage, then "Full Heal"** → the bar may twitch client-side then snaps back
  (server did nothing). notes: Full Heal still works
- [x] **Test Panel "Spawn Normal"** → no real (server) mob to fight; server.log shows no dev-spawn. notes:
- [x] **server.log** shows no give / level / spawn applied for this account. notes: Please review.

## 3 — Revoke works
- [x] **`grant_gm -- <gmuser> off`**, then the GM account **re-logs** → its dev commands no
  longer work (back to plain). notes:

## 4 — Regression: local dev mode is unchanged
- [x] **Restart the server WITH `$env:PD_DEV_CMDS='1'`** (boot log `dev_cmds=true`). notes:
- [x] **The NON-GM account can now use `/give` etc.** — dev mode makes everyone a dev, exactly as
  before this change. notes:

## 5 — The `grant_gm` tool itself
- [x] **`grant_gm`** (no args) lists every account with `[GM]` markers. notes:
- [x] **Granting an already-GM account** prints "already GM"; **a bad username** errors cleanly. notes:
- [x] **A grant while that character is ALREADY logged in** does NOT take effect until it re-logs
  (the flag is read at world-token mint). notes:

## Notes / observations
- Some parts of the Test Panel are still working for the non-GM account.  Trigger Death is one that is still functional.
