# Gear Stat Display Fix — Playtest Checklist — 2026-07-11

Equipped gear now applies its stat bonuses to the character sheet in launcher (multiplayer)
mode. Before, the server applied gear stats for combat but never synced the six primary stats
(STR/AGI/DEX/INT/WIS/CHA) to the client and the client's equip path skipped local stat
recompute — so the character window never moved when you equipped gear. This is the fix the
Tarnished Silver Ring surfaced (AGI +1 that didn't show).

**Client-only change → no server rebuild, no DLL rebuild.** Just re-export / reload the client
(the server can keep running). Max HP/MP/Stamina stay server-authoritative (unchanged); this
is about the primary-stat numbers on the character sheet.

> **Test with a SERVER-KNOWN item.** The quest **Tarnished Silver Ring** (from wolf_threat) is
> perfect — it's server-granted, so the server knows it's in your bag. Items from the Test
> Panel "give" buttons are client-only ghosts (the separate dev-tool issue), so they can't be
> equipped server-side and won't exercise this path. Loot drops and vendor-bought gear also
> work.

## Setup
- [x] Re-export / reload Project_Dawn in Godot (server can stay up)
- [x] A character holding the Tarnished Silver Ring (turn in wolf_threat at Aldric if needed),
      or any looted/vendor-bought equippable item; note the starting AGI on the character window

## 1 — Equip applies the stat, unequip removes it
- [x] **Equip the Tarnished Silver Ring** (drag to the ring paperdoll slot) → the character
  window **AGI goes up by 1** immediately. notes:
- [x] **Unequip it** → AGI drops back to the starting value (not below). notes:
- [x] **Re-equip / unequip a few times** → AGI toggles cleanly between base and base+1, never
  drifts. notes:

## 2 — Survives relog WITHOUT drifting (the tricky case)
- [x] **With the ring equipped, log out and back in** → the ring is still equipped AND AGI is
  still base+1 (NOT base, NOT base-1). notes:
- [x] **Relog a second and third time** → AGI stays base+1 every time (no downward drift per
  relog). notes:
- [x] **Unequip, relog** → AGI is back to base and stays there. notes:  Ring is equipped again when I log back in.  Let me know what you think.

## 3 — Death strips the stat (naked = base)
- [x] **With the ring equipped, die** (Test Panel damage, or a mob) → after respawning naked
  (gear on your corpse), the character window shows **base AGI** (the ring's +1 is gone with the
  ring). notes:
- [x] **Loot the ring back from your corpse and re-equip** → AGI is base+1 again. notes:

## 4 — Other stats / multi-stat gear (same code path)
- [x] **Equip any looted/vendor STR or INT item** → the matching stat moves; unequip reverses
  it. (The fix applies all six primary stats uniformly; the ring just happens to be AGI.) notes: Tested with Iron Short Sword (+2 STR)
- [x] **A gear piece with a max-HP or CON effect** → the character sheet's primary stat moves,
  and max HP still matches the server (the HP bar is server-driven, unchanged by this fix). notes: Tested with Iron Chain Vest +2CON +25HP

## 5 — Regression: Test Room (no server) still works
- [x] **In Test Room, equip/unequip gear** → stats still apply the same as before (the local
  path was already correct; this fix only touched the launcher/server-driven paths + the
  character re-apply). notes:
- [x] **Test Panel "Level Up" with gear equipped** → after the level-up your gear stats are
  still applied (this also fixed a latent case where a dev re-apply dropped gear stats). notes:

## Notes / observations
- Does the server.log show that the ring is not saying unequipped or equipped when i log in/out?

Let me know what you find before you change anything.