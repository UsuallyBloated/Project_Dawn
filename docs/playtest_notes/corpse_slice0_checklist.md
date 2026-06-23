# Corpse Epic, Slice 0 — Server-Authoritative XP / Leveling + Death Penalty — Playtest Checklist — 2026-06-22

Slice 0 of the corpse/resurrection epic moves XP, level-ups, AND the death penalty server-side
(they were client-driven and desynced). This verifies leveling no longer rolls back, the death
penalty (5% of the level band, cascading de-level, grace + floor at level 5) is authoritative, and
gear/buffs survive a level change. Wire is now **PD_W0018**.

**Build prerequisites (do all three):**
- Re-export / reload Project_Dawn (client GDScript changed).
- The `gdext_net.dll` was rebuilt this session — confirm `addons/gdext_net/gdext_net.dll` is fresh
  (reload the Godot editor: Project > Reload Current Project).
- Restart the server (PD_W0018): `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from
  `F:/Projects/server`. Old `PD_W0017` clients/servers will refuse to talk.

> **One-time migration note:** leveling was client-only before, so the server's stored level for
> existing characters is whatever was last persisted (likely low). On first login under PD_W0018 a
> character shows its **server** level, which may be lower than it appeared client-side. Expected.
> For a clean run, make a fresh character or accept the server value as the new truth.

| Rule (locked 2026-06-20/22) | Value |
|---|---|
| Kill XP | server-awarded (solo full, group split), client mirrors |
| Death penalty | 5% of the current level's XP band (`xp_to_next`) |
| De-level | cascades past the boundary, **no per-death cap** |
| Grace + floor | no penalty below level 5; a cascade never drops below level 5 |
| Res restores | 25/50/75% of lost xp (Slice 3, not built yet) |

Diagnostics: server stdout logs `"level change"` (with from/to) and `"server-detected player death"`.
Client: the XP bar + Character window level/stats; combat log shows `"You lost N experience points."`
**Test aid:** the Test Panel (`scripts/test_panel.gd`, backtick console is separate) has a new
**Grant 250 XP** button to reach level 5+ without grinding.

## Setup
- [x] Re-export Project_Dawn, reload editor, restart PD_W0018 server with `PD_DEV_CMDS=1`
- [x] Two clients logged in (or one client + one mob for the solo sections)
- [x] Note each character's level on login (migration note above)

## 1 — Kill XP is server-driven
- [x] Kill a mob solo → XP bar advances; server log shows the kill credit. notes:
- [x] Spam **Grant 250 XP** until you cross a level → you **level up**; level + stats rise; server
  log shows `"level change" from=N to=N+1`. notes:
- [x] Character window: STR/CON/etc. and max HP/MP/Stamina increased by the class's per-level gains. notes:

## 2 — The desync is fixed (the headline regression)
This used to be broken: the client leveled locally, then a server HealthUpdate rolled max HP back.
- [x] Level up, then take a hit / heal (forces a HealthUpdate) → max HP does **NOT** snap back to the
  pre-level value. notes: I believe this is working, but the HP bars seem to bounce around quite a bit and I'm not sure why they are behaving the way they do. Direct heals and HoTs appear to make the health bar move up and down unpredictably.  Please have a look and let me know if you see anything or nothing.
- [x] Relog after leveling → level + XP + max stats are preserved (server persisted them). notes:

## 3 — Death penalty + de-level (level 5+)
Use **Grant 250 XP** to reach level 6 with only a little XP into the band, so one death de-levels.
- [x] At level 6 with low XP-into-level, die (Test Panel **Trigger Death**, or to a mob) → combat log
  "You lost N experience points."; XP bar drops; if it crossed the boundary you **drop to level 5**;
  server log `"level change" from=6 to=5`. notes:
- [x] Stats after de-level decreased by exactly the per-level gain (Character window). notes:
- [x] Equipped gear bonuses are **still applied** after the de-level (equip something first, then
  de-level — the gear's stat/HP bonus must remain). notes:
- [x] Loss amount ≈ 5% of the level's band (L5 band 505 → ~25; L6 band 757 → ~37). notes:

## 4 — Grace + floor at level 5
- [x] At level 1 to 4, die → **no** XP loss, no "lost experience" line. notes:
- [x] At exactly level 5, die repeatedly → XP drops toward 0 but you **never** fall below level 5. notes:

## 5 — Quest XP through the server
- [x] Complete a quest with an XP reward (Test Panel **Add Test Quest** then fulfill it) → XP advances
  and can level you, same as a kill (it now routes through the server). notes:  I can't tell if player receives XP for finishing a quest.

## 6 — Group XP split (regression)
- [x] Two grouped clients, one kills a mob → both get a share (server splits with the group bonus),
  and a share that crosses a band levels that member. notes:

## 7 — Death resets + respawn (regression)
- [x] On death: buffs clear, any in-progress `/camp` aborts, cast bar clears (unchanged behavior). notes:
- [x] After the 5s respawn you stand back up at 25% HP / 25% MP / 50% Stamina at your bind. notes:
- [x] A second death after respawning is processed again (penalty applies; the flag reset works). notes:

## Notes / observations

**Triage of the two flagged rows (2026-06-22, investigated + partly fixed):**

- **Section 2, HP bar "bounces" on direct heals / HoTs:** root-caused (multi-agent + adversarial
  verify). The client applied self-heals optimistically and *larger* than the server in launcher mode
  ([spells.gd](../../autoloads/spells.gd) self-heal added `WIS*0.3 * effectiveness`; the server applies
  a flat `heal_amount`), so the bar jumped to the client guess then snapped down to the server's value.
  Pre-existing (predates Slice 0). **FIXED:** gated the local self-heal + hp-cost writes behind
  `not Net.is_launcher_mode()` (the server's HealthUpdate is now the sole HP authority, matching regen
  and the HoT tick). Re-test: cast a self-heal, the bar should fill smoothly to the server value with
  no snap-back. Two follow-ups remain (NOT fixed, documented): (a) **heal magnitude** now shows the
  server's flat value, which omits the WIS bonus the client used and there's a client/server spell drift
  (e.g. server "Mending Rk. II" heals 38 vs client "Mending" 25) to reconcile; (b) **bard songs** pulse
  client-only (the server applies the song heal once on cast, never pulses), so they still bounce, fixing
  that needs server-side song pulsing, not a local gate.
- **Section 5, can't tell if quest grants XP:** the test quest was *uncompletable*, its "Report back to
  Captain Aldren" objective never auto-satisfies and there's no turn-in NPC, so the grant never fired.
  The grant path itself is correct. **FIXED for testing:** added a Test Panel **Complete Test Quest**
  button (force-completes `test_q1`), a server log line (`"quest xp grant"`), and numbers in the XP
  combat-log line ("You gained 250 experience!"). Re-test: Add Test Quest, Complete Test Quest, watch
  the XP line + bar + the server log. Follow-up (NOT fixed): in launcher mode kill-objective quests
  can't progress at all (`notify_kill` only fires for local Test-Room enemies, not server kills). Great work,  so cool.