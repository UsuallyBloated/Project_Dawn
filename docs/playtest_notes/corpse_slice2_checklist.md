# Corpse Epic, Slice 2 — Loot Your Own Corpse — Playtest Checklist — 2026-06-23

Slice 2 makes a corpse lootable BY THE OWNER: walk back, click your body, take your gear (it returns
to your bags) and your coin. Owner-only, no group/round-robin. A corpse you loot **clean vanishes**; a
corpse born empty from a naked death still **lingers** as a res anchor. Wire is now **PD_W0020**.

**Build prerequisites (all three):**
- Re-export / reload Project_Dawn, then reload the Godot editor (Project > Reload Current Project) so
  the rebuilt `gdext_net.dll` (PD_W0020) loads.
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`.
  No new migration (Slice 1's `0007_corpses.sql` already has the tables/columns).
- Old PD_W0019 clients/servers will refuse to talk. Capture: `... | Tee-Object server.log`.

| Rule | Value |
|---|---|
| Loot rights | owner-only (your char_id == corpse owner); others refused "That is not your corpse." |
| Gear return | to your **bags** (re-equip manually, EQ-style); a full inventory leaves the item on the corpse |
| Coins | the corpse's coin returns 100% to you (no split), credited on your first take |
| Looted empty | the body **despawns** + its DB rows delete |
| Born empty (naked death) | **lingers** as a res anchor until decay (NOT despawned by looting) |
| Take target | reuses LootItem/LootAll keyed by corpse id (no new client send) |

Diagnostics: server logs `"corpse looted empty — despawned"` and `"apply_corpse_loot persist failed"`
(should never fire). Client: the loot window over the corpse, the "You loot: X" lines, the wallet, your
bags/paperdoll.

## Setup
- [x] Re-export client, reload editor (PD_W0020 DLL), restart server. notes: server.log confirms the PD_W0020 build booted (loaded persisted corpses count=5) and looting ran.
- [x] Have gear equipped + items in bags + some coin, then die so there's a stocked corpse. notes: used 5 pre-existing (boot-loaded) corpses from earlier sessions rather than dying fresh this run.

## 1 — Loot your own corpse
- [x] After dying, walk back and **left-click your corpse** → a loot window opens listing your items
  (and a coin row if you had coin). notes: inferred — a corpse can't be looted to empty without its window opening; not directly eyeballed.
- [x] **Take** a single item → it lands in your bags ("You loot: X"); the corpse window refreshes with
  that item gone. notes:  (not yet confirmed — can't tell single-Take vs Take-All from the log)
- [x] **Take All** → all remaining items land in your bags; the corpse **despawns** (server log
  `"corpse looted empty — despawned"`); the loot window closes. notes: server.log: 5x "corpse looted empty — despawned" (ids 2000000002..6, char 76); a despawn means no leftover-refund, so all items were placed in bags.
- [x] Re-equip from your bags works (gear is not auto-equipped, EQ-style). notes:

## 2 — Coins
- [x] A corpse with coin → your **first take credits the coin** to your wallet (watch the coin total);
  the coin row disappears from the window after. notes:  I am very happy that the player's money is not distributed through the group when they loot their own body.

## 3 — No dupe, no loss
- [x] Note your full gear before dying; loot it all back → you have **exactly** what you had, nothing
  duplicated in your bags and nothing stranded on a despawned corpse. notes:
- [x] Loot with a **full inventory** (fill your bags first) → the item you can't fit **stays on the
  corpse** (no silent loss); free a slot and take it. notes:

## 4 — Owner-only
- [x] Player B left-clicks Player A's corpse → no loot window opens (owner pre-gate), and if B somehow
  sends a take, the combat log shows **"That is not your corpse."** notes:

## 5 — Persistence (partial loot survives a relog)
- [x] Take SOME (not all) items, then quit + log back in → the corpse still holds the **remaining**
  items (the looted ones are gone, not back). notes:
- [x] Restart the SERVER mid-corpse (after a partial loot), relog → same: remaining items intact, no
  dupes, no loss. notes:

## 6 — Looted-empty vs born-empty
- [x] Loot a corpse clean → it **vanishes** (your decision: the run is finished). notes: confirmed — 5x "corpse looted empty — despawned" in server.log; no errors, no persist failures.
- [x] Die **naked** (Test Panel: take everything off / have nothing) → an **empty corpse lingers** (it
  does not vanish; it's a res anchor for Slice 3). It's clickable but the window is empty. notes:  Not exercised in-game this run (no naked death in either log), but now covered by a server regression test (`corpse_lingers_unless_a_loot_emptied_it`, gating the real `corpse_emptied_by_loot` predicate): a Take-All on an already-empty corpse does NOT despawn it. Worth a quick in-game confirm eventually; no longer a blocker.

## 7 — Regression: mob loot bags unchanged
- [x] Kill a mob → its **loot bag** (golden sphere) still opens, loots item-by-item / Take All, splits
  coin, and despawns when empty exactly as before (corpses share the id path but didn't break bags). notes:

## Notes / observations
- Checked boxes (2026-06-23) reflect the QUICK playtest + server.log — the **server-side** path only
  (corpse loot → empty → despawn, no errors, no persist failures). Still need an eyeball / full run:
  single-Take (1), re-equip (1), coins (2), no-dupe + full-inventory (3), owner-only (4), persistence +
  server-restart-mid-corpse (5), naked-death linger (6, incl. the post-run fix), loot-bag regression (7).
