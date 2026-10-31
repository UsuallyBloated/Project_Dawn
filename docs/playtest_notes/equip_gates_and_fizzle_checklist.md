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
- [x] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes: journal 2026-10-29: `build="2157fd9" dev_cmds=false` (the 10-27 22:51 UTC boot, still up).
- [x] Both seats on the new export (login screen build stamp). notes: the stamp is not in the server journal; the 29.5 m Smite landing and the gems greying after a fizzle are the new client's behaviour (the old one refused at 29 and cleared the cooldown).
- [x] A GM account for the Level Up tool and `/give`. The items: two Cracked Wooden Clubs, an Iron Short Sword, Copper Chain Boots, a Cracked Leather Vest, a Splintered Staff. notes: account 2 (`GM account connected`), one character per class: NUG, grump, MOINKL, THYTTT, BARDOO; `GmGive applied` and `dev quest xp grant` lines through the sitting. The Warrior got a Carved Staff instead of the Splintered one (both `2h_blunt`).

## 1 — Cleric (Smite, Healing Light; Greater Heal at 8)
- [x] **(DW) Holding a club, click the off-hand slot** → "Your class cannot dual wield.", the club stays on the cursor, the slot stays empty. notes:
- [x] **(DW) Right-click a second club in the bags** → it swaps into the main hand (the old club comes out), never into the off hand. notes: I cant actually tell if they are swapping, but i can tell that the second club is not going into the offhand, so thats good. [Claude, 10-29: the journal shows the swap: 15:30:41 `EquipItem src_slot=1 equip_slot=0`, then `src_slot=3 equip_slot=0`, then `src_slot=1 equip_slot=0`, the two clubs trading the main hand and the bag slot on each right-click.]
- [x] **(CLASS) An Iron Short Sword (1h_slashing)** → "Your class cannot wield that.", not equipped, from the bags and from the cursor alike. notes:
- [x] **(CLASS) Copper Chain Boots** → worn (Clerics train chain). notes:
- [-] **(CLASS) The Cleric that wore two clubs on the R720 on 10-27, if it still wears them** → still worn; the off hand stays idle (the swing gate), and once taken off the second club cannot go back on. notes:  See my note at the bottom of this .md 
- [x] **(FIZZLE) Cast Smite until one fizzles** → "Your spell fizzles!", and every gem greys for about two seconds, as after a landed cast. notes:
- [x] **(FIZZLE) Click the gem again at once** → the client's own "You cannot cast again yet." and nothing is sent (no `inside the global cooldown` line in the journal); a click after the gems clear casts, nothing queues. notes: "You cannot cast again yet." displayed in chat.  Gem is not cast the moment it clears.  This works great. I dont think this needs to change. [Claude, 10-29: the expected result used to say "casts the moment it clears", meaning a click after the clear; reworded to what exists. The line was the client's: the journal has no server cooldown refusal at all.]
- [-] **(FIZZLE) Healing Light (a timed cast) fizzles** → the bar stops at once, the mana bar settles on the quarter burned, the gems grey. notes: Player cannot see their own casting bar. [Claude, 10-29: the server half ran, `CastStart fizzled caster=9 spell=Healing Light burned=2.5` at 15:44:19 and 16:09:39, and Greater Heal `burned=10.0` at 16:13:49 and 16:17:32, so the fizzle is right. The missing bar is a HUD finding, not a fizzle one: the self cast bar (`scripts/hud_cast_bar.gd`) is drawn 72 to 120 px above the bottom edge at the centre, inside the band the hotbars sit in; filed under the UI layout entry.]
- [x] **(FIZZLE) A refused cast (Smite with no target, or too far)** → the gems do NOT grey: a refusal starts no cooldown, as before. notes:  Seems to work.  i spammed enough to get a fizzle.
- [x] **(RANGE) Hover Smite** → `Range: 30 m`. notes:
- [x] **(RANGE) Stand 29.5 m from a mob (the `/loc` of the two) and cast Smite** → it lands (the old client refused at 29). notes:
- [x] **(RANGE) Back off to about 31 m and cast** → "Your target is too far away." from the client, no bar, no mana. notes:
- [x] **(RANGE, two seats) Greater Heal (2.5 s, level 8) on the partner standing at 29 m, who walks away past 30 m before it lands** → "Cast failed: That target is too far away.", mana untouched (the server's reach is exact). Divine Wrath (1.8 s, level 12) on a mob the partner leads away does the same. notes:
- [x] **(RANGE, two seats) Healing Light on the partner at 30 m** → lands. notes:

## 2 — Warrior
- [x] **(DW) Below 15, holding a club, click the off-hand slot** → "You will be able to dual wield at level 15.", the slot stays empty. notes:
- [x] **(DW) Level Up to 15, click again** → the club goes on; both hands swing. notes:
- [x] **(CLASS) Iron Short Sword, Copper Chain Boots, Cracked Leather Vest** → all worn. notes: [Claude, 10-29: the journal shows the sword worn (main hand 16:21:01, off hand 16:21:35) and the chain boots (16:23:35 and 16:23:41, both pairs); no vest was given to this character (it went to the Monk), so the vest half rests on the cap table (Warriors train leather) and the Monk's refusal row.]
- [x] **(REG) Equip from the cursor onto the paperdoll, swap a worn piece, then a Splintered Staff (two-hander) with the club still in the off hand** → as before. notes: We are allowing warriors to equip two handed weapons in one hand?  Not too sure about this. [Claude, 10-29: a real finding, see Notes below and the To-Do entry "A two-hander needs an empty off hand". The staff went on at 16:23:14 with a weapon still in the off hand and no UnequipItem of slot 1 before it: the server has no two-handed rule, and the Carved Staff (and the Splintered Staff) are `2h_blunt` by skill but carry `is_two_handed = false`, so even the client's own off-hand-clearing convenience did not fire. The user's call, the same hour: a two-hander beside an off-hand weapon is an end-game Warrior ability; until it exists, refused for everyone.]

## 3 — Monk
- [x] **(DW) A Monk 1 with a club** → the off-hand slot takes it. notes:
- [x] **(CLASS) A Cracked Leather Vest** → "Your class cannot wear that." (Monks train cloth alone). notes:

## 4 — Wizard
- [x] **(CLASS) Copper Chain Boots** → "Your class cannot wear that.". notes:

## 5 — Bard
- [x] **(REG) Sing and twist** → no greying, no refusal. notes:

## 6 — Any character
- [x] **(REG) Corpse loot with gear worn at death** → goes back on the slots it died in (the gate does not touch the corpse path). notes: tested with THYTTT

## 7 — `server.log`, after the sitting
- [x] **(CLASS) Through the equip rows** → no `EquipItem refused — the class cannot use it` lines: the client refused first every time. notes:
- [x] **(FIZZLE) After the casting** → no `inside the global cooldown` lines from honest play. notes:

## Notes / observations
- (Claude, 10-29) **Two-handers**: see the Warrior regression row. No server rule, two staves without the flag, and the off hand swings beside a two-hander (the Attack path's off-hand gates are the dual-wield level and a real off-hand weapon, nothing about the main hand). Decided: an end-game Warrior ability; refused for everyone until then. Build waiting on the go.
- (Claude, 10-29) **The self cast bar**: the Healing Light fizzle row could not be watched because the player's own cast bar never shows (drawn in the hotbars' band). A HUD layout item, not a fizzle one.
- (Claude, 10-29) **`player link ... rtt_ms=0.0` for every player on every line** (here and on 10-27): the world loop hands the clients' acks to renet before it advances renet's clock, so an ack inside a tick is timed at zero. A two-line order swap on the server, waiting on the go.
- (Claude, 10-29) Also in the journal, outside this sheet: a Decrepit Skeleton pays 263 XP solo and 157 each in a pair (`pool=315 members=2`); a character seeded Evil crossed to Bad on skeleton kills (`alignment tier changed ... score=-1500`), the factions build at work ahead of its own checklist; THYTTT's corpse put 4 worn pieces back (`reequipped=4`); dump's client went linkdead by heartbeat at 16:55:28 and reaped 30 s later, as designed.
- (user) [-] **(CLASS) The Cleric that wore two clubs on the R720 on 10-27, if it still wears them** → still worn; the off hand stays idle (the swing gate), and once taken off the second club cannot go back on. notes:  Cool work, that character will be deleted shortly. no need for a fix here.  We absolutely do not at this point need to care about character persistence.  characters will be deleted hundreds of times for a while.  Thanks for the hard work.  Please make note of this.  I especially do not want to be wasting any amount of code bank on fixes like this.