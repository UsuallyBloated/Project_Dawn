# Handoff — Loot / Group Polish (3 loose ends)

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client (this repo,
`F:\Projects\Project_Dawn`) + a Rust authoritative server (`F:\Projects\server`).
**Read `CLAUDE.md` first** — it's the contract (and it's now accurate: the server
runs a live world sim at wire **PD_W0014**).

This is a **small polish session** — three independent loose ends left from the
2026-06-15 group-loot + coin-drops feature. None is big; do any subset. They're
ordered easiest → hardest. Two need **no** wire/DLL change; one does.

## Context (what just shipped — read these)
- `docs/design/group_loot_and_coin.md` — the group-loot/coin design (ownership, RR/FFA,
  30 m coin split, `/autosplit`, leadership).
- `docs/playtest_notes/group_loot_coin_checklist.md` — two-client playtest, **all green**;
  the **"Round 2"** section at the bottom lists exactly these three deferred items.
- `docs/session_notes/session_2026_06_15.md` — the build (8 layers) + post-playtest fixes.
- `docs/concepts/architecture/systems_overview.md` → "Group loot rights & coin drops".

## Repos at handoff
| Repo | Path | Branch | State |
|---|---|---|---|
| Client | `F:\Projects\Project_Dawn` | `feature/ally-buff-routing` | clean; group-loot feature done |
| Server | `F:\Projects\server` | `feature/ally-buff-routing` | clean (ignore stray `*.exe`/`server.log`); wire PD_W0014 |

No git remotes — local-only. Run `git -C <each> status` / `log --oneline -10` before and
after. Server tests: `cargo test -p projectdawn-server` (130 lib tests pass; the
`world_two_clients.rs` pet/AOE failures are **pre-existing flaky** — see
`server/docs/flaky_integration_tests.md`; re-run failing tests individually before
blaming yourself). Client checks: `godot --headless --path . --quit` (no SCRIPT ERROR;
known-ignorable `time_of_day.gd:44` null `add_child` in `--script` mode only) and
`tools/currency_smoke.gd` → `CURRENCY_SMOKE_PASS`.

> **Wire/DLL gotcha (only Task 3 needs this):** PD_W0014 is shared by client + server.
> If you add/extend a wire message, rebuild the GDExtension DLL with
> `addons/gdext_net/build.ps1` (≈45 s) and **rebuild the server too** — a mismatched
> pair is rejected at connect (clean version error). Changing an existing gdext
> `#[signal]` requires a **lockstep** `net.gd` handler update + DLL rebuild, or it
> mismatches at runtime. The gdext-net source lives in the **server** repo
> (`crates/gdext-net/src/lib.rs`) and shares the `protocol` crate, so there's one Rust
> wire definition; the only hand-mirror is `scripts/net/protocol.gd` / `net.gd` signals.

---

## Task 1 — Drop an item to the ground (client UI only) — *no wire/DLL change*

**What's already there:** the whole drop path is built except the button to trigger it.
- Wire: `ClientWorldMsg::DropItem { … }` (`protocol/src/world.rs:403`).
- gdext sender: `send_drop_item(location, slot, count)` (`gdext-net/src/lib.rs:878`).
- Client wrapper: `Net.broadcast_drop_item(location, slot, count)` (`autoloads/net.gd:521`)
  — **currently has no caller.**
- Server: the `DropItem` handler spawns a **public** loot bag at the player's feet
  (`tick.rs` ~4438; `owner_killer = None` so anyone in range can pick it up — verified in
  the group-loot work).

**What's missing:** a UI affordance in the inventory / bag windows to invoke
`broadcast_drop_item`. Mirror the existing item interaction in
`scripts/inventory_window.gd` / `scripts/bag_window.gd` (they already do drag-drop +
right-click for use/equip — see the `MountManager` right-click branches added in Track
22.C as a precedent for adding an item context action). Pick the cleanest fit:
- **Recommended:** a right-click context-menu "Drop" on a slot (and bag slot), or a
  drag-out-of-window-to-world gesture if that's how the inventory already feels.
- Call `Net.broadcast_drop_item(location, slot, count)` where `location` is `"base"` or
  the bag ref the server expects (match how loot/move intents pass `SlotRef` —
  cross-check the server's `DropItem` arg shape so `location`/`slot` line up).

**Gotchas:** confirm the `location`/`slot` encoding the server expects (look at how
`broadcast_loot_item` / `MoveItem` pass slots). Don't double-decrement the local
inventory — in launcher mode the server is authoritative and fans an `InventoryDelta`
back; let that update the UI (don't optimistically remove the item, mirror how loot
pickup works in `RemoteLootBagManager`).

**Acceptance:** in launcher mode, a player can drop a stack to the ground → a loot bag
appears at their feet → another player (or themselves) can pick it up (it's public).
Headless boot clean.

---

## Task 2 — Defender sees incoming misses (PvP) — *likely no wire change*

**The report (playtest 8.3):** when B attacks A and **misses**, A doesn't see it. A
should get an "X misses you" combat-log line (helps situational awareness, esp. PvP).

**What's there:**
- Server fans misses via `handlers::fan_out_miss(server, &recipients, attacker, target)`
  — called from several combat paths (`tick.rs` ~1748 the generic fan-out; ~2169, ~2418,
  ~2454 the melee/range/PvP paths; "attack out of range, fanning Miss" at ~2452).
- Client: `Net.world_miss(attacker, target)` (`net.gd:69`) → `_on_miss` (`net.gd:807`).
  Find where `world_miss` is consumed and turned into a combat-log line (check
  `autoloads/net_combat_broadcaster.gd` and `CombatLog` usage).

**Investigate first (it's one of two bugs):**
1. **Server recipient gap** — does the `recipients` list passed to `fan_out_miss` on the
   PvP path include the **target** (defender)? Compare the PvE miss path (does a player
   see an enemy miss them today? if yes, PvE works) against the PvP path. If the
   defender isn't in `recipients`, add them.
2. **Client log filter** — if the defender *does* receive `world_miss` but nothing logs
   it, the combat-log handler is probably only rendering misses where the local player is
   the **attacker** ("You miss X"). Add the incoming case ("X misses you") keyed on
   `target == local player`. (Hit damage likely already shows incoming — mirror that.)

Likely a small fix in one of those two spots; **no new wire message** (the `Miss`
message already carries `attacker` + `target`). Confirm Hit already shows incoming
("X hits you") and make Miss symmetric.

**Acceptance:** two-client, B attacks A with `/pvp` on both — A sees "B misses you" (or
similar) in the combat log on each miss; existing "You miss X" still works.

---

## Task 3 — `/autosplit` toggle notifies the group — *needs a wire message + DLL rebuild*

**The report (playtest 4.1):** when a group member toggles `/autosplit`, the **whole
group** should see it (transparency — it affects whether they get coin from that
member's loots). Today the toggle only echoes locally on the toggler's client.

**What's there:**
- `/autosplit on|off` → `Net.broadcast_autosplit(on)` → server `ClientWorldMsg::SetAutosplit`
  handler sets `conn.autosplit` **inline in `handlers.rs`** (search `SetAutosplit`) and
  returns; only the toggler logs it (`hud.gd`).

**What to build** — fan a one-line notice to the toggler's group members. Two precedents
to combine (both from the group-loot work):
- **Server→client private string → combat log:** `ServerWorldMsg::LootRejected { reason }`
  + `handlers::send_loot_rejected` + gdext `loot_rejected` signal + `net.gd`
  `_on_loot_rejected` → `RemoteLootBagManager` logs it. Copy this shape for a
  `GroupNotice { text }` (or reuse a chat message if one is wired server→client).
- **Group enumeration:** `handlers::fan_group_roster` / `group_manager.group_of(cid)` show
  how to list a player's group members to fan to.

**Wiring note:** `SetAutosplit` is handled *inline* in `handlers.rs`, which doesn't have
`server` / `group_manager` / all `connections` in scope (those are the tick loop). So to
fan a group notice, route it like the **group intents**: have the `SetAutosplit` handler
return an `Outcome` (e.g. `Outcome::AutosplitNoticeIntent { char_id, on }`), queue it in
`tick.rs` (mirror `group_loot_mode_intents` — there's a tidy drain-loop pattern at the
"4hbb"/"4hbc" comments), and in the drain loop enumerate the player's group + fan the
notice (with the toggler's `conn.name`, e.g. "Aria set auto-split off"). Keep setting
`conn.autosplit` where it is (or move it into the drain loop — either works).

**Steps:** protocol `ServerWorldMsg::GroupNotice { text }` (append under PD_W0014) →
`send_group_notice` helper → tick drain-loop fan to group → gdext `group_notice(text)`
signal + decode/emit → `net.gd` `world_group_notice` signal + handler →
`GroupManager`/`RemoteLootBagManager`/`hud` logs it via `CombatLog`. **Rebuild the DLL.**

**Gotchas:** new signal = lockstep `net.gd` handler + DLL rebuild (see the wire gotcha
above). Don't notify on a no-op (only when the value actually changes), and don't notify
when the player is solo (no group). Decide whether the toggler also still gets their own
echo (they do today via `hud.gd` — avoid double-logging for them).

**Acceptance:** in a group, when one member `/autosplit off`, every member sees a line
like "Aria set auto-split off"; solo players see only their own echo; no double-log.

---

## Wrap-up (all tasks)
- Per the session workflow: append a session note to
  `docs/session_notes/session_YYYY_MM_DD.md`, add a `README.md` index row, and update the
  **"Round 2 — Deferred"** items in `group_loot_coin_checklist.md` (mark the ones you
  ship). Update `systems_overview.md` if you change behavior.
- Run `/code-review` if you touch 5+ files or core combat/inventory.
- A short two-client playtest checklist (or rows added to the existing one) for whatever
  you ship — these are all observable, human-verified behaviors.

## After this (ranked backlog, don't start without asking)
1. **Banker NPC** — one town NPC that does **both** zero-weight storage (deposit/withdraw,
   new DB table) **and** coin tier exchange (the coin-weight relief valve; `currency.md`
   specs the fee bands). The headline next-step now that coins drop + have weight. *(There
   is intentionally no separate "moneychanger" NPC — the Banker absorbs exchange; decided
   2026-06-16, see `currency.md`.)*
2. **Citizen-class field-exchange trade-window** — the optional player-run field exchange
   (blocked on the class).
3. **Fae gear line + capacity floor** — Fae caster STR −5 → capacity 5.0 < starter cloth
   kit (see `[[fae-gear-line]]` / item-weight session follow-ups).
4. **Flaky `world_two_clients.rs` hardening** — serial run / adaptive timeouts.
