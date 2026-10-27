# Client-Authority Fixes Playtest Checklist — 2026-10-19

The first three fixes from the client-authority audit (`docs/security/client_authority_audit_2026_10_19.md`;
the rule, user 2026-10-19: "Events happening on the client are a no-go"). Each moves something
the client used to decide onto the server.

| Fix | What changed | Ships with |
|---|---|---|
| 1 | Made-up hit, miss and evade messages are GM-only (only the Test Panel sends them) | the next redeploy (server `23bba2c`) |
| 2 | The server decides movement speed: run speed x its own speed buffs x snare x carry weight; mounts refused online | **the Oct 22 bump, both sides together** (`feat/server-speed`, server `9a3e1aa`, client `291d433`). An older client against the new server walks at two thirds speed. |
| 3 | Spell power on the server: INT on nukes, WIS on heals, the casting-skill multipliers, spell crits | the next redeploy (server `b81da60`) |

Diagnostics: a GM's Test Panel hit lands in the GM action log (`admin_report`, `hit_broadcast`);
crits show as crit hits in the combat log; carry weight shows on the character sheet.

## Setup
- [ ] For §1 and §3: the server redeployed at `b81da60` or later (`build=` on the boot line)
- [ ] For §2: the Oct 22 redeploy and export (after `feat/server-speed` is merged)
- [x] A GM account; for §1 a second seat (two-boxing works)

## 1 — Fake hits are GM-only
- [x] **As a GM, Test Panel → hit / miss / evade buttons at a second seat** → the second seat still sees the combat text, as before. notes:  Dip does not see "FRonz evaded your attack." screenshot attached.
- [x] **The second seat, sitting, takes one of those Test Panel hits** → (after the Oct 22 export) it stands up, as from any hit; this is the GM tool working. notes:

## 2 — The server decides speed (Oct 22 build)
- [x] **Run in a straight line** → the same speed as before the change; no rubber-banding. notes:
- [x] **Crouch and walk** → half speed, smooth. notes:
- [x] **Cast Spirit of Wolf, run** → faster by about 40%, not double; no rubber-banding. notes:
- [ ] **Get snared by a mob, run** → slow on your screen without snapping back (if it snaps, note it: the client's own prediction of a snare is the known gap). notes: which enemy snares?
- [x] **GM: give yourself a pile of copper until the sheet shows over capacity, run** → slower, and the "You are encumbered!" line; past double capacity, a crawl and no stamina regen. notes:
- [x] **Right-click a mount whistle** → "Mounts are not available online yet." and you stay on foot. notes:

## 3 — Spell power (next redeploy)
- [ ] **A caster casts a level 1 nuke at a mob several times** → bigger than before (a 30-damage nuke lands around 45 to 55 for a fresh caster), the numbers vary only by an occasional crit (shown as a crit, 1.5 to 2 times). notes:
- [ ] **A Cleric heals a hurt partner** → more than the spell's base (Healing Light 60 lands around 67 at level 1); the same number every cast. notes:
- [ ] **A DoT (Entangle, Dark Decay)** → its ticks are the same size as before; only the direct hit grew. notes:
- [ ] **Play an evening as a caster** → note whether low-level nukes now feel too strong; the formula is the client's as written, and `docs/design/spell_formula_research.md` has the options if it is. notes:

## 4 — Melee misses come from the server (Oct 22 build)
- [x] **Auto-attack a mob for a minute with a fresh character** → some swings miss ("You miss X." and a MISS over the mob), more often than once skilled; the mob still turns on you after a miss. notes:
- [x] **A second seat watching** → sees your misses over the mob as well. notes:
- [-] **Swing a weapon your class cannot use** (a Rogue with a staff, say) → mostly misses, small hits. notes:  Why dont we restrict access to weapons instead of weakening the use of non-optimal weapons.? (Decided 2026-10-27: yes, EQ's rule; the equip is refused on both sides, `equip_gates_and_fizzle_checklist.md` §2; the 80% miss stays as the backstop for gear worn before it.)

## 5 — Dual wield is earned (Oct 22 build)
- [x] **A Warrior below 15 with a sword in each hand** → only the main hand swings, and equipping the second said "You will be able to dual wield at level 15." notes:
- [X] **The same Warrior at 15 (Level Up tool)** → both hands swing. notes:
- [x] **A Monk at level 1 with empty hands** → both fists swing; with a weapon in the main hand only the main hand swings. notes:
- [x] **A Cleric with two weapons** → "Your class cannot dual wield." and only the main hand swings. notes: second screen shot shoes cleric was able to equip two weapons even though that class should be restricted from dual weild. (As built on 10-19: the equip went on and only the swing was refused. Changed 2026-10-27 to EQ's rule, the equip itself refused on both sides; `equip_gates_and_fizzle_checklist.md` §1.)

## 6 — Each spell's own reach (Oct 22 build)
- [x] **Nuke a mob from about 28 m** → it lands (it used to be refused past 24 m). notes:
- [x] **From about 32 m** → refused, mana kept. notes:
- [x] **Hover any targeted spell** → the tooltip ends `Range: 30 m` (`30 m to others` on a heal or buff). notes: Smite max range is 30m, but i cant cast on an enemy that is 30m away. (The client checked a metre inside the reach. Fixed 2026-10-27: the client checks the full 30 m and the server allows a metre past it; `equip_gates_and_fizzle_checklist.md` §4.)
- [x] **Pull a mob from 30 m and run** → it follows a little further than before before giving up (the leash floor moved to 35 m). notes:Smite max range is 30m, but i cant cast on an enemy that is 30m away.

## 7 — The server holds your spell bar (Oct 22 build)
- [ ] **First login on the new build** → your bar is exactly as it was (the server takes it over once). notes:
- [x] **Sit, open the book, memorize a spell into an empty gem** → the two-second bar runs, then "You memorize X into slot N." and your mana is untouched (memorizing is free since 2026-10-26, server `c81dca9`; it used to take half the spell's mana). notes:
- [x] **Start a memorize and stand up before it finishes** → it stops and the gem stays as it was. notes:
- [x] **Clear a gem (right-click it), relog** → the gem is still empty after the relog; a memorized spell is still there. notes:

## 8 — NO RENT (Oct 22 build)
- [x] **Hover a Conjured Bread** → the tooltip starts with NO RENT. notes:
- [x] **Conjure some food, log out, log back in within a few minutes** → the food is still there. notes:
- [-] **Conjure some food, stay logged out over thirty minutes, log in** → the conjured food is gone; ordinary food is not. notes:I havent tested this.  

## Notes / observations
-
