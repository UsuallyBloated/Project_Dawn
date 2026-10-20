# Bard Songs Playtest Checklist — 2026-10-20

Bard songs run on the server now, by classic EQ's rules (user decisions 2026-10-20): a song
takes 3 s to sing and costs nothing; the server pulses the one song being sung every 6 s and
each pulse's effect lingers 12 s; a new song replaces the current one while the old one's
effect lingers (twisting); re-singing the active song, `/stopsong`, any other cast or death
ends it; a song is sung on the move. Every song's strength scales with level: 0.4 of its
listed value when first learned, the full value at 50. Mana Weave is P99's mana song (6 mana
per 6 s pulse). **Needs the Oct 22 bump** (both sides together: songs changed shape in the
data, and the DLL carries the stop).

| Song (level) | Effect at 50 | At its learn level | Where to look |
|---|---|---|---|
| Selos' Melody (1) | +35% run speed | +14% | the buff bar's speed icon; the run itself |
| Poet's Mending (4) | 8 HP a pulse (a heal-over-time) | about 3 | the HoT icon; HP climbing |
| Wanderer's Chord (6) | +12% haste | about 5% | the haste icon; swing pace |
| Anthem of the Hunt (8) | +12% accuracy, +8% crit | about 5% / 3% | the stat icon |
| Mana Weave (10) | 1 mana a second (6 a pulse) | about 0.4 | the mana regen icon; mana climbing |
| Aria of Dismay (16) | 8% attack slow on the target | about 3% | "Slowed" on the target frame |

Diagnostics: `grep "song started\|song stopped" server.log`; the buff bar on your own screen is
the server's snapshot, so an icon that stays is the server's doing.

## Setup
- [ ] The Oct 22 build on both sides
- [ ] A Bard at 10 or more (Level Up tool); a second seat for §4 (two-boxing works)

## 1 — Singing
- [ ] **Sing Selos' Melody** → a 3 s bar, then "You begin singing Selos' Melody." and the speed icon with about 12 s on it; no mana spent. notes:
- [ ] **Watch the icon for 20 s** → it refreshes to 12 s every 6 s and never runs out while you sing. notes:
- [ ] **Run while singing a new song** → the bar is not cancelled by moving (any other spell's is). notes:
- [ ] **Click Selos' Melody again while it is sung** → "You stop singing Selos' Melody." at once, no bar; the icon runs its last 12 s down and goes. notes:
- [ ] **`/stopsong`** → the same. notes:

## 2 — Twisting
- [ ] **Sing Selos', then Wanderer's Chord, then Poet's Mending, then Anthem** (each 3 s) → all four icons stay up as you cycle; drop one from the cycle and its icon runs out 12 s after its last pulse. notes:
- [ ] **Cast Dissonance (a nuke) while singing** → "You stop singing X."; the nuke lands. notes:
- [ ] **Die while singing** → the song ends; the icons run out. notes:

## 3 — Level scaling and the numbers
- [ ] **Level 1 Bard, Selos'** → about +14% speed (noticeably slower than Spirit of Wolf's +40%). notes:
- [ ] **Level 50 (Level Up tool), Selos'** → +35%. notes:
- [ ] **Mana Weave at 10, mana half empty** → mana climbs about 2 to 3 a pulse (6 a pulse at 50); nothing like the old 12 a second. notes:
- [ ] **Poet's Mending, hurt** → HP climbs steadily, shown as a heal-over-time, no bounce. notes:
- [ ] **Aria of Dismay on a mob** → "Slowed" on its frame, refreshed each pulse while it stays in reach; walk out of reach and the pulses skip; kill it and the song stops. notes:

## 4 — A second seat
- [ ] **The partner targets the singing bard** → the song's icons show on the bard's frame with the right timers. notes:

## Notes / observations
-
