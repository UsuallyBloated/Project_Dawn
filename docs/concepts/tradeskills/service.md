# Service Skills

Service skills don't produce items in the traditional sense — they perform actions, enable mechanics, or produce knowledge objects. They are often overlooked in the crafting economy but some are deeply intertwined with core gameplay.

---

## First Aid

**Requires:** Bandage (consumable, produced via this skill) | **Prerequisites:** None | **Cap:** 200

Craft and apply bandages to restore HP out of combat. First Aid is the only way to recover HP in the field without a healing class, a potion, or a campfire. It's slower than potions and requires bandages, but bandages are cheap to produce and the skill is available to every class.

**Combat restriction:** First Aid cannot be used while in active combat. The animation is 2 seconds; taking damage during the animation cancels it.

### First Aid Products

| Bandage | Materials | Min Skill | HP Restore | Cast Time |
|---|---|---|---|---|
| Cloth Bandage | 2 Cloth | 0 | 15 HP | 2s |
| Linen Bandage | 3 Cloth + Herb extract | 40 | 35 HP | 2s |
| Silkwrap | 2 Silk Cloth | 80 | 60 HP | 2s |
| Herbal Compress | Linen + Bloodmoss + Bitterroot | 100 | 80 HP + removes Bleed DoT | 2s |
| Masterwork Bandage | 3 Silk + Moonpetal extract | 170 | 120 HP + minor HoT (5 HP/3s for 30s) | 2s |

**Self and others:** First Aid can be applied to other players (target them, use the skill). A high-skill First Aid user is a meaningful group utility, especially in situations where the Cleric is dead and there's no potion.

---

## Lockpicking

**Requires:** Lockpick Set (consumed on fail, degraded on success) | **Class Restriction:** Rogue-type classes only | **Cap:** 200

Pick mechanical locks on doors, chests, and cages. Lockpicking is a Rogue-defining utility skill. High skill opens higher-tier locks without failing and destroying lockpicks. Some locked areas can only be opened this way — no key exists, and bashing the door fails. Rogues who invest in Lockpicking become the keys to content that would otherwise be inaccessible.

### Lock Tiers

| Lock Tier | Min Skill | Location Examples |
|---|---|---|
| Simple | 0 | Basic chests in town, unlocked rooms |
| Standard | 40 | Dungeon room doors, merchant storage |
| Complex | 80 | Vault doors, rare chest spawns |
| Master | 130 | Dungeon boss chambers, secret rooms |
| Legendary | 175 | End-game vault content; one-time opens |

**Lockpick quality:** Higher-quality lockpicks (Tinkering-produced) reduce failure chance at each tier. A Rogue who also takes Tinkering for lockpick crafting is significantly more self-sufficient than one who buys from vendors.

**Alignment note:** Lockpicking is class-restricted (Rogue-type) but not alignment-restricted. A Good-aligned Rogue can pick locks.

---

## Animal Husbandry

**Requires:** Stable or Pen | **Prerequisites:** None | **Cap:** 200

Raise, train, and breed animals and mounts. Animal Husbandry is the mount system's crafting backbone. High-skill practitioners can breed animals with better speed, stamina, or rare colorations. Live animal catches from Trapping (cage traps) feed into this skill.

### Operations

| Operation | Skill | Input | Output |
|---|---|---|---|
| Tame basic mount | 0 | Captured mount animal (world drop) | Rideable mount (base stats) |
| Train mount speed | 30 | Rideable mount + training time | +5% mount speed |
| Breed for coloration | 60 | 2× same mount type | Rare coat pattern (cosmetic) |
| Breed for endurance | 80 | 2× trained mounts | Mount with +20% stamina |
| Train warhorse | 120 | Horse + combat training regimen | Mount that doesn't break from combat |
| Selective breed (stat) | 150 | 2× high-trait mounts | Offspring with elevated base stats |
| Legendary breeding | 185 | Rare parent stock | Mounts with unique abilities (water walking, night speed) |

**Mount interaction note:** Animal Husbandry design must align with the mount system (design target in CLAUDE.md). Spirit of Wolf stacking, dismount-on-damage, and Selos' Melody interactions are all mount-dependent systems that Animal Husbandry will eventually feed into.

**Pack animals:** Animal Husbandry also produces trained pack animals — mules, oxen — that can carry additional inventory when exploring non-combat zones.

---

## Farming

**Requires:** Tilled soil in a farming zone or player housing plot | **Prerequisites:** None | **Cap:** 200

Till soil, plant crops, and harvest raw food ingredients. Farming is the primary source of grain (flour), root vegetables, and domesticated herbs that feed Baking, Cooking, and Brewing. Without Farmers, Bakers and Cooks depend on vendors or the market for base ingredients.

**Growth time:** Planted crops grow on a real-time timer. Wheat: 20 minutes. Root vegetables: 15 minutes. Exotic herbs: 40–60 minutes. Higher Farming skill reduces growth time and increases yield per plot.

### Crops

| Crop | Min Skill | Growth Time | Yields | Use |
|---|---|---|---|---|
| Wheat | 0 | 20 min | Grain → Flour | Baking, Brewing |
| Potato | 0 | 15 min | Potatoes | Cooking |
| Carrot | 10 | 15 min | Carrots | Cooking |
| Onion | 10 | 12 min | Onions | Cooking |
| Barley | 20 | 18 min | Barley | Brewing |
| Hops | 30 | 20 min | Hops | Brewing |
| Wildflowers | 40 | 30 min | Wildflower bunches | Brewing (mead), Incense |
| Sweetgrape | 60 | 35 min | Grapes | Brewing (wine) |
| Rare Herbs | 80 | 50 min | Herb varieties | Baking, Alchemy |
| Spice Plants | 100 | 45 min | Spice blends | Cooking (tier 3+) |
| Exotic Grove Crop | 150 | 60 min | Exotic ingredients | Halfling Feast, Legendary Alchemy |

**Halfling affinity:** Halflings receive +XP rate for Farming and have access to the Halfling Cottage Garden layout — a small personal plot available in non-town zones that produces at slightly better yields than standard farming plots.

---

## Sailing

**Requires:** Boat or ship (docked vessel) | **Prerequisites:** None | **Cap:** 200

Operate and maintain watercraft. Sailing unlocks navigation on ocean and large river zones, enables access to island locations, and supports fishing in deep-ocean zones. Higher skill opens faster vessel types and allows maintenance repairs without a dock.

### Operations

| Operation | Skill | Notes |
|---|---|---|
| Row boat | 0 | Slow; small; river and coastal only |
| Small sailboat | 40 | Wind-dependent speed; open coastal |
| Merchant vessel | 80 | Large cargo capacity; group crewing |
| Navigate by stars | 100 | Remove fog of war in ocean zones; find islands |
| Deep ocean transit | 130 | Access to deep sea fishing zones |
| Vessel repair at sea | 150 | Hull repair without returning to dock |
| Ship-to-ship maneuver | 170 | Future PvP maritime design target |

**Economy note:** Sailing players are logistics providers. They carry bulk goods (stone, timber, ore) across water zones faster than overland travel. In a mature server economy, dedicated traders with high Sailing can become significant supply chain nodes.

---

## Beekeeping

**Requires:** Beehive (craftable structure, placed in field or housing) | **Prerequisites:** None | **Cap:** 200

Maintain hives to produce honey and beeswax. Beekeeping is the start of the artisan chain — its outputs (honey, wax) feed Baking, Brewing, Candlemaking, and Incense Crafting.

Hives produce on a real-time cycle. Basic hive: yields every 15 minutes. Upgraded hive: every 10 minutes. A character with 10 upgraded hives running in a housing plot is a passive production engine.

### Hive Operations

| Operation | Min Skill | Output | Yield |
|---|---|---|---|
| Harvest basic hive | 0 | Honey (2-4), Beeswax (1-2) | Per 15-min cycle |
| Craft Upgraded Hive | 60 | Station item (placed object) | Better yield per cycle |
| Harvest rare varietal | 80 | Varietal Honey (specific flower types) | Feeds specialty Brewing recipes |
| Grand Apiary (Grandmaster) | 180 | Royal Jelly (Alchemy reagent), Grand Honey | Rare yield; Royal Jelly is Enchanting-adjacent |

**Royal Jelly:** A Grandmaster Beekeeping yield. Royal Jelly is an Alchemy ingredient for high-tier stat elixirs and a rare Enchanting reagent (life-magic imbue). It cannot be purchased from vendors. Grandmaster Beekeepers are rare; Royal Jelly supply is genuinely constrained.

**The Halfling fantasy:** A Halfling character who runs Farming + Beekeeping + Baking + Brewing + Cooking is a self-contained agricultural empire. They grow the grain, keep the bees, bake the bread, brew the mead, and cook the feast. The Halfling Feast and Dwarven Grand Stout are theoretically the best consumable buffs in the game — a Halfling-Dwarf partnership running a supply operation together is a meaningful economic arrangement.

---

## Cartography

**Requires:** Cartography Kit (portable) | **Prerequisites:** None | **Cap:** 200

Draw and reproduce maps of explored regions. Cartography uses zone data from the player's own exploration — you can only map areas you have personally visited. The output map is an item that can be used by any player to reveal that region's geography and landmark locations.

Higher Cartography skill produces more accurate maps (fewer blank areas, more node locations marked) and allows reproducing copies from a master map.

### Map Types

| Map | Min Skill | Content |
|---|---|---|
| Rough Sketch | 0 | Basic zone outline; major landmarks only |
| Standard Map | 50 | Roads, settlement locations, major node clusters |
| Detailed Survey | 100 | Resource node locations, patrol routes noted |
| Master Chart | 150 | Everything — node respawns, rare spawn areas, secret paths |
| Ocean Chart | 130 | Sailing zone with island positions |
| Dungeon Floor Map | 80 | Per-floor dungeon layout (requires dungeon exploration at that skill) |

**Bard affinity:** Bards receive bonus XP for Cartography. A Bard-made Master Chart of an unexplored dungeon is a genuine service commodity — sold to adventuring groups before a run.

**Bookbinding prerequisite:** Cartography 50 (along with Scribing 50) unlocks Bookbinding.

---

## Scribing

**Requires:** Inkpot + Parchment (or player-produced paper from Logging) | **Prerequisites:** None | **Cap:** 200

Copy scrolls, reproduce spellbook entries, and transcribe runes discovered in the world. Scribing is primarily a caster-support skill — higher tiers allow reproducing spells as single-use scrolls that any class can use.

### Products

| Item | Materials | Min Skill | Notes |
|---|---|---|---|
| Blank Scroll | Parchment + Inkpot | 0 | Component for other Scribing recipes |
| Minor Spell Scroll | Blank Scroll + learned spell reference | 40 | Single-use scroll; any class can cast it once |
| Standard Spell Scroll | Blank Scroll + intermediate spell | 80 | Single-use; higher-tier spell |
| Rune Transcription | Blank Scroll + Ruinstone rubbing | 100 | Copies ancient rune from dungeon wall; Runecarving feed |
| Spellbook Copy | 5 Parchment + spell reference | 120 | Backup copy of spellbook; sold to Wizards who lose theirs |
| Language Scroll | Blank Scroll + known language | 150 | Teaches a snippet of a language; not full fluency — partial |
| Master Grimoire | 10 Parchment + Gold Ink + 5 spells | 170 | Compendium of multiple spells; Wizard/Magician demand |

**Paper production:** At Logging skill 40+, bark pulp can be processed into parchment paper (a Scribing action itself — skill 20). This makes a dedicated Scribe self-sufficient from wood harvest to finished scroll without depending on vendor parchment.

**Bard affinity:** Bards reproduce songs as scrolls. A Bard Song Scroll (Scribing 130+) allows a non-Bard to play a 30-second version of one Bard song once. Extremely high demand from groups who don't have a Bard. Bards who invest in Scribing sell these — a meaningful source of income for the class.

**Bookbinding prerequisite:** Scribing 50 (along with Cartography 50) unlocks Bookbinding.

---

## Bookbinding

**Requires:** Binding Press (station) | **Prerequisites:** Scribing 50, Cartography 50 | **Cap:** 200

Combine Scribing and Cartography outputs into complete bound books. Bookbinding's core feature — the one that sets it apart from every other tradeskill — is **player-authored content**. A player can write text into a book. Other players can find and read it.

This is the lore system. Every in-game text, diary, historical record, and rumor found in the world could be player-authored. The difference between a prop and a lore object is the author's investment.

### Book Types

| Book | Materials | Min Skill | Content | Notes |
|---|---|---|---|---|
| Pamphlet | 2 Parchment + Cover | 50 | Up to 4 player-written pages | Cheapest; disposable |
| Journal | 5 Parchment + Leather Cover | 80 | Up to 10 pages; can include a small map | Most common lore object |
| Illustrated Tome | 8 Parchment + Fine Cover + Sketch pages | 120 | Up to 20 pages + illustrated header | Visual header from Cartography sketch |
| Atlas | 5 Parchment + 3 Maps + Cover | 100 | Collection of maps in book form | Bundled Cartography output; high utility value |
| Skill Manual | 10 Parchment + Master sketch + Seal | 150 | Player-written; teachable skill hints | Passive skill XP gain bonus when another player reads it |
| Grand Grimoire | 15 Parchment + Gold Binding + Gem inlay | 185 | Up to 40 pages; magical preservation | Books last indefinitely; can be placed in housing |

**Player-authored content:** When creating a book above Pamphlet tier, the crafter gets a text input window. Whatever is written becomes the book's content. Other players who pick up or purchase the book can read it. This is the primary lore delivery mechanism for player-driven world history — expedition journals, trade route guides, dungeon notes, clan histories, songs transcribed by Bards.

**Skill Manual mechanic:** A Skill Manual written by a Grandmaster-level crafter in a specific skill grants a modest passive XP bonus (5–10% faster gain) to readers for 24 in-game hours after reading. This creates a literal market for expertise: Grandmaster crafters can write manuals that give other players a training edge.

**The Bard's natural home:** The Bard class's connection to Scribing + Cartography + Bookbinding is thematic and mechanical. Bards travel. They explore. They record what they find. A Bard who invests in all three has the highest-tier Bookbinding output and produces books other players genuinely seek out — not for the stats, but for the content.
