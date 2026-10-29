# Equip Gates, the Fizzle Cooldown and the Full 30 m — 2026-10-27

Four small builds from the 2026-10-27 sitting (`client_authority_fixes_checklist.md`'s notes).
(1) EQ's equip rule: a weapon goes into the off hand only when the class can dual wield (a
Cleric wore two clubs on the R720); (2) a weapon of a type the class never trains, or armor of
a kind it never trains, is refused at the equip instead of worn badly; (3) a fizzle keeps the
gems greyed for the refresh (the next click used to meet "You cannot cast again yet."); (4) a
targeted spell casts at its full listed range (the client stopped a metre short; the server's
30 m is exact, out of range at 30.1).

**Needs the redeploy (server `build=` on the boot line) AND the next export.** The server half
of (1) and (2) works against the old client, but the old client still refuses at 29 m and
clears the cooldown on a fizzle.

**Grouped by character (2026-10-29)** so each seat runs its rows in one sitting. Each row
names the build it checks: DW (dual wield), CLASS (class-restricted equipping), FIZZLE, RANGE,
REG (regression). Rows marked *two seats* need the partner; everything else is one seat. The
10-27 sheet's shield row is gone: no shield item exists yet (the shield skill has no items).

| Thing | Where | Notes |
|---|---|---|
| The equip refusals | chat, then `server.log` `EquipItem refused — the class cannot use it` | the server line fires only for a client that skipped its own check |
| The fizzle | chat "Your spell fizzles!", the greyed gems | `server.log` `CastStart fizzled` / `CastSpell fizzled` |
| The reach | the spell tooltip's `Range: 30 m` | `server.log` `CastSpell refused — target pre-flight` with `too far away` only past 30 m |

## Setup
- [ ] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes:
- [ ] Both seats on the new export (login screen build stamp). notes:
- [ ] A GM account for the Level Up tool and `/give`. The items: two Cracked Wooden Clubs, an Iron Short Sword, Copper Chain Boots, a Cracked Leather Vest, a Splintered Staff. notes:

## 1 — Cleric (Smite, Healing Light; Greater Heal at 8)
- [ ] **(DW) Holding a club, click the off-hand slot** → "Your class cannot dual wield.", the club stays on the cursor, the slot stays empty. notes:
- [ ] **(DW) Right-click a second club in the bags** → it swaps into the main hand (the old club comes out), never into the off hand. notes:
- [ ] **(CLASS) An Iron Short Sword (1h_slashing)** → "Your class cannot wield that.", not equipped, from the bags and from the cursor alike. notes:
- [ ] **(CLASS) Copper Chain Boots** → worn (Clerics train chain). notes:
- [ ] **(CLASS) The Cleric that wore two clubs on the R720 on 10-27, if it still wears them** → still worn; the off hand stays idle (the swing gate), and once taken off the second club cannot go back on. notes:
- [ ] **(FIZZLE) Cast Smite until one fizzles** → "Your spell fizzles!", and every gem greys for about two seconds, as after a landed cast. notes:
- [ ] **(FIZZLE) Click the gem again at once** → nothing is sent; the gem casts the moment it clears. notes:
- [ ] **(FIZZLE) Healing Light (a timed cast) fizzles** → the bar stops at once, the mana bar settles on the quarter burned, the gems grey. notes:
- [ ] **(FIZZLE) A refused cast (Smite with no target, or too far)** → the gems do NOT grey: a refusal starts no cooldown, as before. notes:
- [ ] **(RANGE) Hover Smite** → `Range: 30 m`. notes:
- [ ] **(RANGE) Stand 29.5 m from a mob (the `/loc` of the two) and cast Smite** → it lands (the old client refused at 29). notes:
- [ ] **(RANGE) Back off to about 31 m and cast** → "Your target is too far away." from the client, no bar, no mana. notes:
- [ ] **(RANGE, two seats) Greater Heal (2.5 s, level 8) on the partner standing at 29 m, who walks away past 30 m before it lands** → "Cast failed: That target is too far away.", mana untouched (the server's reach is exact). Divine Wrath (1.8 s, level 12) on a mob the partner leads away does the same. notes:
- [ ] **(RANGE, two seats) Healing Light on the partner at 30 m** → lands. notes:

## 2 — Warrior
- [ ] **(DW) Below 15, holding a club, click the off-hand slot** → "You will be able to dual wield at level 15.", the slot stays empty. notes:
- [ ] **(DW) Level Up to 15, click again** → the club goes on; both hands swing. notes:
- [ ] **(CLASS) Iron Short Sword, Copper Chain Boots, Cracked Leather Vest** → all worn. notes:
- [ ] **(REG) Equip from the cursor onto the paperdoll, swap a worn piece, then a Splintered Staff (two-hander) with the club still in the off hand** → as before. notes:

## 3 — Monk
- [ ] **(DW) A Monk 1 with a club** → the off-hand slot takes it. notes:
- [ ] **(CLASS) A Cracked Leather Vest** → "Your class cannot wear that." (Monks train cloth alone). notes:

## 4 — Wizard
- [ ] **(CLASS) Copper Chain Boots** → "Your class cannot wear that.". notes:

## 5 — Bard
- [ ] **(REG) Sing and twist** → no greying, no refusal. notes:

## 6 — Any character
- [ ] **(REG) Corpse loot with gear worn at death** → goes back on the slots it died in (the gate does not touch the corpse path). notes:

## 7 — `server.log`, after the sitting
- [ ] **(CLASS) Through the equip rows** → no `EquipItem refused — the class cannot use it` lines: the client refused first every time. notes:
- [ ] **(FIZZLE) After the casting** → no `inside the global cooldown` lines from honest play. notes:

## Notes / observations
-
