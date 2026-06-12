# Race Expansion Brainstorm

*Working notes from a brainstorm pass on adding new races. Nothing here is final.
Captured to keep the design conversation from being lost between sessions; promote
items to `docs/concepts/races/` or `docs/concepts/world/factions/` when ready.*

Date opened: 2026-05-18.

---

## Outcome at a glance

| Race | Status | Niche |
|---|---|---|
| **Aerathi** (cliffside Avian, "the Stoop-kin") | **Drafted** — `docs/concepts/races/aerathi.md` | Cliff/mountain eyrie; physical/martial |
| **Vesperin** (canopy Avian) | **Drafted** — `docs/concepts/races/vesperin.md` | Jungle canopy nest-city; caster/bard |
| **Sylphari** | **Drafted** — `docs/concepts/races/sylphari.md` | Jungle grove keepers; plant-blooded |
| Sporeborn (Mushroom folk) | NPC faction | Deep cave / underground; fungal druids |
| Saurian | NPC faction | Jungle/swamp ambushers; venom signature |
| Bog-stalkers | NPC faction | Marshland east of Khala; amphibian |
| Canopy-dwellers (non-Avian) | NPC faction | Reclusive small humanoids; ambush mobs |

**Decided 2026-05-18:** the two Avian cultures are two distinct races (like
Elf / Wood Elf — the game has no sub-race mechanic). Names: Aerathi (cliffside) and
Vesperin (canopy); "Stoop-kin" kept as the Aerathi epithet in lore. "Sylari" dropped
(too close to Sylphari). Draft stat blocks + racial abilities live in the In Design
section of `race_stats.md`.

---

## Playable candidates

### Avian — Cliffside (working names: Raptori, Aerathi, Stoop-kin)
- **Coding:** hawk / eagle / owl; broad-winged, heavy build for an Avian.
- **Society:** solitary or small-eyrie; honor and hunt culture; territorial.
- **Mechanics:** high STR / AGI, low-light vision, glide + reduced fall damage,
  fragile hollow bones (low CON cap).
- **Classes:** Warrior, Paladin, Monk, Ranger, Beast Master, Bard, Rogue.
- **Home:** fortress-eyrie carved into a sea cliff or mountain spire.

### Avian — Canopy (working names: Sylari, Vesperin, Songkin)
- **Coding:** songbird / parrot / corvid; smaller, lighter, vivid plumage.
- **Society:** flock culture; communal nest-villages, trade and oral history.
- **Mechanics:** high AGI / INT / CHA, glide, voice-based passives (Bard
  performance, Languages gain), fragile hollow bones (low CON cap).
- **Classes:** Bard, Enchanter, Magician, Sorcerer, Wizard, Rogue, Ranger.
- **Home:** multi-tree canopy city with rope bridges and woven nests — fills the
  jungle niche that opened this brainstorm.

### Avian — shared traits
- Hollow-boned and fragile across both sub-races.
- Glide, not true flight; reduced fall damage.
- Bard is the cultural calling that bridges cliffside and canopy peoples. Avian
  Bards are the natural diplomats between the two.

### Sylphari — plant-blooded grove keepers
- **Niche:** jungle Druid / Shaman heavy; aesthetic differentiator from Wood Elves
  must be sharp or they read as redundant.
- **Mechanics (draft):** photosynthesis passive (slow HP regen in sunlight),
  bark-skin AC bonus, weak to fire, high WIS, low CON.
- **Aesthetic direction — pick from / combine:**
  - **Bark-skin, not leaf-skin.** Patterned like birch, rosewood, or aspen — bone
    structure visible underneath. Reads as "person carved from a tree."
  - **Seasonal phenotype.** Coloration shifts on a slow cycle — spring-pale with
    blossom features, lush green in summer, amber/red in autumn, gray-brown and
    dormant in winter. Cosmetic or a small stat shift; huge visual identity win.
  - **Bioluminescent sap.** Veins glow faintly at night — under the skin, in the
    eyes, along old scars. Strong presence in dim zones.
  - **Flowering features instead of hair.** Hair as petals, moss, vines, or
    hanging seed-pods. Lets portraits go dramatic.
  - **Hollow-light build.** Tall, skeletally lean, almost gaunt — *carved*, not
    *lush*. Pairs with low CON / high WIS+AGI.
  - **Cultural lichen-marking.** Living moss and lichen cultivated on the skin as
    clan markings, status, profession. Tattoos, but grown. Unique tradeskill hook.
- **Recommended combo:** bark-patterned skin + seasonal phenotype + flowering
  hair. Visually distinct from every existing race; mechanically cheap.

---

## NPC factions

### Sporeborn (mushroom folk)
- Deep-cave druidic culture; spore-cloud passive auras as a recognizable combat
  signature.
- Considered for playable; character-design space felt limited — promoted to NPC
  faction. Slots well into the lower levels of the procedural dungeon generator.

### Saurian
- Jungle and swamp ambushers; venomous attacks, cold-blooded weakness.
- Considered for playable; felt redundant alongside existing reptilian-adjacent
  races. Strong recurring antagonist faction — gives Rangers and Beast Masters a
  distinct quarry with a learnable mechanical signature.

### Bog-stalkers (amphibian)
- Frog / newt humanoids from the marshland east of the Khala Savannahs.
- Canonically links to existing Felhari geography as wary neighbors.

### Canopy-dwellers (non-Avian)
- Small, reclusive humanoids in deep jungle.
- Ambush mobs that drop from trees; or an isolated village quest hook rather than
  a full faction. Deliberately not Avian — different silhouette and culture.

---

## Open questions

- **Homelands on the atlas.** Aerathi eyrie: which coast or range? Vesperin canopy
  city and Sylphari groves: same jungle (forces cultural interaction) or adjacent
  biomes (cleaner starting zones)? The jungle region itself is new territory for
  the atlas.
- **Saurian and Sporeborn geography.** Where on the world atlas do they sit? The
  procedural dungeon generator is a natural home for Sporeborn; Saurian want a
  surface jungle region distinct from wherever the Vesperin end up.
- **Class-list maybes.** Flagged "under discussion" in the race files: Aerathi
  Shaman (and a debatable Druid block); Vesperin Cleric and Druid; Sylphari Monk
  and Sorcerer. Resolve, then add the three races to
  `race_class_restrictions.md` and its matrix.
- **Stat balance pass.** Draft blocks in `race_stats.md` (In Design section) are
  first-pass; totals 520–529. Photosynthesis vs the planned food/water regen
  gating needs a decision.
- **Integration checklist (when promoting to playable):** `data/character_data.gd`
  (race list + `LOCKED_COMBOS`), `races.md` master table,
  `docs/reference/creature_heights.md`, languages (`data/language_definitions.gd`),
  starting-zone lore in `docs/concepts/world/`.
