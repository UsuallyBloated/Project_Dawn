# Mob Trains — Design Reference
*Social aggro, leashing, and train mechanics.*

---

## What a Train Is

A train is a chain of aggro'd mobs following a player through an area. It happens when:
1. A player pulls more mobs than intended
2. A player runs through an area to escape and picks up additional mobs
3. A player dies while holding aggro and the mobs are still active

Trains are dangerous to other players who are in the path. An unexpected train of six mobs running through a camp is a wipe condition.

This is a feature, not a bug. It creates genuine consequences for pulling badly, teaches zone geography, and makes other players' choices matter.

---

## Social Aggro

Mobs have a **social range** — a radius within which they will assist other mobs of the same faction when combat starts.

### How it works
When mob A enters combat:
1. All mobs of the same faction within `social_range` of mob A check if they have line of sight to the attacker
2. If yes, they add the attacker to their threat list and move to engage
3. This chain continues — if the newly-aggroed mob B is within social range of mob C, mob C checks too

Social aggro does **not** chain infinitely. It only fires once per engagement — mobs alerted by social aggro do not re-trigger the check for their own neighbors.

### Social range values
| Zone type | Social range |
|---|---|
| Open field | 15 units |
| Camp / settlement | 20 units |
| Dungeon corridor | 10 units |
| Dungeon room | 20 units (room-scoped) |

Mobs with the **Pack Leader** AI type have extended social range (+50%) and call for help at 50% HP regardless of nearby mob count.

### Faction scope
Social aggro only triggers within the same faction tag. A gnoll camp and a bandit camp 30 units apart will not assist each other. Faction tags are defined per mob type in the zone data.

---

## Leashing

A mob that chases a player too far from its spawn point will **leash** — disengage, reset HP and threat, and walk back to its spawn.

### Leash distance
Default leash distance is **80 units** from spawn point. Some mob types have extended leash:

| Mob behavior type | Leash distance |
|---|---|
| Standard | 80 units |
| Guard (camp patrol) | 120 units |
| Named mob | No leash (tracks indefinitely until dead, LOS broken, or zone edge) |
| Summoner mob | No leash; summons player instead |

Named mobs with no leash are the primary train risk. A named that gets pulled accidentally and then ignored will follow the puller across the zone.

### Leash reset
On leash:
- HP resets to full immediately
- Threat list clears
- Mob walks (not runs) back to spawn point
- Mob is not attackable during the walk-back
- If attacked during walk-back, leash cancels and combat resumes

### Dungeon leashing
Dungeon rooms are treated as discrete leash zones. A mob will chase to the room boundary but not beyond, unless it is a named mob or the mob explicitly patrols between rooms.

---

## Train Mechanics

### Aggro inheritance
When a player runs through a mob group while already in combat, the new mobs:
1. Check if the runner is in their aggro range
2. If yes, add the runner to their threat list and join the chase
3. If the runner passes through multiple groups, all aggroed mobs consolidate into a single train

The train follows the player regardless of direction. There is no way to "shake" a train by running fast — leashing is the only mechanic that removes mobs from the train, and that only happens at leash distance from their spawn.

### Train etiquette
Players are responsible for their trains. Conventional expectations:
- Call "/shout TRAIN TO ZONE!" or "TRAIN!" when running a large unintentional mob chain through a populated area
- Do not run a train through another group's camp
- If you are going to die, die away from other players — not in their camp

There is no mechanical enforcement of these conventions. The social consequences — reputation, group exclusion, general hostility — are the enforcement.

### Zone edge behavior
Mobs will not follow a player across a zone boundary. At the zone edge, all mobs in the train leash and return to their spawn points. Running to the zone line is a viable (if desperate) train-clearing strategy.

Dying at the zone line after running a train clears the train. The mobs leash. Your corpse remains.

---

## Mob Pathing and Stuck States

Mobs use direct-path navigation modified by obstacle avoidance. In open zones this works cleanly. In dungeons with complex geometry:

- Mobs may get stuck on corners or doorways
- A stuck mob that has line of sight to its target will continue to try pathing
- A stuck mob with no line of sight will leash after 30 seconds of failed pathing

Players can exploit stuck states to kill mobs from a position the mob cannot reach. This is an accepted part of dungeon mechanics, not an exploit.

---

## Pulling as a Skill

Controlled pulls — pulling single mobs or small groups from a larger camp — are a core group skill, especially in dungeons.

Methods available:
- **Bow pull** (Ranger) — range aggroed single target from distance, back up before social range triggers
- **Lull** (Druid/Enchanter spell) — suppresses a mob's social aggro temporarily; does not affect the target mob's own aggro
- **Mez** (Enchanter) — mesmerize the pulled mob's neighbor before it can assist
- **Feign Death pull** (Monk) — pull multiple mobs, feign death to shed aggro, let mobs return; pull one again cleanly

A puller who trains the group is a bad puller. Over time, groups learn which pullers are reliable and which aren't.
