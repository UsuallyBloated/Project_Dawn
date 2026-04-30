# Recipe Discovery

Most recipes are learned from trainers, purchased as recipe scrolls, or found as loot drops. Recipe Discovery is a parallel system: at high skill levels, failed combines have a chance to reveal a new recipe rather than simply wasting materials. It is the crafting equivalent of critical hits — rare, meaningful, and not guaranteed.

---

## How It Works

**Trigger condition:** A combine attempt that fails (result is Crude or produces nothing) at a skill level significantly below trivial may trigger discovery. The skill must be at least 75% of the recipe's trivial skill — attempting a recipe far above your skill has no discovery chance, only failure.

**Discovery chance:** Base 2% on any qualifying failed combine. Modified by:
- Each point of skill above the recipe's minimum: +0.1% (capped at +10%)
- Gnome / Kobold using Tinkering-adjacent recipes: +1% base
- Dwarf using Blacksmithing: +0.5% base
- Halfling using Cooking or Baking: +0.5% base

**What is discovered:** A new recipe adjacent to the one attempted — a variation using a different secondary material, a modified version of the output, or an entirely new item that uses the same primary component. Discoveries are not random: each recipe has a fixed discovery table of 1–3 possible unlocks. Once a discovery has been found, it cannot be re-discovered.

**Discovery notification:** A distinct sound cue and chat log message: `You have discovered a new recipe: [Name].` The recipe is permanently added to the character's known recipe list.

---

## Discovery Tables — Examples

### Blacksmithing
| Base Recipe | Discovery | Condition |
|---|---|---|
| Iron Short Sword | Weighted Iron Short Sword (+STR, slightly less DEX) | Fail at skill 60–90 |
| Iron Plate Chestpiece | Iron Plate with Gutters (channels blood away; cosmetic) | Fail at skill 80–110 |
| Silver-Edged Blade | Hollow Silver-Edged Blade (lighter; +AGI instead of +STR) | Fail at skill 100–140 |

### Cooking
| Base Recipe | Discovery | Condition |
|---|---|---|
| Roasted Meat | Spiced Roasted Meat (+HP regen, shorter duration) | Fail at skill 40–70 |
| Hearty Stew | Traveler's Stew (same HP regen, lighter to carry — stacks 20 vs 5) | Fail at skill 80–110 |

### Alchemy (White)
| Base Recipe | Discovery | Condition |
|---|---|---|
| Minor Healing Potion | Bitter Healing Draught (2× effect, nauseates for 10s — minor STR debuff) | Fail at skill 30–60 |
| Mana Tonic | Mana Tonic (Extended) (half the MP restore, lasts 3× as long; useful for meditation) | Fail at skill 60–90 |

### Tinkering
| Base Recipe | Discovery | Condition |
|---|---|---|
| Basic Trap | Delayed Trap (same damage, 3s delay trigger — harder for mobs to avoid) | Fail at skill 20–50 |
| Clockwork Lock | Clockwork Lock (Noisy) (weaker lock but squeals loudly when picked — alarm function) | Fail at skill 80–120 |

---

## Design Notes

**Why failed combines, not successful ones:** Successful combines already reward the crafter with the intended output. Tying discovery to failure creates a secondary reason to push skill boundaries rather than staying in the comfort zone. It also makes the failure state feel meaningful.

**Not all recipes have discovery tables:** Common recipes at low skill ranges (Simple Bread, Copper Dagger) have no discovery attached. Discovery is concentrated in the mid-to-high skill range where experimentation has more value.

**Grand discovery:** Each tradeskill has one Grand Discovery — a unique recipe found only through discovery, not available from any trainer or vendor. These are the highest-prestige crafted items in the game. Grand discoveries are account-wide announcements when found.

**Crafter's mark:** All items produced via a discovered recipe carry the crafter's name in the item tooltip: `Discovered and crafted by [Name].` This distinguishes discovered items from trainer-learned recipes in the same skill range.
