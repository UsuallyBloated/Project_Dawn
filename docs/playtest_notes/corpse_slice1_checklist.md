# Corpse Epic, Slice 1 — The Corpse Run (corpse entity) — Playtest Checklist — 2026-06-23

Slice 1 makes dying leave a **persisted corpse** holding all your gear + carried coin; you respawn
**naked**, the corpse is visible with a "<name>'s corpse" nameplate, it survives a relog, and it
**decays harshly** (gear gone for good) after the linger. Looting your corpse back is Slice 2, this
slice is render + persistence + decay only. Wire is now **PD_W0019**.

**Build prerequisites (all four):**
- Re-export / reload Project_Dawn, then reload the Godot editor (Project > Reload Current Project) so
  the rebuilt `gdext_net.dll` (PD_W0019) loads.
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`.
  It applies migration `0007_corpses.sql` on first boot (creates `corpses` + `corpse_items`).
- Old PD_W0018 clients/servers will refuse to talk.
- Capture the log: `... | Tee-Object server.log`.

| Knob | Value | Where |
|---|---|---|
| Corpse decay | **300 s (5 min)** | `world/corpses.rs` `CORPSE_LINGER_SECS` (short for testing; raise for prod) |
| Coins on corpse | stripped (locked) | all four tiers move to the corpse, wallet zeroes |
| Corpse id | loot-bag partition | shares `EntityDespawn` routing with loot bags |

Diagnostics: server stdout logs `"corpse created"` (char_id + corpse_id + item_stacks),
`"loaded persisted corpses"` (count, at boot), and `"corpse decayed — gear lost"`. Client: the body +
nameplate, the combat log ("You have died." + "Your corpse rests where you fell."), the inventory /
paperdoll / wallet.

> **Known limitation (expected, not a bug):** a fresh character has no bind point (no Soul Binder yet),
> so respawn is a same-scene teleport and the corpse renders correctly. If you have a bind in a
> *different* zone, the corpse may briefly draw in the bind zone too, that's tied to the deferred
> server-authoritative respawn, out of Slice 1 scope.

## Setup
- [x] Re-export client, reload editor (PD_W0019 DLL), restart server (migration 0007 applies cleanly,
  no SQL error in the log). notes:
- [x] Have some gear equipped + items in bags + some coin, so there's something to leave behind. notes:

## 1 — Death creates the corpse
- [x] Die (to a mob, or Test Panel **Trigger Death**) → a body + **"<your name>'s corpse"** nameplate
  appears where you fell; combat log shows "You have died." and "Your corpse rests where you fell";
  server log shows `"corpse created" char_id=.. corpse_id=.. item_stacks=N`. notes:  Test Panel's "Trigger Death" does not appear to spawn a corpse.  Dying to a monster spawns a corpse.  "Tin's Corpse" appeared when Tin died.
- [x] The Slice 0 death penalty still applies on top (XP loss / possible de-level). notes:

## 2 — Naked + broke respawn (the atomic gear move)
- [x] After respawn your **inventory is empty**, your **paperdoll is empty**, and your **wallet is 0**. notes:
- [x] Your stats dropped to gear-free values (the equipped bonuses are gone). notes:
- [x] No duplication: the gear is on the corpse, NOT also still in your bags. You are genuinely naked.
  notes: 

## 3 — Persistence (survives a relog)
- [x] Quit and log back in (within the 5-min linger) → the corpse is **still there** with your name;
  server log shows `"loaded persisted corpses" count>=1` at boot (if you also restarted the server).
  notes:
- [x] Restart the SERVER (not just the client) while a corpse exists, then relog → the corpse is still
  there (it loaded from the DB before your login). notes:

## 4 — Harsh decay (gear gone for good)
- [x] Stand near the corpse and wait out `CORPSE_LINGER_SECS` (5 min) → the corpse **despawns**; server
  log `"corpse decayed — gear lost"`. notes:
- [x] Relog after decay → the corpse does NOT come back (its DB rows were deleted). notes:

## 5 — Two-client view
- [x] Player B sees Player A's corpse with **"A's corpse"** nameplate when in range. notes:
- [x] (Slice 2 preview) B cannot loot it yet — there's no loot interaction on a corpse in Slice 1.
  notes: Confirmed, neither player can currently loot the corpse.

## 6 — Walk-away / walk-back (AOI)
- [x] Walk far from your corpse → it despawns from view (AOI exit); walk back → it reappears. notes:

## 7 — Regression: loot bags unchanged
- [x] Kill a mob → a normal **loot bag** (golden sphere) still spawns and loots normally (corpses
  share the id partition but didn't break bags). notes: This works as intended, but we need to get rid of the golden orbs and have corpses be left behind for all creatures that die. Golden spheres were only place holders.

## Notes / observations
-  Excellent work.  I made a few notes so let me know what you think.
-  I ran two servers for the tests so there might be a server.log that appears to be missing.

