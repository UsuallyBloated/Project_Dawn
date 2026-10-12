# Small Rules Playtest Checklist — 2026-10-08 (spell batch step 1)

The user's 2026-10-05 rule decisions, built as step 1 of the spell batch. The group share
range is 200 m for XP, quest journal ticks and the coin split (was 30 m; journal ticks had no
range at all). Friendly spells (heals, buffs, the pet heal) reach 30 m; hostile spells keep
25 m. Slow is 5% for 30 s at 10 mana (1.0 s cast); Torpor is on the server at last, 10% for a
minute at 20 mana (1.5 s cast), no heal; Aria of Dismay is 8%; none of the three has a cooldown
of its own until the global cooldown lands (step 4). One attack slow holds a target at a time
and the strongest wins: a weaker one is refused at no cost. Every new character is born bound
at the starter spawn.

**Server-side rows need the R720 on `c71b686` or later. The spell numbers also changed on the
client (Slow, Torpor, Aria; the 29 m friendly check), so their rows want the next export or
the editor; until then the client refuses a friendly cast past 24 m before the server sees
it, and shows the old mana costs on the tooltip while the server charges the new ones.**

Who: Mirelle (Enchanter 20: Slow) and a Shaman 20 for Torpor (your GM account's Level Up
tool, or ask for one on `spelltest`); Fennric or Aldous as the second seat. Journal anchors:
`kill credit granted ... members=2`, `coin looted ... recipients=2`, `A stronger slow already
holds`.

## Setup
- [ ] Redeploy the server (boot line shows `build=` at `c71b686` or later, `dev_cmds=false`)

## 1 — The 200 m share (two seats, grouped)
- [ ] **Second seat stands about 150 m from the camp (`/loc` and the distance readout); you kill** → they get the XP line and the journal tick if the mob matches; the journal shows `members=2`. notes:
- [ ] **Second seat stands about 250 m away; you kill** → they get nothing; `members=1`. notes:
- [ ] **Coin: with `/autosplit` on, loot a coin drop with the second seat at 150 m, then at 250 m** → `recipients=2` at 150 m, `recipients=1` at 250 m. notes:
- [ ] **The known trade-off, seen once:** a group-mate parked in town shares from the camp nearest town if it is inside 200 m. Note which camps that covers. notes:

## 2 — Friendly reach is 30 m
- [ ] **Heal a group-mate at about 28 m (the readout on the target frame)** → it lands. notes:
- [ ] **Heal them at about 32 m** → "Cast failed: That target is too far away or no longer here." and the mana stays. (On the old client the client's own check refuses past 24 m first, with its own line; both are a refusal with the mana kept.) notes:
- [ ] **Nuke a mob at about 28 m** → still refused: hostile spells keep 25 m. notes:

## 3 — Slow, Torpor, Aria
- [ ] **Shaman: cast Torpor on a mob** → it lands for 20 mana with a 1.5 s bar, no heal on you, and the mob swings slower for a minute. notes:
- [ ] **Then cast Slow on the same mob** → "Cast failed: A stronger slow already holds that target." and the mana stays. notes:
- [ ] **Slow on a fresh mob, then Torpor on it** → Slow lands (10 mana, 1.0 s), Torpor takes over. notes:
- [ ] **Cast Slow twice in a row** → the second lands (no cooldown of its own; it refreshes). notes:
- [ ] **Bard: sing Aria of Dismay at a mob** → 8%, not 35%; the server slows the mob for 30 s per cast. notes:

## 4 — Bound from birth
- [ ] **Make a brand-new character, walk out of town, die** → it respawns at the starter spawn (as before, now because it is bound there, not as a fallback). notes:

## 5 — Regression
- [ ] **A solo kill** → full XP, as always. notes:
- [ ] **A heal on yourself** → unchanged. notes:

## Notes / observations
-
