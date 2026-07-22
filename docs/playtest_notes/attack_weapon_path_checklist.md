# Attack weapon_path Trust Gate Playtest Checklist — 2026-07-22

The server no longer trusts the `weapon_path` the client sends with an `Attack`. It derives the
swung weapon from its OWN equipment map (main hand = slot 0, off hand = slot 1) via
`PerConnection::equipped_weapon_path`, so a modified client can't claim a heavier weapon (more
damage), a ranged one (more reach), or one that trains a skill it hasn't equipped (audit finding 5).
Since a stock client always sends the weapon it actually has equipped, this is invisible to normal
play — so this playtest is a **regression sweep**: confirm melee/ranged still behaves for every
equipped state. The exploit path itself needs a modified client, so it's covered by the unit test
`equipped_weapon_path_reads_the_server_slot` + the server log.

**Build prereq: restart the server (release build). No client re-export** — server-only change; the
wire message is unchanged.

> **Known gotcha (dev tooling):** a Test Panel "ghost item" weapon is client-only — the server never
> saw it, so it now swings as **fists**, not that weapon. That is correct (the server is
> authoritative). To test a real weapon, use `/give <weapon>` then equip it through the paperdoll
> (both are server-side), NOT a Test-Panel ghost equip.

## Setup
- [ ] Restart server (release build)
- [ ] Have a melee character with a weapon to equip (via `/give` + paperdoll if needed) and an enemy

## 1 — Equipped melee weapon (regression)
- [ ] **Equip a 1H weapon and auto-attack an enemy** → normal damage lands, weapon skill advances as
  before. notes:
- [ ] **Swap to a different (heavier/lighter) weapon and attack** → damage tracks the NEW weapon (the
  server re-derives from the equipment slot). notes:

## 2 — Unarmed (regression)
- [ ] **Unequip your weapon and attack bare-handed** → you still hit for fist damage (1-4 + STR
  bonus), hand_to_hand skill advances. notes:

## 3 — Dual-wield (regression)
- [ ] **Equip a main-hand + off-hand weapon and attack** → both swings land; off-hand does its
  reduced damage; each trains its own weapon skill. notes:
- [ ] **Remove the off-hand only, keep main-hand, attack** → main-hand still swings normally; no
  phantom off-hand hit. notes:

## 4 — Ranged (regression)
- [ ] **Equip a bow and attack from range** → the longer ranged envelope still applies (no false
  "out of range" Miss at bow distance). notes:

## 5 — Range enforcement still correct
- [ ] **With a melee weapon, try to hit an enemy that's clearly too far** → Miss (out of range), same
  as before — the range now derives from the equipped weapon, not a claimed one. notes:

## 6 — Exploit path (forged weapon_path — expect [-] on a stock client)
- [ ] **Send an Attack naming a weapon you don't have equipped** (needs a modified client) → server
  ignores the claim and uses your actual equipped slot (or fists if empty); no extra damage/reach.
  notes: (expected `[-]` — stock client always sends its real weapon; unit-test-covered)

## Notes / observations
-
