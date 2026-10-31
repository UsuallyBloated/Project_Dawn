# The Two-Hander Rule, the Jump Reach and the Self Cast Bar — 2026-10-29

Three builds from the 2026-10-29 sittings, grouped by character so each seat runs its rows in
one go. (1) **The two-hander rule** (DW2): a two-hander goes in the main hand only, and only
while the off hand is empty; nothing goes in the off hand while the main hand holds one; the
off hand never swings beside one. The user's call: a two-hander beside an off-hand weapon is
an end-game Warrior ability, and nobody has it until that ability exists. Both staves now
carry the two-handed flag (they were `2h_blunt` by skill with the flag off, so a staff went on
beside a club). (2) **The jump reach** (JUMP): the jump cue reaches everyone who can see the
jumper (the view, 120 to 240 m), not the 50 m say range, for the user's jump check. (3) **The
self cast bar** (BAR): centred, a little below the middle, where it used to sit under the
hotbars.

**Needs the redeploy (server `build=` on the boot line) AND the next export.** The server half
of (1) works against the old client (it would see the refusal lines arrive from the server);
(2) is server only; (3) is client only.

| Thing | Where | Notes |
|---|---|---|
| The two-hander refusals | chat, then `server.log` `EquipItem refused — the class cannot use it` | the server line fires only for a client that skipped its own check |
| The off-hand swing backstop | `server.log` `Attack rejected — off-hand swing beside a two-handed weapon` | only a modified client, or gear worn before the rule, reaches it |
| The jump cue | the partner's hop on your screen | nothing is logged for a jump |

## Setup
- [x] Server on the R720 from this build (boot line `build=`, `dev_cmds=false`). notes: deployed 2026-10-29 19:04 UTC, boot line `build="c7c96f6" dev_cmds=false`, two persisted corpses loaded.
- [x] Both seats on the new export (login screen build stamp). notes:
- [x] A GM account for the Level Up tool and `/give`: a Carved Staff, two Cracked Wooden Clubs. notes:

## 1 — Warrior (Level Up to 15 first, so the off hand is open)
- [x] **(DW2) Staff into the main hand with an empty off hand** → worn. notes:
- [x] **(DW2) Holding a club, click the off-hand slot beside the staff** → "You cannot hold that with a two-handed weapon.", the club stays on the cursor. notes:
- [x] **(DW2) Right-click a club in the bags with the staff worn** → it replaces the staff in the main hand (a one-hander swaps in), never joins it. notes:
- [x] **(DW2) A club in each hand, then right-click the staff** → "Empty your off hand first.", both clubs stay on. notes:
- [x] **(DW2) Take the off-hand club off by hand, right-click the staff again** → worn. notes:
- [x] **(DW2) Holding the staff, click the off-hand slot** → "A two-handed weapon goes in the main hand.". notes:
- [x] **(DW2) With the staff worn and the off hand empty, auto-attack a mob** → one swing stream (the staff); no second "You miss" or hit line for an off hand. notes:
- [x] **(DW2) Two clubs, auto-attack** → both hands swing, as before. notes:

## 2 — Monk (level 1)
- [x] **(DW2) Staff into the main hand** → worn (Monks train 2h_blunt). notes:
- [x] **(DW2) A club into the off hand beside it** → "You cannot hold that with a two-handed weapon." (a Monk dual wields from 1; the two-hander rule still refuses). notes:
- [x] **(DW2) Staff worn, auto-attack** → the staff swings alone; the fists do not join it (a Monk's off hand punches only with BOTH hands empty). notes:

## 3 — The jump reach (two seats, `/loc` on both)
- [x] **(JUMP) Partner about 100 m away, in view, jumps** → you see the hop (the old build showed nothing past 50 m). notes:
- [x] **(JUMP) Partner 40 m away jumps** → the hop, as before. notes:
- [x] **(JUMP) Partner walks out of view (past where their body is no longer drawn, two cells, about 250 m) and jumps** → nothing (nothing to draw it on). notes:
- [x] **(JUMP) You jump** → no cue of your own; your own hop as always. notes:
- [x] **(JUMP) `/say` at 60 m** → still silent (the say range is unchanged; only the jump moved). notes:
- [x] **(JUMP) Eat a Bread Loaf at 60 m** → the partner does not see "Chomp, chomp, chomp..." (the emote stays at the say range). notes:

## 4 — The self cast bar (any caster; Healing Light)
- [x] **(BAR) Cast Healing Light** → a bar with the spell's name, centred left to right and a little below the middle of the screen, fills over 1.2 s. notes:
- [x] **(BAR) It lands** → the bar clears. notes:
- [x] **(BAR) Cast and press ESC** → "You stop casting." and the bar clears at once. notes:
- [x] **(BAR) Cast until a fizzle** → "Your spell fizzles!" and the bar clears at once. notes:
- [x] **(BAR) Drag the bar somewhere else, cast again** → it stays where you put it for the session. notes:
- [x] **(BAR) Open the inventory and the bank, cast** → the bar is not under either window's usual spot, or you can drag it clear. notes:

## 5 — `server.log`, after the sitting
- [x] **(DW2) Through the equip rows** → no `EquipItem refused — the class cannot use it` lines: the client refused first every time. notes:
- [x] **(DW2) Through the swing rows** → no `Attack rejected — off-hand swing` lines from honest play. notes:  Please look into this.  Im not sure. [Claude, 10-29: looked. The journal has no `Attack rejected` line of any kind through the sitting (GHAST's staff fight at 20:09, MIONINK's two skeleton fights at 20:17 and 20:18), so every swing the clients sent was accepted; the client itself sends no off-hand swing beside a two-hander (`Combat._is_dual_wielding`), which is why the server's backstop never had to fire. Holds. The equip rows likewise: no `EquipItem refused` line, the client refused first every time.]

## Notes / observations
-
