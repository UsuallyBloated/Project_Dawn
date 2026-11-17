# Wandering Wildlife Playtest Checklist — 2026-11-16

Animals now wander the ground between the camps (design: `docs/design/wandering_wildlife.md`):
70 by day in five level bands, 14 more at night. They walk short legs and pause, notice you as
they pass, fight with the AI every mob has, and go home to where the fight began. Wolves travel
in packs. Also in this build: one pet at a time (a new charm or summon releases the old pet; a
charmed one comes back hostile), and a charm no longer wipes the record of who hurt a mob.

**Build prerequisite:** the server redeployed from the build that carries
`feat/wandering-wildlife` (the boot line reads `roamers=on`). Everything but section 7's quest
text works on the client testers already hold; the quest text needs a client build from the
same branch. No protocol change, no migration.

| Band | Where (from the town) | Animals (level; temper) |
|---|---|---|
| Town meadows | 150 to 420 m, all round | Field Rat (1; aggressive, short-sighted: 6 m), Grass Snake (2; passive) |
| Near basin | 450 to 750 m, south of the ridge | Prairie Wolf pairs (3), Prairie Adder (4; 6 m), Black Bear (5; passive); **night:** Bat (4) |
| Outer basin | 800 to 1,300 m, south of the ridge | Timber Wolf threes (7), Brown Bear (8), Rock Adder (6); **night:** Wandering Shade (7) |
| The Greywood | north of the ridge | Greywood Wolf threes (8), Greywood Bear (9), Forest Viper (7) |
| Far reaches | past 1,350 m: the war camp's vale, the barrow hills, the east arm | Grizzly Bear (11), Hill Wolf pairs (11), Rock Viper (12); **night:** Barrow Shade (10, barrow hills) |

Night is 21:00 to 05:00 game time: 400 real seconds out of every 1,200. The Test Panel shows the hour; otherwise the sky tells you (fully dark is night).

Tip: GM flight (`/fly`, from the editor build) is the quick way to look over a region. Server
journal anchors: `wandering wildlife` (at world start), `world health` (tick times, once a
minute), `enemy position fan`, `charm dropped for a new pet`, `kill credit granted`.

## Setup
- [ ] Server redeployed; boot line reads `roamers=on` and `dev_cmds=false`. notes:
- [ ] The `wandering wildlife` line at world start reads `slots=66 animals=84` (the share of the plate about 51%). notes:
- [ ] One GM account and, for sections 5 and 9, a second seat. notes:

> **Known gotcha:** the animals only walk while somebody is in the world, and you only see one
> walking when you are within view of it (120 to 240 m). An empty meadow at first glance is
> normal: there are six rats and six snakes in half a square kilometre.

## 1 — They are there, and they walk
- [ ] **Walk a lap of the meadows 200 to 400 m from the town** → you meet Field Rats and Grass Snakes away from any camp. notes:
- [ ] **Watch one from 20 m for a minute** → it stands a while (5 to 25 s), ambles 20 to 80 m at well under its running speed, facing the way it walks, and stands again. notes:
- [ ] **Stand at the town gate for ten minutes (or fly a slow circle at 150 m)** → no wandering animal comes inside 150 m of the town's middle on its own. notes:
- [ ] **Visit each band in the table** → the animals listed are there, at about the listed levels (`/con`). notes:
- [ ] **Look at where they walk on the hills** → none stands on a cliff face or walks down one; they turn back at steep ground. notes:

## 2 — Being noticed, and passive animals
- [ ] **Walk past a Prairie Wolf pair or a Brown Bear at 10 m** → it turns on you as you pass (it looks for you while it walks, not only when standing). notes:
- [ ] **Walk right up to a Grass Snake and a Black Bear and stand there** → nothing; they carry on. notes:
- [ ] **Hit the Black Bear** → it fights back. notes:
- [ ] **Nuke a Grass Snake from 30 m** → it comes for you (a passive animal still answers; none can be hit from beyond its reach). notes:
- [ ] **Hit a wandering animal while it is mid-walk** → the hit lands (a walking animal is not "evading"). notes:
- [ ] **Field Rats near a starter camp** → they join a fight only when it comes within about 6 m of them. If they make the first camps too hard for a new character, say so: their temper is one line of data. notes:

## 3 — The walk home
- [ ] **Pull a wanderer 30 m and outrun it past its leash (35 m)** → "evades" on your hits as it turns back; it walks a short way, to about where the fight began (not across the map to where it first appeared), heals to full, and goes back to wandering. notes:
- [ ] **Pull one toward the town and let it go** → it walks back out; it does not settle near the town. notes:

## 4 — Loot, coin and quests
- [ ] **Kill a wandering wolf, a bear, an adder or viper, a rat** → wolf, bear, snake and rat loot respectively (the snakes drop snake items), and none drops coin. notes:
- [ ] **Wolf quest (Aldric) active, kill a wandering wolf** → the journal ticks. notes:
- [ ] **Rat quest (Brom) active, kill a Field Rat** → no tick. **Kill a Plague Rat at the Rat Warrens** → a tick. notes:
- [ ] *(client build from the branch)* **The rat quest's objective** reads "Kill plague rats at the Rat Warrens". notes:

## 5 — Packs (second seat helps)
- [ ] **Find a wolf pair or three** → they move together: one leads, the others trail within a few metres and stop when it stops. notes:
- [ ] **Hit one wolf from range** → every packmate within about 30 m comes too. notes:
- [ ] **Kill one of a pack, back off 80 m and wait about three minutes** → a replacement appears beside the survivors (not a whole second pack, and not while you stand within 60 m). notes:
- [ ] **Kill a whole pack and wait** → a fresh pack appears somewhere else in the band, never beside you. notes:

## 6 — Respawns
- [ ] **Kill a lone wanderer and stand on the spot for five minutes** → it does not reappear beside you; its replacement is somewhere else in the band. notes:

## 7 — Night
- [ ] **At 21:00 game time, in the near basin** → Bats are out; in the outer basin, Wandering Shades; in the barrow hills, Barrow Shades. notes:
- [ ] **Kill a Bat and a Shade** → the Bat drops bat loot and no coin; the Shade drops coin and no animal loot, and the kill moves town standing and alignment as an undead kill does. notes:
- [ ] **Stay beside a night animal through 05:00** → it stays while you can see it; walk out of view and come back: gone. notes:
- [ ] **Fight a night animal across dawn** → it does not vanish mid-fight. notes:
- [ ] **By day** → no Bats (the Cave Bat camp is unchanged) and no Shades. notes:

## 8 — The off switch
- [ ] **Add `PD_NO_ROAMERS=1` to the server's `.env` and restart** → boot line `roamers=off`; the camps are all there, nothing wanders. Remove it and restart → they are back. notes:

## 9 — One pet at a time, and charm
- [ ] **Necromancer: summon a skeleton, then summon again** → the old one falls, the new one stands; never two. notes:
- [ ] **Enchanter: charm a wandering wolf from a pack; wait past its pack's respawn time** → the pack does not grow a replacement while the charm holds. When the charm ends the wolf comes for the Enchanter and the pack is its old size. notes:
- [ ] **Enchanter: charm a wanderer, walk it to the town gate, let the charm end, and survive or die** → afterwards the animal walks back out to where it was charmed; it does not stay at the gate. notes:
- [ ] *(two seats)* **Seat A beats a mob to a sliver; seat B (Enchanter) charms it, lets the charm end, and finishes it** → the kill credit (XP, the journal line `kill credit granted`) goes by who did the damage, seat A included; before this build the charm wiped A's share. notes:
- [ ] **A pet parked with `/pet guard` in the wilds** → wanderers that pass will find and fight it (EQ's behaviour; worth knowing). notes:

## 10 — Regression and the journal
- [ ] **A camp pull, a camp respawn, a charm on a camp mob and its return, a Beast Master's warder** → all as before. notes:
- [ ] **`world health` lines with everyone online** → `over_budget=0`; the median tick stays in low single milliseconds with 124 to 138 mobs. notes:
- [ ] **No error or panic lines in the journal for the sitting.** notes:
