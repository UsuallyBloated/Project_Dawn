# Consumables

Single-use items. Potions are instant or short-duration; food and drink provide regen buffs; poisons coat weapons. All consumables stack to their `stack_size` in inventory.

---

## Alchemy — White (Healing & Restoration)

**Alignment:** Good or Neutral | **Station:** Alchemy Table (Artisan+); Kit (Apprentice/Journeyman)

| Item | Ingredients | Min Skill | Effect | Duration |
|---|---|---|---|---|
| Minor Healing Potion | Feverfew + Bloodmoss + Empty Vial | 0 | Restore ~25 HP | Instant |
| Healing Potion | 2× Feverfew + 2× Bloodmoss + Empty Vial | 50 | Restore ~60 HP | Instant |
| Minor Healing Draught | Bloodmoss + Clay Vial | 0 | Restore 25 HP | Instant |
| Healing Draught | 2× Bloodmoss + Glass Vial | 30 | Restore 60 HP | Instant |
| Superior Healing Draught | Bloodmoss + Moonpetal + Glass Vial | 130 | Restore 150 HP | Instant |
| Legendary Healing Elixir | Moonpetal + Spirit Sage + Grand Vial | 180 | Restore 300 HP + HoT 10/3s | 30s |
| Minor Mana Tonic | Silverleaf + Clay Vial | 20 | Restore 30 MP | Instant |
| Mana Potion | Ice Essence + Wormwood + Empty Vial | 35 | Restore 80 MP | Instant |
| Mana Tonic | 2× Silverleaf + Glass Vial | 50 | Restore 80 MP | Instant |
| Superior Mana Tonic | Shimmerbloom + Silverleaf + Glass Vial | 120 | Restore 200 MP | Instant |
| Antidote | Wormwood × 2 + Empty Vial | 20 | Cures poison DoT | Instant |

*Note: "Minor Healing Potion" and "Minor Healing Draught" are currently two separate entries with slightly different ingredients — reconcile to one canonical item name and recipe.*

### Stat Elixirs

| Item | Ingredients | Min Skill | Effect | Duration |
|---|---|---|---|---|
| Elixir of Strength | Shimmerbloom + Iron Dust + Vial | 80 | +5 STR | 30 min |
| Elixir of Intellect | Shimmerbloom + Gold Dust + Vial | 80 | +5 INT | 30 min |
| Elixir of Agility | Shimmerbloom + Feather + Vial | 80 | +5 AGI | 30 min |
| Elixir of Wisdom | Shimmerbloom + Silver Dust + Vial | 85 | +5 WIS | 30 min |
| Elixir of Constitution | Shimmerbloom + Deeproot + Vial | 90 | +5 CON | 30 min |

### High-Tier Elixirs

| Item | Ingredients | Min Skill | Effect | Duration |
|---|---|---|---|---|
| Clarity Draught | Moonpetal + Silverleaf + Deeproot + Vial | 140 | +10 MP regen | 30 min |
| Spirit of the Forest | Moonpetal + Deeproot + Spirit Sage + Vial | 160 | +3 all stats, +5 HP/MP regen | 45 min |
| Grand Elixir | Void Bloom + Spirit Sage + Moonpetal + Grand Vial | 185 | +8 all stats, +10 HP/MP regen | 60 min |

---

## Alchemy — Elemental

| Item | Ingredients | Min Skill | Effect |
|---|---|---|---|
| Fire Elixir | Fire Essence + Empty Vial | 30 | Fire damage boost or fire resistance (to be defined) |
| Shadow Draught | Shadow Essence + Bat Blood + Empty Vial | 40 | Shadow damage boost or stealth assist (to be defined) |

*Effect definitions pending. These are in `recipe_definitions.gd` but have no `SpellData` or `ItemData` effect values yet.*

---

## Alchemy — Black

**Alignment:** Evil or Neutral | **Station:** Alchemy Table

### Weapon Poisons (coat weapon, consume charges on hit)

| Item | Ingredients | Min Skill | Effect | Coat Duration |
|---|---|---|---|---|
| Weak Shadow Poison | Nightshade + Spider Venom + Vial | 25 | 10 shadow dmg/3s on hit for 30s | 10 min |
| Shadow Venom | 2× Nightshade + Spider Venom + Glass Vial | 60 | 20 shadow dmg/3s on hit for 30s | 15 min |
| Virulent Shadow Venom | Nightshade + Void Bloom + Spider Venom Sac + Glass Vial | 150 | 35 shadow dmg/3s on hit for 45s | 20 min |
| Death Draught | Nightshade + Bone Dust + Rotting Fungi + Glass Vial | 110 | 30 poison dmg/3s for 45s | 15 min |

### Thrown Vials

| Item | Ingredients | Min Skill | Effect | Target |
|---|---|---|---|---|
| Plague Vial | Rotting Fungi + Bone Dust + Vial | 50 | Disease DoT 8 dmg/3s for 45s | Single target |
| Virulent Plague Vial | 2× Rotting Fungi + Lich Dust + Glass Vial | 130 | Disease DoT 18 dmg/3s for 60s + -3 CON | Single target |
| Curse Bottle | Grave Flower + Lich Dust + Vial | 90 | -5 to one stat for 60s | Single target |
| Plague Grenade | Rotting Fungi + Bat Blood + Iron Casing | 140 | Disease DoT, small radius | AOE |

### Misc Black Alchemy

| Item | Ingredients | Min Skill | Effect |
|---|---|---|---|
| Blood Elixir | Bat Blood + Iron Shavings + Deeproot + Vial | 100 | +10 STR, +10 dmg, -5 WIS, -10% evasion | 30 min |
| Necromancer's Ink | Lich Dust + Grave Flower + Void Bloom + Vial | 160 | Crafting reagent for Necromantic Scribing (not consumed on use) |

---

## Poison Making

**Alignment:** Neutral/Evil | **Class gate:** Rogue, Necromancer, Shadow Knight, Blood Mage, Witch Hunter, Dark Elf | **Station:** Alchemy Table

| Item | Ingredients | Min Skill | Effect |
|---|---|---|---|
| Poison Vial | 2× Nightshade + Snake Venom Sac + Empty Vial | 25 | Weapon coat: poison DoT |
| Potent Poison | 3× Nightshade + 2× Spider Venom Sac + Empty Vial | 60 | Weapon coat: stronger poison DoT; produces 2 |

---

## Food

Food buffs apply HP regen per tick and stack additively with meditation regen. Only one food buff active at a time (replaced on eating a new food item).

**Station:** Oven | **Skill:** Baking / Cooking

| Item | Ingredients | Min Skill | HP Regen | Duration |
|---|---|---|---|---|
| Bread Loaf | 2× Flour + Water Flask | 0 | +2 HP/tick | 30 min |
| Meat Pie | Wolf Meat + Flour + Raw Egg | 15 | +4 HP/tick | 30 min |
| Mushroom Bread | 2× Wild Mushroom + 2× Flour + Water Flask | 20 | +3 HP/tick | 30 min |
| Berry Tart | 3× Wild Berries + Flour + Honey | 25 | +2 HP/tick + minor STR | 30 min |
| Journeybread | — | — | +4 HP/tick | 180s |

*Journeybread is seeded via Test Panel (debug). Reconcile with recipe or mark as vendor-only.*

---

## Drink

Drink buffs apply MP regen per tick. Only one drink buff active at a time.

**Station:** Brewing Barrel | **Skill:** Brewing

| Item | Ingredients | Min Skill | MP Regen | Duration | Other |
|---|---|---|---|---|---|
| Crude Ale | Barley + Hops + Yeast + Water Flask + Empty Bottle | 0 | +2 MP/tick | 30 min | — |
| Honey Mead | 3× Honey + Yeast + Empty Bottle | 20 | +4 MP/tick | 30 min | — |
| Waterskin | — | — | +5 MP/tick | 180s | Test Panel seed |

*Waterskin is seeded via Test Panel (debug). Define as vendor item or Brewing recipe.*
