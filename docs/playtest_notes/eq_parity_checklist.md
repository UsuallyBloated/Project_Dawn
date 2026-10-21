# EQ Parity Playtest Checklist — 2026-10-20

The EQ parity audit's five recommendations plus the user's three formula calls, built in one
pass (`docs/design/eq_parity_audit.md` §8 and §9): EQ's hit point and mana formula; the
level 1 to 10 spells at EQ's numbers; the regeneration buffs at P99's figures and levels;
Haste 30%; the low-level mobs' hit points down toward P99's; a spell does exactly its
listed number (no INT or WIS bonus, no casting-skill multiplier); the casting skills decide
fizzles instead. **Both sides move together** (`feat/server-speed`, the Oct 22 bump): the
server owns every number, the client mirrors the pool formula for the bars and the sheet.

| Thing | Before | Now | Where to see it |
|---|---|---|---|
| Human Warrior, level 1 | 200 HP, 100 mana | 28 HP, 20 mana (a token pool; EQ's Warriors had none), 120 stamina | creation preview, the HUD |
| Human Wizard, level 1 | 95 HP, 210 mana | 17 HP, 17 mana | same |
| Human Warrior, level 50 | about 1,670 HP | 1,886 | Level Up tool |
| Smite (Cleric 1) | 35 + INT x 0.5, x evocation, 20 mana | 7 (a crit 10 to 14) for 12 mana | combat log |
| Healing Light (Cleric 1) | 60 + WIS x 0.3, 35 mana | 10 for 10 mana | combat log, the HP bar |
| Ice Spear (Wizard 1) | 50 for 28 mana | 7 for 10 mana | combat log |
| Mana costs, levels 1 to 10 | 15 to 55 | EQ's: about one mana a point (Burst of Flame 7, Minor Healing 10, Fire Bolt 40) | the spell book |
| Breeze / Clarity (Enchanter) | 4 and 8 mana a second for 30 s, at 4 and 14 | 2 and 4 mana a 6 s tick for 27 minutes, at 16 and 29, for 35 and 75 mana | the spell book, the buff bar |
| Regrowth (Druid) | 30 HP a tick for 18 s at 1 | 5 a tick for 20.5 minutes at 34 for 100 mana (Rk. II 10 a tick at 44 for 200) | the spell book |
| Lich Form (Necromancer 20) | 48 mana a tick | 4 a tick | the buff bar |
| Haste (Enchanter 16) | 50% for 30 s, 40 mana | 30% for 11 minutes, 80 mana | the buff bar, swing pace |
| Decrepit Skeleton / Grey Wolf (level 1) | 25 / 24 HP | 16 | kill time |
| Plagued Zombie (level 6) | 116 HP | 80 | kill time |
| A fizzle | never | about one cast in ten at par; "Your spell fizzles!"; a quarter of the mana; the gem's refresh | combat log, the mana bar |

`server.log` anchors: `CastStart fizzled`, `CastSpell fizzled` (both carry `burned`), the
`dev full restore` line from Full Heal. The in-game console (backtick) shows the client's
view of the refusal.

## Setup
- [ ] Re-export Project_Dawn from `feat/server-speed` (the rebuilt DLL of the bump)
- [ ] Redeploy the server from `feat/server-speed` (migrations 0013 to 0015 as the bump carries)
- [ ] A fresh account, or the `spelltest` characters (their levels set by sqlite as before)

> **Known gotcha:** an existing character logs in with its current HP clamped to the new,
> much smaller maximum (a level 20 Warrior kept at 600/600 reads about 480/480). That is the
> clamp at login, not a loss; nothing is owed.

## 1 — Pools
- [ ] **Create a Human Warrior; read the creation preview** → HP 28, MP 20, Stamina 120. notes:
- [ ] **Enter the world with it** → the HUD bars read 28/28 and 20/20. notes:
- [ ] **Create a Human Wizard; preview and world** → 17 HP, 17 mana, both places. notes:
- [ ] **Level Up tool on the Warrior, four times** → max HP 125 at level 5, the sheet's CON 28; the server's HealthUpdate agrees (no bounce). notes:
- [ ] **Relog the level 5 Warrior** → 125 still. notes:
- [ ] **Die and respawn at level 5 or above, taking the de-level** → max HP drops to the lower level's number and current HP is clamped under it. notes:
- [ ] **An older character (made before this build) logs in** → max HP and mana recomputed from its level; current values clamped; no death, no penalty. notes:

## 2 — Spells at their listed numbers
- [ ] **Cleric 1 casts Smite at a Decrepit Skeleton** → "for 7" (a crit shows 10 to 14); never 7 + half the INT. notes:
- [ ] **Cleric 1, hurt, casts Healing Light on itself** → +10 exactly on the bar (not 17). notes:
- [ ] **Wizard 1 casts Ice Spear** → 7. notes:
- [ ] **Magician at 8, Fireball Rk. II** → 45; at 16 Fireball Rk. III still 95 (the 12+ spells are untouched). notes:
- [ ] **Train a casting skill up by casting (the skill-up lines)** → damage does NOT climb with it; only the fizzle rate falls. notes:
- [ ] **The spell book and the gem tooltips** → show the new numbers (7, 10, 45) and the new costs (Smite 12, Healing Light 10, Ice Spear 10), the same on both sides. notes:
- [ ] **A fresh Cleric's mana** → about 16; one Smite (12) and the pool is nearly dry, as on P99 at level 1; sitting to med is the game. notes:
- [ ] **A fresh Enchanter casts Rune, a fresh Wizard casts Bind Affinity** → both castable at level 1 (10 mana each). notes:

## 3 — Fizzles
- [ ] **A fresh caster casts its level 1 nuke twenty or thirty times** → a few "Your spell fizzles!" among them (about one in ten); each fizzle leaves the target untouched. notes:
- [ ] **On a fizzle, watch the mana bar** → a quarter of the spell's cost gone (Smite 20: 5), not the whole cost; the server's ManaUpdate settles it. notes:
- [ ] **On a fizzle, click the gem again at once** → "You cannot cast again yet." for about two seconds (the gem's refresh), then it casts. notes:
- [ ] **A timed spell (Fireball, Healing Light) fizzles** → the line comes at the START, no bar runs, no cast time is lost. notes:
- [ ] **An instant spell fizzles** → the line comes on the click. notes:
- [ ] **A Bard sings any song fifty times** → never a fizzle (no singing skill yet). notes:
- [ ] **A fizzle and the skill-up line** → a fizzle never trains the casting skill; landed casts still do. notes:
- [ ] **Level Up tool to 16 as a Magician, then Fireball Rk. III with the evocation still low** → fizzles noticeably more often than the level 1 nuke (about one in four). notes:
- [ ] **`server.log`** → `CastStart fizzled` / `CastSpell fizzled` lines with `burned` for each. notes:

## 4 — Regeneration buffs
- [ ] **A level 4 Enchanter's book** → no Breeze; it appears at 16, costs 35, and ticks about 2 mana a 6 s for 27 minutes (the buff bar's timer reads minutes, not seconds). notes:
- [ ] **Clarity** → in the book at 29, not 14; 75 mana; 4 mana a tick for 27 minutes. notes:
- [ ] **Haste's timer** → 11 minutes, not 30 s. notes:
- [ ] **A level 1 Druid's book** → no Regrowth (34 now, Rk. II at 44). notes:
- [ ] **A level 20 Necromancer casts Lich Form** → mana climbs about 4 a tick, not 48. notes:
- [ ] **A Shaman 4 casts Healing Wave** → a 20 heal and no heal-over-time icon. notes:

## 5 — Haste and the mobs
- [ ] **Enchanter 16 casts Haste** → the buff reads 30%; swings come 30% faster, not 50%. notes:
- [ ] **A level 1 Warrior fights a Decrepit Skeleton** → it dies in about 3 to 5 swings (16 HP); the Warrior takes 3 a bite and has 28, so the fight is close. notes:
- [ ] **A level 1 Warrior fights two Grey Wolves at once** → likely dies (the point of the pass: level 1 is dangerous, as on P99). notes:
- [ ] **A level 6 character kills a Plagued Zombie** → 80 HP, noticeably quicker than before. notes:
- [ ] **Rotfang / Sable (the named Dire Wolf and Cave Bat)** → still named, still scaled from the smaller base (3.5x of 64 and 48). notes:
- [ ] **A level 10 or 12 mob (Gnoll Brute, Barrow Zombie)** → unchanged at 215 and 265. notes:
