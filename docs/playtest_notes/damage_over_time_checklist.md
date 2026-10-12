# Damage Over Time Playtest Checklist — 2026-10-08

Spell batch step 5 (user call of 2026-10-05): the server now models damage over time. Dark
Decay (Necromancer 10) and Entangle (Druid 6) are server spells: the direct hit lands with
the cast, then the DoT ticks every three seconds for its duration, builds the mob's hate for
you, breaks mez, and a tick that kills pays exactly what a direct hit would (XP, quest
credit, loot). Two anti-farming rules: a mob that starts walking home sheds every DoT on it,
and your DoTs end when you die, Gate, Succor, Evacuate or log out. The target frame shows
what is on a mob (DoTs, and the crowd control that was invisible before: mez, root, snare,
slow). Also fixed: a mob finished off by Thorns used to pay nothing, and a pet or charmed mob
killed on any path used to drop loot and coin (it never paid XP; now it drops nothing
either). **Needs the redeploy with `d593609` or later AND the next export** (the target-frame icons and the
client no longer running its own DoT online are client code; the ticks, the lines and the
kills work on the old client too).

| Spell | Who | Direct | DoT | Ticks of | Cost |
|---|---|---|---|---|---|
| Entangle | Druid 6 | 10 | 5/s for 18 s (90) | 15 every 3 s | 18 mana, instant, 18 s cooldown |
| Dark Decay | Necromancer 10 | 20 | 7/s for 24 s (168) | 21 every 3 s | 40 mana, 2 s cast, 24 s cooldown |

`server.log` anchors: `enemy killed by a damage-over-time tick`, `kill credit granted`,
`loot bag spawned (kill)`. Each tick fans a Hit (the floating number) and the caster's own
line reads like a proc: "Entangle for 15". `spelltest` has no Druid or Necromancer; make one
or Level Up a fresh character (Entangle at 6, Dark Decay at 10).

## Setup
- [ ] Redeploy the R720 with `d593609` or later (boot line `dev_cmds=false`)
- [ ] Export the client from the same batch; `/version` shows it
- [ ] A Druid 6+ with Entangle on the bar (a Necromancer 10+ with Dark Decay for the long one)

## 1 — The DoT ticks and shows
- [ ] **Entangle a mob and watch it** → the direct hit lands at once, then a floating number every three seconds; chat shows "Entangle for 15" each tick; the server log has no `unknown spell` line. notes:
- [ ] **Watch the target frame** → an "Entangle" icon with a countdown appears on the mob and leaves when the DoT ends. notes:
- [ ] **Re-cast Entangle while the first still runs (after its 18 s cooldown, so cast a second mob first, or use Dark Decay)** → the DoT refreshes to a full duration; it never stacks (one icon, one tick every three seconds). notes:
- [ ] **Entangle a mob that is standing idle, then stand still** → the mob turns on you from the tick alone (a tick is damage, and damage is aggro). notes:

## 2 — A DoT kill pays
- [ ] **Entangle a low mob (a Decrepit Skeleton) and let the ticks finish it** → XP lands, the corpse has loot, a quest kill counts if one is up; `enemy killed by a damage-over-time tick` in the log. notes:
- [ ] **In a group, let a group-mate's DoT finish a mob you tagged first** → the usual kill credit rules (most aggro) and the group split apply. notes:

## 3 — The anti-farming rules
- [ ] **Entangle a mob, then run until it gives up and walks home** → the ticks STOP the moment it turns home (no more floating numbers, the icon leaves); it heals on the way as always. notes:
- [ ] **Entangle a mob, then Gate** → no tick lands after you arrive; the mob you left is at full hate-free rest. notes:
- [ ] **Entangle a mob, then die to it** → the ticks stop with your death; nothing pays your corpse. notes:
- [ ] **Entangle a mob, then log out (camp) and watch from a second seat** → the ticks stop when the body reaps (the linkdead linger keeps them, since the body can still be killed). notes:

## 4 — Crowd control shows on the frame
- [ ] **Cast a mez, root, snare or slow on a mob** → "Mesmerized", "Rooted", "Snared" or "Slowed" appears on the target frame with its countdown and leaves on expiry. notes:
- [ ] **Hit a mesmerized mob with a DoT tick** → the mez breaks (icon leaves) as any damage would. notes:

## 5 — Thorns pays now, pets never drop
- [ ] **Druid with Thorns up, let a nearly dead mob swing at you until the reflect kills it** → XP and loot land; before this the kill paid nothing. notes:
- [ ] **Second seat, both /pvp on: kill the other player's warder (or a charmed mob) by any means** → no XP (as before) and now NO loot bag and no coin either; it used to drop a wolf's table every free respawn. notes:

## 6 — PvP (second seat, both /pvp on)
- [ ] **Entangle a flagged player** → their bar drops 15 every three seconds, you see "Entangle for 15", they see the hit; it ends on time. notes:

## 7 — Regression: nearby behavior unchanged
- [ ] **Direct-damage spells, melee kills, pet kills** → XP, credit and loot as before (the kill step is shared now; nothing should have changed). notes:
- [ ] **A heal-over-time (Regrowth) on yourself** → unaffected. notes:

## Notes / observations
-
