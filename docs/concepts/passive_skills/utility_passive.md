# Passive Utility Skills

Utility skills are passive skills that train through non-combat actions. They're design targets — none are implemented yet.

Unlike weapon, armor, and casting skills which train continuously through repeated combat use, most utility skills are deliberately slower to train, representing specialized knowledge.

---

## Skill List

### Meditate
Accelerates out-of-combat mana regeneration while sitting.

- **What trains it:** Time spent successfully meditating (sitting + out of combat + mana not full).
- **Benefit:** Each point of Meditate skill increases the mana-per-second recovery rate while sitting. At max skill, mana recovery while meditating is roughly 3× the base regen rate.
- **Who trains it:** All casting classes. Hybrid casters (Paladin, Shadow Knight, Shaman, etc.) have lower caps.

| Class | Meditate Cap |
|---|---|
| Wizard, Magician, Sorcerer, Enchanter, Necromancer | 250 |
| Cleric, Druid, Blood Mage | 235 |
| Shaman, Bard, Witch Hunter, Ranger, Beast Master | 175 |
| Paladin, Shadow Knight | 150 |
| Warrior, Monk, Rogue | — |

**Implementation note:** Meditate is tightly coupled with the Meditation system (sitting + regen). When that feature is built, Meditate skill should be the primary control knob on meditate regen rate.

---

### Bind Wound
Apply pressure and makeshift bandages to stop bleeding; restores a small amount of HP out of combat.

- **What trains it:** Each successful bind wound action.
- **Benefit:** Higher skill restores more HP per bind (scales from ~5% max HP at skill 1 to ~25% at max skill). Bind Wound cannot heal above 50% of max HP — it only staples wounds, it doesn't cure them.
- **Cooldown:** 30 seconds between uses. Must be out of combat.
- **Who trains it:** All classes. Warriors, Monks, and Rogues have the highest caps — survival skills for classes who fight without a healer.

| Class | Bind Wound Cap |
|---|---|
| Warrior, Monk, Rogue, Ranger | 250 |
| Witch Hunter, Beast Master, Bard | 200 |
| Shadow Knight, Paladin, Shaman | 175 |
| Cleric, Druid | 150 |
| All arcane casters | 100 |

---

### Safe Fall
Reduces fall damage through trained body mechanics — rolling into a landing, distributing impact.

- **What trains it:** Taking fall damage (each survivable fall is a learning opportunity).
- **Benefit:** `fall_damage = base_fall_damage * (1.0 - safe_fall_skill / cap * 0.80)` — at max skill, 80% fall damage reduction. A Monk at max can survive falls that would kill a Warrior.
- **Who trains it:** Rogues and Monks primarily. Rangers and Beast Masters also learn it.

| Class | Safe Fall Cap |
|---|---|
| Monk | 250 |
| Rogue | 225 |
| Ranger, Beast Master | 175 |
| Bard, Witch Hunter | 125 |
| All others | 50 |

---

### Forage
Find edible plants, berries, small game, and herbs in the surrounding environment.

- **What trains it:** Attempting to forage (active button or command, with a cooldown).
- **Benefit:** Higher skill = better chance of finding something, and access to rarer finds (herbs used in Alchemy and Poison Making at higher levels).
- **Who trains it:** Rangers and Druids primarily; most classes have a minimal fallback.

| Class | Forage Cap |
|---|---|
| Ranger | 250 |
| Druid | 225 |
| Shaman, Beast Master | 150 |
| Monk | 100 |
| All others | 50 |

**Implementation note:** Forage is also a Ranger class identity feature. The Forage UI could be a small HUD button that triggers a cooldown-gated find attempt.

---

### Swimming
Determines how quickly the breath meter depletes underwater and how fast the character swims.

- **What trains it:** Time spent swimming underwater.
- **Benefit:** Slower breath drain; higher surface and dive speed. At max skill, breath lasts ~3× as long as at skill 0.
- **Who trains it:** All classes. Kel`varath have a racial bonus (+50 to starting value) — their lizardfolk nature makes them exceptional swimmers.

| Class | Swimming Cap |
|---|---|
| All classes | 200 |
| Kel`varath (racial) | +50 starting bonus |

---

### Sense Heading
Innate directional awareness — helps with navigation, particularly in dungeons and at night.

- **What trains it:** Passive; trains simply from moving around the world for a long time.
- **Benefit:** At low skill, you can tell which of the four cardinal directions you're facing. At high skill, you get precise compass heading. Relevant when a map/minimap is implemented.
- **Who trains it:** All classes. Rangers and Druids have higher caps through their wilderness expertise.

| Class | Sense Heading Cap |
|---|---|
| Ranger, Druid | 200 |
| All others | 150 |

---

### Begging
The art of appealing to NPCs for charity — coin, food, or information.

- **What trains it:** Attempting to beg from an NPC (active command, per-NPC cooldown).
- **Benefit:** Higher skill = higher chance NPCs respond with a gift rather than dismissal or hostility. CHA stat contributes as a multiplier.
- **Flavor:** High alignment players receive a bonus to begging from Good-faction NPCs. Evil-aligned players may receive more from morally gray vendors.
- **Who trains it:** All classes, but Bards and Rogues have the highest caps — silver tongues and nimble fingers.

| Class | Begging Cap |
|---|---|
| Bard | 250 |
| Rogue | 200 |
| Enchanter | 175 |
| All others | 100 |

---

## Notes on Grouping

These utility skills form a natural fourth column in any skills UI window, separate from weapon, armor, and casting skills. They're slower to cap, less combat-critical, and often tied to quality-of-life features (regen, navigation, survival). Their implementation priority is lower — most depend on systems (underwater, foraging zones, bandage items) that don't exist yet.

**Suggested implementation order** when the time comes:
1. Meditate (paired with Meditation sitting system)
2. Bind Wound (pairs with a consumable bandage item)
3. Safe Fall (pairs with fall damage implementation)
4. Forage (pairs with zone resource nodes)
5. Swimming (pairs with underwater zones and breath meter)
6. Sense Heading / Begging (flavor; lowest priority)
