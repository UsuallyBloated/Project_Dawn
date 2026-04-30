# Named Mobs — Spawn Design
*Design reference for named / boss mob behavior, spawn windows, and camp mechanics.*

---

## What a Named Mob Is

A named mob is a specific mob entry that:
- Has a proper name (not "a gnoll warrior" but "Gnash the Gnoll Warlord")
- Has a dedicated loot table with items not available elsewhere
- Spawns on a timer with variance rather than respawning immediately on death
- Occupies a specific spawn point that other (placeholder) mobs occupy in its absence

Named mobs are not dungeon bosses. Dungeon bosses are covered in individual zone docs. Named mobs live in the open world — in camps, at crossroads, in ruins — and require camping: waiting at the spawn point across multiple placeholder cycles until the named appears.

---

## Spawn Window Mechanics

### The placeholder cycle
Each named mob spawn point has one or more **placeholder** mobs — ordinary mobs of the appropriate type and level. When the placeholder dies, a timer starts.

```
placeholder dies → base_timer + variance rolls → spawn fires
                                 ↓
                    (named OR placeholder, probability-weighted)
```

### Timer values
| Named tier | Base timer | Variance | Named chance per spawn |
|---|---|---|---|
| Common named | 20 min | ±10 min | 25% |
| Uncommon named | 1 hr | ±30 min | 15% |
| Rare named | 3 hr | ±1 hr | 10% |
| Ultra-rare named | 8 hr | ±2 hr | 5% |

**Variance is random each cycle** — the same spawn point will not produce the named on a predictable schedule. A camper who kills placeholders for four hours has the same per-spawn chance as one who has been there for twenty minutes.

### Named chance on spawn
When the timer fires, the server rolls against the named chance for that spawn point. If the roll fails, a placeholder spawns and the cycle repeats. If the roll succeeds, the named spawns instead.

Named mobs do not respawn immediately on death. After a named dies, its spawn point resets to placeholder behavior with a **lockout** equal to three times the base timer before the named can appear again.

---

## Placeholder Identification

Players learn to identify the placeholder for a named mob through in-world observation:
- Placeholder names follow the zone's generic naming conventions
- Placeholders may have slightly different coloration or naming ("a large gnoll" vs "a gnoll")
- Zone-specific lore hints from NPCs can narrow down which mob is the placeholder

There is no UI indicator. Figuring out the camp is part of the game.

---

## Camp Claiming

The Breach camps, outdoor bosses, and popular named mobs create social friction. The camp system governs this.

### Camp check
Before engaging a named mob's spawn area, a player should perform a **camp check**: ask in /say whether the camp is taken. Convention:

```
[Player] says: "Camp check on [Name]?"
[Camper] says: "Claimed. Been here 45 min."
```

If no response, the camp is considered open.

### Camp hold window
After killing the named, the camp hold window gives the successful group **15 minutes** of priority on that spawn point before it becomes open again. This is social convention, not enforced mechanically — the game will not prevent another player from engaging.

### Contention
The game does not assign camps. Two groups can both engage the same placeholder. First to tag the placeholder owns the kill and any named that spawns from it. Tagging is defined as: first hit registers the mob as owned by that group's tag.

### Kill steal protection
A mob tagged by one group cannot be looted by another. Named loot is protected — the tagging group gets the drop regardless of who deals the final blow.

---

## Loot Table Design

### Named loot tiers
Each named has a **primary** and **secondary** loot table.

**Primary table** — named-exclusive items. Always drops one item from this table on kill. Items from this table cannot be found elsewhere.

**Secondary table** — zone-quality gear and tradeskill materials. Drops 0–3 items, weighted by rarity. Overlaps with regular zone loot.

### Item rarity on primary table
Named loot is not uniform. Even on the primary table, the best items are rare:

| Item quality | Drop rate |
|---|---|
| Common named drop | 60% |
| Uncommon named drop | 30% |
| Rare named drop | 9% |
| Ultra-rare (best in slot) | 1% |

This means camping a named for its best item requires many kills over time — not a single lucky run.

### Loot is not guaranteed to be useful
Named loot is designed around the zone's level range and is class-agnostic in its raw stats but often thematically class-appropriate. A named in a ranger-heavy zone will drop items with AGI and archery-adjacent stats — but any class can use them if the stats apply.

---

## Quest-Gated Named Mobs

Some named mobs only spawn as the result of a quest step. These are distinct from standard camping:

- The player must complete a precondition (collect items, kill a specific mob first, interact with an object)
- The named spawns at a designated location as a personal or group instance of the mob — other players cannot steal the spawn
- The named despawns after 30 minutes if not killed

Quest-gated named mobs appear in zone docs with a `[Quest-gated]` tag in the Enemies table. Standard camp mechanics do not apply to them.

---

## Named Mob Behavior

Named mobs are not mechanically identical to their placeholders. All named mobs have:

- **Higher HP** — roughly 3× a same-level placeholder
- **One or more special abilities** — see zone docs for specifics; named mobs are documented per zone
- **Enrage at 20% HP** — attack speed increases significantly; this is the danger window
- **Death message** — named mobs announce their death in /say or /shout with a zone-visible message

Common special ability types:
- **Call for help** — pulls nearby mobs on spawn or at HP threshold
- **Knockback** — melee ability that moves the tank
- **AOE proc** — damages everyone in melee range periodically
- **Flee** — runs at low HP, often toward more mobs (dangerous)
- **Summon** — teleports the highest-threat player to the named's position (prevents kiting)

Named mobs with the **Summon** ability are among the most dangerous. Kiting and pulling are not options — the group must stand and fight.

---

## Example — Greenshire Region Named Mobs

| Named | Placeholder | Base Timer | Named Chance | Notable Ability |
|---|---|---|---|---|
| Gnash the Warlord | a gnoll raider | 1 hr | 15% | Calls for help at 50% HP |
| Bristletusk | a large boar | 20 min | 25% | Knockback + bleed DoT |
| Rotwood Elder | a deadwood shambler | 3 hr | 10% | AOE disease proc |
| The Watcher in the Mill | — | Quest-gated | — | Summon; no kite possible |

---

## Server Events — Ultra-Rare Named

A small number of named mobs have a base timer measured in days, not hours. These are server-scale events:

- Announced in /shout when they spawn
- Have zone-wide presence (large models, audible sounds)
- Drop server-first or legendary-tier loot
- The kill is recorded in a zone-wide history accessible at the relevant NPC

Killing one for the first time on a server is a notable event. Subsequent kills are still rare but not historic.
