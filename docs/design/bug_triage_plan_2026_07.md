# Bug Triage Plan: July 2026 playtest reports (build-ready)

**Written 2026-07-08 for handoff to a fresh Claude session.** Three user-reported bugs from the
2026-07-07/08 playtests, in priority order, with verified code anchors, reproduction steps, and
suspects. Investigate with evidence before fixing: at least one of these may be working-as-designed.

## Context for a fresh session (do not skip)

- **Two repos:** Godot 4.4 client at `f:\Projects\Project_Dawn` (GDScript), Rust server at
  `F:\Projects\server`. Branch `fix/xp-leveling-overflow` in both. LOCAL git only (no remote ops).
  Read `CLAUDE.md` at the client root for conventions.
- **Server run:** `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:\Projects\server`,
  `| Tee-Object server.log`. The log is UTF-16: use a real file-search tool on it, not raw grep.
- **Debug loop (client):** instrument with `DebugLog.info/warn/error/combat(msg)` and watch the
  in-game console (backtick key). Server side: `tracing::info!` lines + server.log.
- **Tests:** `cargo test -p projectdawn-server --lib`. Integration suite `world_two_clients` is
  timing-flaky in parallel; re-run failures individually (`server/docs/flaky_integration_tests.md`).
- **Workflow:** investigate, fix, adversarial-review anything touching economy/combat, author a
  playtest checklist (`docs/playtest_notes/TEMPLATE_checklist.md`), user playtests BEFORE commit.
  One server + one client commit; exclude `.claude/*` and banker_slice2_checklist.md. Commit trailer:
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **User directive:** exploit vigilance is priority one. Bug 1 is a live economy exploit.

---

## Bug 1 (P0, ECONOMY EXPLOIT): selling an item does not remove it from inventory

**Report (2026-07-07):** "we need to revisit the buy/sell system with the merchants; selling items
doesnt remove the item from the characters inventory." If the coins land and the item stays, that is
an infinite money loop: sell, keep, sell again.

**Code anchors (verified):**
- Client: `scripts/vendor_window.gd` builds a `_sell_items` index array (~line 185-209, note the
  comment about `Inventory.all_slots()` dropping entries) and dispatches via
  `Net.broadcast_sell_item(location, slot, qty)` (`autoloads/net.gd:659`).
- Server: SellItem intents queue at `world/tick.rs` ~1481/1736 and apply in step "4hj" (~5807+),
  with rejection logs like `SellItem rejected — base slot empty` / `bag slot empty`.

**Investigate in this order:**
1. Reproduce: sell one stackable and one non-stackable; watch server.log for the SellItem
   apply/reject lines and `CoinsUpdate`; then check ground truth in `world.db` (inventory rows) and
   relog to see what the server snapshot re-seeds.
2. Split the fault line: (a) server debits but the client never applies the InventoryDelta (display
   ghost, self-heals on relog, no exploit); (b) server rejects (slot mismatch) but PAYS coins
   anyway (real exploit); (c) client sends a stale slot index (the `_sell_items` mapping vs live
   inventory slots) so the server debits the WRONG slot (item loss, the inverse bug). The rejection
   log lines vs the coin lines in one server.log pass will tell you which.
3. Likely suspect based on shape: the `_sell_items` slot mapping going stale after a prior sale
   mutates inventory (indexes shift, the second sale references the old layout). Check whether the
   window rebuilds `_sell_items` on `Inventory.changed` after each sale.

**Fix requirements:** the coin credit and the item debit must be atomic server-side (verify step 4hj
does both under one intent; if the client is the only broken half, fix the delta application/window
refresh). Add a regression test: sell, assert item gone + coins exact; sell the same slot again,
assert reject + NO coins. Playtest rows: single sell, double-click spam sell, sell-from-bag, relog
audit.

---

## Bug 2 (P1, VERIFY DESIGN FIRST): player corpse does not despawn after looting all items

**Report (2026-07-07):** "Character corpse does not despawn after player loots all items."

**Why this needs care:** Slice 2 of the corpse epic playtested loot-to-despawn CLEAN, and the exact
behavior is unit-tested. The rule (deliberate, from `world/tick.rs:8208-8229` and the design doc
`docs/design/corpse_and_resurrection_plan.md`):
- A corpse EMPTIED BY LOOTING (`corpse_emptied_by_loot(had_content=true, empty_now=true)`) despawns.
- A corpse that was BORN EMPTY (naked death, nothing carried) LINGERS on purpose: it is the
  resurrection anchor for a Cleric/Paladin res (Slice 3).

**So investigate whether the user hit the designed linger:**
1. Repro matrix: (a) die carrying gear + coins, loot ALL of it, expect despawn (the tested path);
   (b) die carrying ONLY coins, loot them; (c) die naked, "loot" the empty corpse, expect linger BY
   DESIGN; (d) loot all items but leave coins, then take coins.
2. Check `had_content` at the loot site (`tick.rs` ~7107-7210, `delete_now =
   corpse_emptied_by_loot(...)`): does it count COINS as content, or items only? A coins-only corpse
   mis-classified as born-empty would linger wrongly. This is the most plausible real bug.
3. Check the Take All path vs per-item looting separately (they were both exercised at Slice 2, but
   Slice 3 + PD_W0023 changes touched the corpse code paths since).

**Outcome fork:** if it is the naked-death linger, this is a UX problem, not a bug: the player cannot
tell a res-anchor corpse from a stuck one. Options for the user: show the decay timer on the corpse
nameplate, or a one-line CombatLog note ("The corpse will fade in N minutes."). If it is the
coins-only misclassification, fix `had_content` to include coins and extend the
`corpse_emptied_by_loot` unit tests.

---

## Bug 3 (P2, DESIGN + SMALL FIX): "You critically hit a wolf for 3 damage!"

**Report (2026-07-07):** "three damage is not a critical hit; we need to make sure that when a player
crits, its actually a critical hit. We will need to figure out how other games execute this."

**Code anchors (verified, `world/combat.rs`):**
- Crit chance: `(DEX - 10) * 0.003`, capped 30% (`CRIT_PER_DEX`/`CRIT_MAX`, lines 55-56), offhand
  60% of mainhand, plus buff bonuses.
- Crit effect: multiplier `rng.gen_range(1.5..=2.0)` on the base roll (lines 119-127).

**Diagnosis (math, not a code defect):** at low level with a weak weapon the base roll is tiny
(bare hands: 1-4 + STR/5), so 2 base x 1.5 = 3 "crit". The multiplier model is fine at scale; it
FEELS broken when the base is single-digit, and a 1.5x roll can be nearly invisible.

**Research task (small, do it honestly):** how classic games make crits feel real. Known reference
points to verify and expand with sources: classic EQ warriors crit for double the damage roll
(and Berserkers triple); WoW-era standard is a flat 2.0x; many ARPGs use 1.5-2x plus a visible
floor. Deliver a one-page recommendation to the user with 2-3 options:
- (a) flat 2.0x multiplier (simple, reads clearly at every scale),
- (b) 1.5-2.0x roll PLUS a minimum bonus floor (e.g. crit adds at least +50% of the weapon's max
  roll, so low-level crits still visibly pop),
- (c) keep the roll, raise the low end (1.75-2.25x).

**Wherever it lands:** the change is a few lines in `calc_swing`, plus updating the combat.rs unit
tests that assert non-crit ranges, and checking the client CombatLog line renders the crit flag
distinctly (color/exclamation already exist; see `NetCombatBroadcaster`/CombatLog). Note spell crits
are not implemented server-side (combat.rs header comment); melee only for now.

---

## Explicitly NOT in this plan

- **Abandon-quest button + Brom's quest dialogue:** they belong to the quest system and are slices
  C/D of `docs/design/quest_phase2_server_objectives_plan.md`. Do not duplicate them here.
- **Quest journal wiping on logout:** same plan, slice A.

## Suggested order

Bug 1 (exploit, close it first), then Bug 2 (fast to classify, possibly docs/UX only), then Bug 3
(research + user decision + small change). Each gets its own checklist and its own commit; they are
independent and should not share one changeset.
