# Item Weight Proposal — Full Content Pass

**Status: APPROVED & APPLIED (2026-06-12).** Rulings: chain rescale Option B (three
anchors changed with permission); ore > ingot confirmed; universal 0.1 floor, no
zero-weight items; Arrow Bundle Option A (`stack_size` 200→20); Gold Ingot 2.0,
Brown Steed Whistle 0.1, meats 0.25. **Amended later same day:** smithing family
rescaled ÷12 (ore 0.25 / ingot 0.1 / gold ingot 0.2 / coal 0.2 / mithril 0.1·0.1 /
adamantite 0.5·0.2). Tables below show the final applied values —
this doc is the record; `tools/item_weight_audit.gd` regenerates the live catalog.

**How this was produced:** the audit tool (`tools/item_weight_audit.gd`) generated the
catalog; weights were proposed per category against the 20 playtested anchors, then
adversarially reviewed on three axes — internal consistency (including every recipe in
`data/recipe_definitions.gd`), gameplay pressure (computed against real creation stats
from `data/character_data.gd`), and a hostile-playtester tooltip pass. Six values were
adjusted in review before this doc: rough gems 0.2→0.1 (a ring "set with an uncut gem"
must outweigh the loose gem), cured leather strip 0.3→0.2 (one snake skin cures into
two strips), bat blood 0.2→0.3 (filled vial = potion weight, like every other filled
vial), flour & barley 0.5→0.3 (recipes consume 1–2 per loaf/bottle — these are
portions, not sacks), bear hide 1.0→1.5 (the thick leather slab cut from a large
animal can't outweigh the whole hide), hardwood shaft 0.3→0.2.

Encumbrance reference: capacity = `10 + STR`; over capacity speed falls toward ×0.25
and stamina regen halves; at ≥2× capacity stamina regen stops. Coins weigh 0.02 each
(settled design — 1,000 coins = 20.0, a full fresh capacity).

---

## Open questions — rule on these before I apply

### 1. Worn-gear budget (the big one)

Worn equipment counts 100% toward weight. With the values below (derived from the
locked anchors — iron chain vest 10.0 / leggings 8.0 / copper chain coif 4.0):

| Kit (5 pieces) | Kit total | + weapon | Fresh wearer | Load | Standing still |
|---|---|---|---|---|---|
| Cloth | 5.5 | + staff 5.0 = 10.5 | Human Wizard (STR 12, cap 22) | 48% | fine — 11.5 free |
| Leather | 12.0 | + 2 daggers 4.0 = 16.0 | Human Rogue (STR 12, cap 22) | 73% | fine but thin — 6.0 free |
| Copper chain | 24.0 | + mace 4.0 = 28.0 | Human Cleric (STR 12, cap 22) | **127%** | **encumbered: ×0.84 speed, regen halved** |
| Iron chain | 30.5 | + sword 4.0 = 34.5 | Human Warrior (STR 22, cap 32) | **108%** | **encumbered: regen halved** |

A Human Warrior — the baseline heavy-armor archetype — is encumbered *standing still*
in the gear his class is built around. Minimum STR just to stand in iron chain + sword
is 25; to also carry ~8.0 of supplies/coins, STR 33 (Ogre/Minotaur territory). An Ogre
Warrior (STR 40, cap 50) wears it comfortably. EQ-authentic in *direction*, but ~2× EQ
in *magnitude* — EQ's tier-2 sets ate roughly half a fresh plate class's allowance,
not all of it. It also mutes the coin lever for chain classes: they're over capacity
before the first copper.

- **Option A — ship as-is.** Hardcore: chain is aspirational until you level/buff STR.
- **Option B — rescale chain ~45% (recommended).** Keeps all slot ratios; **changes
  three anchors** (your call, they're playtested): iron vest 10→6, iron leggings 8→5,
  copper coif 4→2.5, and derived: iron coif 5→3, iron boots 5→3, iron gloves 2.5→1.5,
  copper vest 8→5, copper leggings 6→4, copper boots 4→2.5, copper gloves 2→1.5.
  Result: iron kit + sword = 22.5 (Human Warrior 70%, 9.5 free = 475 coins of
  pressure); copper kit + mace = 19.5 (Human Cleric 89% — snug but functional).
- **Option C — count worn gear at 50%** in `encumbrance.gd`. Systems change, not a
  content change, and EQ counted worn at 100% — a feel departure. Not recommended.

**Ruling: Option B — applied**, anchor changes included. Iron kit + sword is now
22.5 (Human Warrior 70%, 9.5 free); copper kit + mace 19.5 (Human Cleric 89%).

### 2. Refining direction — confirm ore > ingot

Proposed: ore 3.0 / ingot 1.5 / coal 1.0 (mithril and adamantite excepted, see table).
Recipes are **2 ore → 1 ingot**, so field-smelting compresses a haul 4:1 by weight,
not 2:1 — a STR-10 miner with a pickaxe (5.0) carries 5 ore raw, or smelts and hauls
the same trip home as 2.5 ingots at 3.75. Strong, correctly-shaped incentive; +3 STR
= +1 ore per trip gives STR real economic value. One dependency: field-smelting only
exists where forges sit near mining nodes (all smelting requires `station=forge`).

**Ruling: confirmed — ore 3.0 / ingot 1.5 applied.**

**Amended (later same day): the whole smithing family rescaled ÷12** — ore 0.25 /
ingot 0.1, gold ingot 0.2 (flavor bump kept), coal 0.2, mithril ore 0.1 / ingot 0.1,
adamantite ore 0.5 / ingot 0.2. Ore > ingot survives (2 ore = 0.5 → 1 ingot = 0.1,
a 5:1 smelt compression) and every lore ordering holds, but ore hauling is no longer
an encumbrance pressure point — a full 20-stack is 5.0, and a STR-10 miner with a
pickaxe can carry three full stacks. The miner's weight lever is now coins and bulk
goods (slabs, clay, drink), not the ore itself.

### 3. Zero-weight allowlist

Proposal ships with **no zero-weight items** — everything is ≥ 0.1. Two near-misses
held at the floor: **Pottery Sketch** (one sheet of paper; the natural test case if
you ever want a "recipe/paper" weightless class) and **Mithril Ingot** (lore says
"nearly weightless"; 0.1 reads as that without a true-zero exception).

**Ruling: universal 0.1 minimum kept — no item in the game weighs 0.**

### 4. Stack pressure + the Arrow Bundle ruling

Worst full-stack burdens at proposed weights (fresh capacity = 20.0 for scale):

| Item | Per | × stack | Full stack |
|---|---|---|---|
| Arrow Bundle | 1.0 | 20 (was 200) | 20.0 after the ruling below |
| Thick Leather Slab | 1.5 | 10 | 15.0 |
| Mechanical Trap | 3.0 | 5 | 15.0 |
| Damaged Wolf Pelt | 0.6 | 20 | 12.0 |
| Crude Ale / Honey Mead / Meat Pie / Lump of Clay | 0.5 | 20 | 10.0 |
| Adamantite Ore | 0.5 | 20 | 10.0 (post-rescale; was 120.0) |
| Bear Hide | 1.5 | 5 | 7.5 |
| Standard ores (×5) | 0.25 | 20 | 5.0 (post-rescale; was 60.0) |
| Metal Bits / Ruined Metal Scraps | 0.1 | 20 | 2.0 |

*(The smithing rows that used to top this table collapsed after the ÷12 family
rescale — see the question-2 amendment.)*

**Arrow Bundle is broken in the data, not the weight.** The item is "a bundle of
twenty fletched arrows" (10c) but ships with `stack_size = 200` — a full stack is
4,000 arrows at 200.0 weight, 10× a fresh capacity, in one slot. The 200 reads like a
stale "200 arrows" from before the item became a bundle. The mass itself is right:
1.0 per bundle = 0.05/arrow.

- **Option A (recommended):** weight 1.0, **and change `stack_size` 200→20** in
  `arrow_bundle.tres` (full stack = 400 arrows = 20.0 — a real EQ-style ammo
  decision). This is the one edit in this pass that goes beyond the `weight` field,
  so it needs your explicit OK.
- **Option B:** the stack unit is a single arrow — weight 0.1, but the name and
  description then need rewording (also beyond weight-only).

**Ruling: Option A — weight 1.0 kept, `stack_size` 200→20 applied** (full stack =
400 arrows = 20.0).

### 5. Quick confirms (one-liners — edit the number if you disagree)

- **Cursed Femur 7.0** — lore says "unnaturally heavy"; this makes it the heaviest 1H
  in the game, just under the 2H war axe (8.0). Softer: 5.0–6.0. Punishing: 8.0+.
- **Mechanical Trap 3.0** — top of the handoff band; a 5-stack is 15.0. Drop to 2.0
  for casual utility, raise to 4.0 if trap loadouts should really hurt.
- **Gold Ingot** — ruled **2.0** for gold-heft flavor, then **0.2** after the family
  rescale (the flavor bump survives, now over the 0.1 ingot band).
- **Cloth Slippers 0.5 vs Patched Cloth Boots 1.0** — slippers are lore-light; the
  patched boots are *boots* (more material), so the 2c junk outweighs the 18c clean
  item. Intentional; unify both at 0.5 or 1.0 if it bugs you.
- **Empty Bottle 0.2** (handoff seeded 0.1) — so bottle (0.2) + drink = flask/ale 0.5
  and vial (0.1) + draught = potion 0.3 both add up.
- **Meats** — ruled flat **0.25** per cut (all four; hides still scale by animal).
- **Brown Steed Whistle** — ruled **0.1** (realism wins: it's a wooden whistle).

---

## Proposed weights

`(anchor)` = already tagged, playtested, **not** part of this apply (listed for
context). All other rows get `weight = <value>` appended in their `.tres`.

### Weapons — daggers 2.0, clubs 3.0, 1H swords 4.0, staves 5.0; junk = clean; lore overrides flagged

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Bent Dagger | 1 | 2 | 2.0 | junk twin of Copper Dagger |
| Bonecrusher's War Axe | 1 | 220 | (anchor) 8.0 | |
| Carved Staff | 1 | 50 | (anchor) 5.0 | |
| Copper Dagger | 1 | 22 | (anchor) 2.0 | |
| Copper Short Sword | 1 | 40 | 4.0 | short-sword class, same as iron |
| Cracked Wooden Club | 1 | 2 | 3.0 | "heavy stick" — between dagger and sword |
| Cursed Femur | 1 | 260 | 7.0 | lore: "unnaturally heavy" — see quick confirm |
| Flamebrand | 1 | 0 | 4.0 | 1H sword class; 0c price ignored |
| Hunter's Shortbow | 1 | 80 | (anchor) 3.0 | |
| Iron Dagger | 1 | 55 | 2.0 | metal tier moves price, not dagger mass |
| Iron Short Sword | 1 | 90 | (anchor) 4.0 | |
| Rusty Short Sword | 1 | 4 | 4.0 | rust loses no mass |
| Splintered Staff | 1 | 3 | 5.0 | junk twin of Carved Staff |

### Armor — chest by material (cloth 2 / leather 4 / copper chain 5 / iron chain 6); legs ×0.8, head & boots ×0.5, gloves ×0.25; junk = clean
*(Option B applied: chain rescaled ~45%, including the three rescaled anchors.)*

| Item | Slot | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Cloth Cap | HEAD | 18 | (anchor) 1.0 | |
| Copper Chain Coif | HEAD | 40 | 2.5 | rescaled anchor (was 4.0) |
| Iron Chain Coif | HEAD | 65 | 3.0 | iron chest ×0.5 |
| Leather Cap | HEAD | 35 | 2.0 | leather chest ×0.5 |
| Worn Cloth Cap | HEAD | 2 | 1.0 | junk = Cloth Cap |
| Cloth Robe | CHEST | 38 | (anchor) 2.0 | |
| Copper Chain Vest | CHEST | 90 | 5.0 | between leather 4 and iron 6 |
| Cracked Leather Vest | CHEST | 3 | 4.0 | junk = Leather Vest |
| Iron Chain Vest | CHEST | 130 | 6.0 | rescaled anchor (was 10.0) |
| Leather Vest | CHEST | 70 | (anchor) 4.0 | |
| Tattered Cloth Tunic | CHEST | 2 | 2.0 | junk = Cloth Robe |
| Cloth Pants | LEGS | 28 | 1.5 | cloth chest ×0.8 |
| Copper Chain Leggings | LEGS | 55 | 4.0 | copper chest ×0.8 |
| Frayed Cloth Pants | LEGS | 2 | 1.5 | junk = Cloth Pants |
| Iron Chain Leggings | LEGS | 110 | 5.0 | rescaled anchor (was 8.0) |
| Leather Leggings | LEGS | 60 | 3.0 | leather chest ×0.8 |
| Cloth Slippers | FEET | 18 | 0.5 | lore-light; see quick confirm |
| Copper Chain Boots | FEET | 35 | 2.5 | copper chest ×0.5 |
| Iron Chain Boots | FEET | 75 | 3.0 | iron chest ×0.5 |
| Leather Boots | FEET | 40 | (anchor) 2.0 | |
| Patched Cloth Boots | FEET | 2 | 1.0 | cloth *boots*, not slippers |
| Scraped Leather Boots | FEET | 2 | 2.0 | junk = Leather Boots |
| Cloth Gloves | HANDS | 18 | 0.5 | cloth chest ×0.25 |
| Copper Chain Gloves | HANDS | 35 | 1.5 | copper chest ×0.25 |
| Iron Chain Gloves | HANDS | 65 | 1.5 | iron chest ×0.25 |
| Leather Gloves | HANDS | 35 | 1.0 | leather chest ×0.25 |
| Rough Leather Bracers | HANDS | 2 | 1.0 | wrist piece, gloves band |
| Torn Cloth Gloves | HANDS | 2 | 0.5 | junk = Cloth Gloves |

### Rings, neck, bag — jewelry 0.1 regardless of gem or price; collar 0.2; pouch 0.5

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Chitinous Ring | 1 | 160 | 0.1 | |
| Rough Emerald Ring | 1 | 120 | 0.1 | gem dropped to 0.1 so ring ≥ loose gem |
| Rough Opal Ring | 1 | 90 | 0.1 | |
| Rough Ruby Ring | 1 | 130 | 0.1 | |
| Rough Sapphire Ring | 1 | 115 | 0.1 | |
| Rough Topaz Ring | 1 | 100 | 0.1 | |
| Shadow Signet | 1 | 120 | 0.1 | light-absorbing lore is visual, not mass |
| Silver Ring | 1 | 55 | 0.1 | |
| Predator's Collar | 1 | 85 | 0.2 | hide loop + teeth, top of neck band |
| Small Pouch | 1 | 20 | 0.5 | per handoff |

### Consumables — potion-likes 0.3 (anchor); bottled drinks 0.5 (flask anchor); baked goods 0.2–0.5 by bulk

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Antidote | 10 | 16 | 0.3 | potion-like |
| Berry Tart | 20 | 5 | 0.2 | smaller than a loaf |
| Bread Loaf | 10 | 4 | (anchor) 0.3 | |
| Crude Ale | 20 | 4 | 0.5 | bottled drink = flask |
| Crude Health Potion | 10 | 8 | 0.3 | crude ≠ lighter |
| Fire Elixir | 10 | 38 | 0.3 | vial-sized |
| Healing Potion | 10 | 28 | (anchor) 0.3 | |
| Honey Mead | 20 | 6 | 0.5 | bottled drink |
| Mana Potion | 10 | 22 | (anchor) 0.3 | |
| Meat Pie | 20 | 6 | 0.5 | meat + crust, top of food band |
| Minor Healing Potion | 10 | 12 | (anchor) 0.3 | |
| Mushroom Bread | 20 | 5 | 0.4 | lore: dense |
| Poison Vial | 10 | 32 | 0.3 | filled vial |
| Shadow Draught | 10 | 38 | 0.3 | filled vial |
| Stale Bread | 20 | 1 | 0.3 | staleness isn't lighter |
| Water Flask | 10 | 3 | (anchor) 0.5 | |

### Mining & smithing — ore 0.25 / ingot 0.1 / coal 0.2 (÷12 family rescale, later ruling); mithril light, adamantite dense; scrap 0.2–0.3

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Adamantite Ingot | 10 | 360 | 0.2 | dense lore carries through smelting (2× band) |
| Adamantite Ore | 20 | 150 | 0.5 | "extraordinarily dense" — 2× the ore band |
| Bronze Ingot | 10 | 22 | 0.1 | |
| Coal | 20 | 4 | 0.2 | |
| Copper Ingot | 10 | 14 | 0.1 | |
| Copper Ore | 20 | 6 | 0.25 | full 20-stack = 5.0 |
| Gold Ingot | 10 | 82 | 0.2 | flavor bump over the 0.1 band (ruled) |
| Gold Ore | 20 | 35 | 0.25 | |
| Iron Ingot | 10 | 22 | 0.1 | |
| Iron Ore | 20 | 10 | 0.25 | |
| Metal Bits | 20 | 4 | 0.1 | pocket scrap — dropped to ingot floor with the rescale |
| Mithril Ingot | 10 | 180 | 0.1 | "nearly weightless" — floor |
| Mithril Ore | 20 | 75 | 0.1 | lore-light, still the lightest ore |
| Ruined Metal Scraps | 20 | 1 | 0.1 | same scrap as Metal Bits |
| Rusted Buckle | 20 | 1 | 0.1 | single small fitting |
| Silver Ingot | 10 | 42 | 0.1 | |
| Silver Ore | 20 | 18 | 0.25 | |
| Tin Ingot | 10 | 12 | 0.1 | |
| Tin Ore | 20 | 5 | 0.25 | |

*(Rescale follow-up, ruled: the scrap band (Metal Bits / Ruined Metal Scraps /
Rusted Buckle) was dropped to the 0.1 floor so loose scrap no longer outweighs a
finished ingot.)*

### Hides & tailoring — hides by animal size (condition is a price axis, not mass); fibers/threads 0.1

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Bear Hide | 5 | 14 | 1.5 | largest hide; one bear hide ≈ one slab |
| Boar Hide | 5 | 10 | 0.8 | |
| Cloth Scraps | 20 | 5 | 0.1 | |
| Cured Leather Strip | 20 | 10 | 0.2 | ≤ every source skin (snake skin cures 2) |
| Damaged Wolf Pelt | 20 | 4 | 0.6 | all wolf pelts equal mass |
| Flax | 20 | 3 | 0.1 | |
| Fresh Wolf Pelt | 5 | 10 | 0.6 | |
| Linen Thread | 20 | 6 | 0.1 | |
| Pristine Wolf Pelt | 5 | 20 | 0.6 | |
| Ruined Silk | 20 | 1 | 0.1 | |
| Sable Wing Membrane | 1 | 15 | 0.1 | "thin as parchment" |
| Sinew | 20 | 6 | 0.1 | |
| Snake Skin | 10 | 5 | 0.2 | shed skin, light |
| Spiderling Silk | 20 | 8 | (anchor) 0.1 | |
| Tattered Pelt | 20 | 1 | 0.5 | generic small hide |
| Thick Leather Slab | 10 | 18 | 1.5 | per handoff; = one tanned bear hide |
| Thick Silk Thread | 10 | 12 | 0.1 | thick or not, still thread |

### Alchemy & essences — dry reagents/powders/essences 0.1; venom sacs 0.2; vial 0.1 + contents 0.2 = potion 0.3

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Bat Blood | 20 | 5 | 0.3 | filled vial = potion weight |
| Bat Wing | 20 | 5 | (anchor) 0.1 | |
| Bloodmoss | 20 | 6 | 0.1 | |
| Bone Fragment | 20 | 2 | (anchor) 0.1 | |
| Empty Bottle | 20 | 3 | 0.2 | + 0.3 of drink = 0.5 flask/ale |
| Empty Vial | 20 | 4 | 0.1 | + 0.2 of draught = 0.3 potion |
| Feverfew | 20 | 5 | 0.1 | |
| Fire Essence | 10 | 15 | 0.1 | palm-sized shard; price is tier, not mass |
| Ground Bone | 20 | 4 | 0.1 | |
| Ice Essence | 10 | 15 | 0.1 | |
| Nightshade | 20 | 8 | 0.1 | |
| Pristine Venom Sac | 1 | 35 | 0.2 | quality isn't mass |
| Shadow Essence | 10 | 18 | 0.1 | |
| Snake Venom Sac | 10 | 8 | 0.2 | fluid-filled organ |
| Spider Venom Sac | 10 | 10 | 0.2 | |
| Wormwood | 20 | 7 | 0.1 | |

### Fletching & ammunition — small components 0.1; wood stock 0.2–0.5; bundle pending question 4

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Arrow Bundle | 20 | 10 | 1.0 | ruled: `stack_size` 200→20 applied |
| Arrow Fletching | 20 | 5 | 0.1 | |
| Feather | 20 | 3 | 0.1 | |
| Flint | 20 | 2 | 0.2 | raw stone chunk, denser than one knapped point |
| Flint Arrowhead | 20 | 4 | 0.1 | |
| Hardwood Shaft | 20 | 6 | 0.2 | thin wood length |
| Pliable Wood | 10 | 6 | 0.5 | bow-limb stock; full stack = one Carved Staff |

### Gems & jewelcrafting — rough gems 0.1 (so set rings stay coherent); wire/settings 0.1

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Gold Wire | 20 | 20 | 0.1 | |
| Rough Emerald | 10 | 35 | 0.1 | pocket pebble; price is tier |
| Rough Opal | 10 | 30 | 0.1 | |
| Rough Ruby | 10 | 40 | 0.1 | |
| Rough Sapphire | 10 | 35 | 0.1 | |
| Rough Topaz | 10 | 30 | 0.1 | |
| Silver Wire | 20 | 15 | 0.1 | |
| Tarnished Silver Setting | 10 | 12 | 0.1 | |

### Tools, tinkering & pottery — iron tools 4–5; light tools 1–2; components 0.1–0.3 by metal mass; clay chain 0.5→0.5→0.4

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Coiled Spring | 20 | 10 | 0.2 | |
| Crude Clockwork | 10 | 160 | 0.5 | per handoff |
| Fired Clay Bowl | 10 | 8 | 0.4 | firing drives off water |
| Lump of Clay | 20 | 3 | 0.5 | wet clay is dense; 20-stack = 10.0 haul |
| Mechanical Trap | 5 | 90 | 3.0 | see quick confirm |
| Pickaxe | 1 | 10 | 5.0 | per handoff; flat gatherer tax |
| Pottery Sketch | 1 | 8 | 0.1 | paper — zero-allowlist candidate (question 3) |
| Sewing Needle | 5 | 5 | 0.1 | |
| Skinning Knife | 1 | 8 | 1.0 | utility blade, half a dagger |
| Small Gear | 20 | 8 | 0.1 | "tiny" |
| Small Metal Plate | 20 | 10 | 0.3 | most metal of the components |
| Small Metal Sheet | 20 | 8 | 0.2 | |
| Smithing Hammer | 1 | 15 | 4.0 | per handoff |
| Tinkering Kit | 1 | 25 | 2.0 | per handoff |
| Unfired Pottery | 5 | 5 | 0.5 | shaped clay, same mass as the lump |

### Cooking & brewing — portions 0.2–0.5 around the bread anchor; meats flat 0.25 (standard cut, ruled)

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Barley | 20 | 3 | 0.3 | recipe portion, not a sack |
| Flour | 20 | 4 | 0.3 | 2 flour → 1 loaf; portion-sized |
| Gnoll Meat | 10 | 2 | 0.25 | |
| Honey | 20 | 5 | 0.4 | dense pot, smaller than a flask |
| Hops | 20 | 3 | 0.2 | dried flowers |
| Raw Egg | 20 | 3 | 0.2 | |
| Rat Meat | 10 | 2 | 0.25 | standard cut |
| Salt | 20 | 3 | 0.3 | pantry pouch |
| Snake Meat | 10 | 3 | 0.25 | |
| Wild Berries | 20 | 4 | 0.2 | a handful |
| Wild Fruit | 20 | 4 | 0.3 | |
| Wild Mushroom | 20 | 4 | 0.1 | single mushroom |
| Wolf Meat | 10 | 4 | 0.25 | |
| Yeast | 20 | 3 | 0.1 | small cake |

### Quest tokens & special — tiny stackables 0.1; palm-sized uniques 0.3–0.5; whistle 0.1 (ruled)

| Item | Stack | Vendor (c) | Weight | Note |
|---|---|---|---|---|
| Brown Steed Whistle | 1 | 350 | 0.1 | ruled: realism over carry-tax |
| Gnoll Chief's Seal | 1 | 25 | 0.4 | stamped iron disc |
| Gnoll Tooth | 20 | 3 | 0.1 | |
| Rotfang's Fang | 1 | 20 | 0.5 | lore: "massive" |
| Undying Marrow | 1 | 60 | 0.4 | dense bone core |
| Worn Coin Purse | 10 | 1 | 0.1 | empty cloth |

---

## Findings out of scope for this pass (surfaced by review — follow-ups, no action now)

- **Fae casters break the capacity formula.** Creation stats have no floor; Fae STR
  −15 → a Fae Wizard has STR −5 and capacity **5.0** — under the 5.5 cloth kit alone.
  Needs a capacity floor (e.g. 15.0) in `encumbrance.gd` or a creation STR floor.
  Systems task, not content. **User direction (2026-06-12): Fae get their own line
  of clothing** — they're far smaller than even gnomes, so a unique Fae gear
  category (its own weights, presumably much lighter) is planned design work, not
  a patch to the human-sized cloth set.
- **Wolf pelt stack asymmetry:** Damaged stacks to 20 (full stack 12.0) while
  Fresh/Pristine stack to 5 (3.0) — the junk pelt is the heaviest to hoard by 4×.
  Stack sizes are out of scope; flagging the oddity.
- **Adamantite Ore full stack (120.0)** exceeds every carry cap — harmless (the carry
  limit binds first; the stack limit is honest fiction), noting it pre-empts a forum
  thread.
- **Brown Steed Whistle** could take one description clause ("heavier than it looks")
  so the 0.5 reads intentional. Description edits are out of scope here.
