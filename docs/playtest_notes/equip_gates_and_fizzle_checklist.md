# Equip Gates, the Fizzle Cooldown and the Full 30 m — 2026-10-27

Four small builds from the 2026-10-27 sitting (`client_authority_fixes_checklist.md`'s notes).
(1) EQ's equip rule: a weapon goes into the off hand only when the class can dual wield (a
Cleric wore two clubs on the R720); (2) a weapon of a type the class never trains, or armor of
a kind it never trains, is refused at the equip instead of worn badly; (3) a fizzle keeps the
gems greyed for the refresh (the next click used to meet "You cannot cast again yet."); (4) a
targeted spell casts at its full listed range (the client stopped a metre short).

**Needs the redeploy (server `build=` on the boot line) AND the next export.** The server half
of (1), (2) and (4) works against the old client, but the old client still refuses at 29 m and
clears the cooldown on a fizzle.

| Thing | Where | Notes |
|---|---|---|
| The equip refusals | chat, then `server.log` `EquipItem refused — the class cannot use it` | the server line fires only for a client that skipped its own check |
| The fizzle | chat "Your spell fizzles!", the greyed gems | `server.log` `CastStart fizzled` / `CastSpell fizzled` |
| The reach | the spell tooltip's `Range: 30 m` | `server.log` `CastSpell refused — target pre-flight` with `too far away` only past 31 m |

## Setup
- [ ] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes:
- [ ] Both seats on the new export (login screen build stamp). notes:
- [ ] A GM account for the Level Up tool and `/give`. notes:

## 1 — A weapon in the off hand needs dual wield
- [ ] **A Cleric holding a club clicks the off-hand slot** → "Your class cannot dual wield.", the club stays on the cursor, the slot stays empty. notes:
- [ ] **A Warrior below 15 does the same** → "You will be able to dual wield at level 15.", the slot stays empty. notes:
- [ ] **Level Up to 15, click again** → the club goes on; both hands swing. notes:
- [ ] **A Monk 1 with a club** → the off-hand slot takes it. notes:
- [ ] **A Cleric right-clicks a second club in the bags** → it swaps into the main hand (the old club comes out), never into the off hand. notes:
- [ ] **A shield (offhand item) on a Cleric** → still goes on. notes:

## 2 — The class refuses weapons and armor it never trains
- [ ] **A Cleric with an Iron Short Sword (1h_slashing)** → "Your class cannot wield that.", not equipped, from the bags and from the cursor alike. notes:
- [ ] **A Wizard with Copper Chain Boots** → "Your class cannot wear that.". notes:
- [ ] **A Cleric with the same boots** → worn (Clerics train chain). notes:
- [ ] **A Monk with a Cracked Leather Vest** → refused (Monks train cloth alone). notes:
- [ ] **A Warrior with any of the above** → all worn. notes:
- [ ] **A character already wearing a weapon it cannot use (worn before this build)** → still worn; it swings at the old 80% miss until unequipped, and cannot go back on. notes:
- [ ] **`server.log` through §1 and §2** → no `EquipItem refused — the class cannot use it` lines: the client refused first every time. notes:

## 3 — A fizzle keeps the gems greyed
- [ ] **A fresh caster casts its nuke until one fizzles** → "Your spell fizzles!", and every gem greys for about two seconds, as after a landed cast. notes:
- [ ] **Click the gem again at once** → nothing is sent; the gem casts the moment it clears. notes:
- [ ] **A timed spell (Healing Light) fizzles** → the bar stops at once, the mana bar settles on the quarter burned, the gems grey. notes:
- [ ] **`server.log` after a session of casting** → no `inside the global cooldown` lines from honest play. notes:
- [ ] **A refused cast (no target, too far)** → the gems do NOT grey: a refusal starts no cooldown, as before. notes:

## 4 — A spell casts at its full range
- [ ] **Hover Smite** → `Range: 30 m`. notes:
- [ ] **Stand 30 m from a mob (the `/loc` of the two) and cast** → it lands (the old client refused at 29). notes:
- [ ] **Back off to about 32 m and cast** → "Your target is too far away." from the client, no bar, no mana. notes:
- [ ] **A heal on a partner at 30 m** → lands. notes:

## 5 — Regression
- [ ] **Equip from the cursor onto the paperdoll, swap a worn piece, a two-hander with an off-hand item worn** → as before. notes:
- [ ] **Corpse loot with gear worn at death** → goes back on the slots it died in (the gate does not touch the corpse path). notes:
- [ ] **A Bard sings and twists** → no greying, no refusal. notes:

## Notes / observations
-
