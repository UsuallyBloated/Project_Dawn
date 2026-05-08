# Creature Heights & Model Reference

**Last Updated:** 2026-05-05  
**Purpose:** Canonical height reference for building character models, scaling proportions, and NPC/mob dimensions.

---

## Playable Race Heights

All heights in **meters** (M); proportions assume Godot's default humanoid scale (~1.8M = human adult).

| Race | Height (M) | Notes | Proportions |
|---|---|---|---|
| **Fae** | 0.60–0.85 | Impossibly small | Delicate, fairy-like, large eyes |
| **Gnome** | 0.90–1.05 | Child-sized, stout torso | Short legs, rounded belly, large head |
| **Halfling** | 0.95–1.10 | Compact, delicate | Proportion similar to Gnome but slimmer |
| **Kobold** | 1.00–1.20 | Dog-faced, wiry | Hunched posture, bat ears, tail (cosmetic) |
| **Dwarf** | 1.20–1.35 | Blocky, massive shoulders | Barrel chest, thick limbs, small head |
| **Wood Elf** | 1.55–1.70 | Lean, athletic | Muscular calves, defined shoulders |
| **Elf** | 1.60–1.75 | Graceful, slender | Longer limbs, lighter frame |
| **Dark Elf** | 1.65–1.80 | Sinuous, angular | Lithe, prominent cheekbones |
| **Half-Elf** | 1.65–1.80 | Human-like with elven features | Blend of both parents |
| **Human** | 1.70–1.85 | Baseline humanoid | Balanced |
| **Felhari** | 1.75–1.95 | Feline, athletic | Digitigrade legs (in animations), feline face |
| **Kel`varath** | 1.85–2.10 | Lizardfolk, scaled | Reptilian posture, tail (cosmetic, non-collision) |
| **Half-Ogre** | 2.00–2.25 | Ogre-human hybrid | Massive but less brutish than pure Ogre |
| **Minotaur** | 2.20–2.50 | Bull-headed, muscular | Barrel chest, hooved feet, thick horns |
| **Troll** | 2.30–2.60 | Savage, hunched | Disproportionately long arms, jutting brow |
| **Ogre** | 2.40–2.70 | Brutish giant | Massive shoulders, long arms, thick neck |

---

## NPC & Creature Heights

### Humanoid NPCs (Vendors, Dialogue)

| NPC | Race | Height (M) | Role |
|---|---|---|---|
| **Aldric the Guard** | Human | 1.80 | Guard, quest-giver |
| **Elara** | Half-Elf | 1.75 | General Merchant |
| **Brom** | Dwarf | 1.30 | Provisioner |
| *[To be filled as NPCs are added]* | — | — | — |

### Enemy Creatures

#### Quadruped / Non-Humanoid

| Creature | Type | Height (M) | Length (M) | Notes |
|---|---|---|---|---|
| **Rat** | Rodent | 0.25 | 0.50 | Head-sized, underground hunter |
| **Giant Spider** | Arachnid | 0.60 | 1.50 | Leg span; body 0.4M |
| **Sable** | Shadow Bat | 0.70 | 1.40 | Wing span ~3M when extended; nocturnal |
| **Ancient Crawler** | Spider | 0.80 | 2.00 | Massive body, eight articulated legs |
| **Wolf** | Canine | 0.95 | 1.80 | Shoulder height; skeletal structure |
| **Rotfang** | Mutant Wolf | 1.40 | 2.30 | Shoulder height; scarred, larger |
| **Gnoll** | Humanoid-canine | 1.70 | — | Upright posture, dog-like head |
| **Skeleton** | Undead | 1.70–1.85 | — | Human proportions, no flesh |
| **The Undying** | Revenant Knight | 1.85 | — | Armored skeletal warrior |
| **Greth Bonecrusher** | Gnoll Chief | 2.00 | — | Broader shoulders, commanding presence |

---

## Scale Guidelines for Modeling

### Head Size
- **Humanoids:** Head = 1/7–1/8 of total body height
  - Elves/Half-Elves/Dark Elves: Slightly larger, more angular heads
  - Dwarves: Proportionally larger heads (1/6 ratio)
  - Ogres/Trolls/Minotaurs: Smaller heads relative to body (1/9 ratio)
- **Small races (Gnomes/Halflings/Fae):** Head = 1/6–1/7 (larger proportional to body)

### Eye Line
- Typically 1/10 from top of head
- For Fae: Eyes are proportionally larger (anime-like)
- For reptilians (Kel`varath): Side-set eyes

### Torso to Limbs
- **Elf:** Long, lean limbs (arm length 40% of height)
- **Dwarf:** Short limbs (arm length 30% of height), wide shoulders
- **Ogre/Troll:** Disproportionately long arms (arm length 45%+ of height)
- **Humanoid quadrupeds (Gnoll):** Chest height 70% of upright standing height

### Stance Considerations
- **Combat ready:** Slight crouch raises center of gravity 5–10% lower
- **Relaxed:** Standing slightly taller
- **Sitting:** Height reduces to 50–60% (for rest/meditation system)

---

## Collision & Interaction Heights

Use these for hitbox, camera height, and interaction sphere scaling:

| Category | Height Multiplier | Notes |
|---|---|---|
| **Humanoid (Human-sized)** | 1.0× | Use 0.3M radius capsule |
| **Tall (Ogre/Troll/Half-Ogre)** | 1.3–1.5× | Use 0.35–0.40M radius |
| **Small (Gnome/Halfling/Fae)** | 0.5–0.7× | Use 0.20–0.25M radius |
| **Giant creatures (spiders)** | 1.5–2.0× | Leg-sized hitboxes per limb |

**Player camera height:** Position camera 0.1–0.15M above head for over-shoulder view.

---

## Godot Implementation Notes

### Model Scale Factor
Each race should have a base scale applied to a canonical "medium humanoid" model:
- Small races (Fae, Gnome, Halfling): **0.5–0.65× scale**
- Medium races (Human, Elf, Dwarf, Kobold, Felhari): **0.85–1.0× scale**
- Large races (Ogre, Troll, Half-Ogre, Minotaur): **1.3–1.5× scale**
- Extra-large creatures (Ancient Spider, Rotfang): **1.5–2.0× scale**

### Animation Considerations
- **Walking stride:** Taller races cover ~0.6M per step; small races ~0.3M
- **Jump height:** All races ~0.5M apex (ability-gated for gameplay balance)
- **Combat reach:** Melee range ~1.0M from center; scales with race size up to 1.3M for Ogres/Trolls

### Ragdoll / Death Behavior
- Tall races fall over more dramatically (visually satisfying)
- Small races collapse onto themselves (less sprawl)
- Quadrupeds (wolves) crumple differently than bipeds

---

## Design Consistency Checklist

- [ ] All playable race models use canonical heights
- [ ] NPCs follow humanoid guidelines (no floating heads or misaligned feet)
- [ ] Enemy creatures scaled appropriately for combat proximity feel
- [ ] Camera height tuned per race for consistent over-shoulder view
- [ ] Collision capsules match model proportions (no clipping through terrain)
- [ ] Animations account for stride length / reach differences
- [ ] UI elements (nameplates, floating numbers) scale with creature size

---

## Future Expansions

### Racial Variants
- Gender dimorphism (M/F height variance ±5–10%)
- Age tiers (youth, adult, elder with proportional scaling)
- Mutation/corruption variants (scarred, cursed, enlarged by magic)

### Equipment Impact
- Heavy armor adds ~0.05M effective height (visual bulk)
- Mounted on steed: Adds ~1.5M to effective standing height

### Transformation Heights
- Revenant: Slight shrinking (bone structure is denser, appears shorter; same collision height)
- Lich Form: Slightly elevated/spectral (hover 0.2M above ground)
- Dragon Kin / Other transformations: TBD per transformation design

---

## Reference Links
- Character Setup: [character_setup.gd](autoloads/character_setup.gd)
- Character Data: [character_data.gd](data/character_data.gd)
- Player Model: [player.tscn](scenes/player.tscn) *(to be created)*
- Enemy Template: [enemy.gd](scripts/enemy.gd)

---

**Draft by:** Claude Code  
**Awaiting:** Designer approval and first model assets
