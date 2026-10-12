# Cast Hardening Playtest Checklist — 2026-10-08 (spell batch step 0)

The cast handler was hardened as step 0 of the spell batch (server `5d8d385`): every refusal
is now private and lands your mana bar on the server's value; a cast cannot complete after
you die; a finished cast bar cannot be held and released later; a hit that interrupts you
beats the cast even if both land in the same instant; casting stands you up. The two other
halves of step 0 (creatures react from their full spell reach; Charm lasts its full minute)
already passed on `ported_spells_checklist.md` and `charm_return_checklist.md`.
**Server-only: needs the R720 on `5d8d385` or later. No client export needed.**

Who: any caster. Mirelle (Enchanter 20) covers most of it; Fennric or Aldous for a second
seat. Journal anchors: `CastSpell rejected — caster is dead`, `held past the bar`,
`interrupted after the bar began`, `cast rejected — crowd control`.

## Setup
- [ ] Redeploy the server (boot line shows `build=` at `5d8d385` or later, `dev_cmds=false`)

## 1 — Refusals are yours alone, and the mana bar tells the truth
- [ ] **Cast a spell twice inside its cooldown (Smite, Healing Light)** → "Cast failed: Spell is on cooldown." in YOUR chat; the mana bar snaps back to what you really have (the refused cast took nothing). notes:
- [ ] **Second seat beside you watches their chat during the same thing** → they see nothing about your refusal. notes:
- [ ] **Burn your mana down and cast something you cannot afford** → "Cast failed: Not enough mana." and the bar stays where it was, not lower. notes:
- [ ] **Regression: a successful cast** → the bar drops by the cost, once, and stays there. notes:

## 2 — Casting stands you
- [ ] **Sit, then cast a spell with a cast bar (Healing Light, Cascade of Stars)** → you are standing by the time the bar ends; the seated regen rate is not running under the bar. (The client may still DRAW you seated until it catches up; say so if it does, that half is a client follow-up.) notes:
- [ ] **Sit, then cast an instant (Smite, Feral Shriek)** → same. notes:

## 3 — A corpse casts nothing
- [ ] **Start a long cast (Complete Heal if you have a Cleric 20, else any 2 s plus bar) and let a mob kill you before the bar ends** → the cast does not land; after the death you get the usual corpse, nothing healed. The journal shows `CastSpell rejected — caster is dead` if the release reached the server. notes:
- [ ] **Dead, try to cast anything** → "You cannot do that while dead." as before. notes:

## 4 — Held and interrupted casts (test-pinned; `[-]` is fine)
- [ ] **A finished bar held and released later** → cannot be staged from an honest client (it releases the moment the bar ends); the integration test `a_finished_cast_cannot_be_held` is the evidence. notes:
- [ ] **A hit and a completion in the same instant** → same; `a_dead_caster_casts_nothing` and the cast-gate unit tests pin the rule. If in ordinary combat a cast ever both "fails: interrupted" AND lands its effect, that is the bug this closes; say so here. notes:

## 5 — Regression
- [ ] **Cast while a mob beats on you until an interrupt lands** → "Cast failed: interrupted (hit during cast)", mana back, as before. notes:
- [ ] **Walk during a cast** → the cast cancels as before (the client's own cancel), and if the server ever answers, its line is private too. notes:

## Notes / observations
-
