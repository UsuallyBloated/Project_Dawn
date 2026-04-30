# Transformations — Brainstorm
*Permanent or semi-permanent changes to the player's body, abilities, or nature. Distinct from buffs/debuffs — transformations redefine what the character is.*

*This document is a design brainstorm. Not all of these will ship. Entries vary in specificity — some are fully sketched, some are just seeds.*

---

## Already Designed (from systems.md)

These are confirmed design targets, documented in the systems reference:

| Transformation | Alignment | Classes | Level | Core Effect |
|---|---|---|---|---|
| **Revenant** | Evil | Necromancer, Shadow Knight, Blood Mage | 20 | Undead body; immune to fear; -CHA; no natural HP regen |
| **Vampire Lord** | Evil | Blood Mage, Shadow Knight | 25 | Lifedrain on auto-attack; sun damage vulnerability |
| **Lich** | Evil | Necromancer | 30 | Vastly increased mana pool; no HP regen |
| **Lycanthrope** | Neutral | Ranger, Druid, Shaman, Monk | 15 | Beast form at night; +STR/+AGI |
| **Exalted** | Exalted | Paladin, Cleric | 30 | Glow aura; undead auto-damage proximity effect |
| **Warden of the Wild** | Exalted | Druid, Ranger | 25 | Commune with animals; nature damage immunity |

### Live — Alignment Drift (class hot-swap)
- **Fallen Paladin** — Paladin reaches Evil tier; loses holy spells, gains shadow/death abilities
- **Redeemed Shadow Knight** — Shadow Knight reaches Exalted; loses dark abilities, gains radiant ones

---

## Alignment-Drift Transformations (Class Hot-Swap Style)

*Same mechanic as Fallen/Redeemed. Trigger is hitting an alignment threshold. Rebuilds spell/skill list without changing stored class.*

### Fallen Cleric
- **Trigger:** Cleric reaches Evil tier
- Loses all healing spells and resurrection
- **Gains:** Dark mending (heals undead/self via necrotic drain), Curse line, ability to raise enemies killed as temporary servants
- *The most disturbing version of this category — a healer turned inside out*

### Corrupted Druid
- **Trigger:** Druid reaches Evil tier
- Nature magic twists: HoTs become DoTs, snares become roots that crush, summons become blighted
- **Gains:** Blight Bloom (AoE poison field), Wither (reverse-HoT draining nature from target), Corpse Vine
- *The forest turns on you — and you let it*

### Enlightened Warrior
- **Trigger:** Warrior reaches Exalted tier
- Does not gain magic, but gains aura-based effects from sustained righteous alignment
- **Gains:** Righteous Stance (passive: undead take bonus damage from auto-attacks), Unyielding (brief CC immunity on activation), Courage Aura (nearby allies get minor morale bonus)
- *Not a magic-user — just someone the light has noticed*

### Tainted Monk
- **Trigger:** Monk reaches Evil tier
- Chi becomes shadow energy; martial discipline inverted into something predatory
- **Gains:** Shadow Step (short-range teleport behind target), Chi Drain (strike that transfers target's stamina to you), Void Stance (evade boost but damage taken dealt back as shadow)
- *The hardest fall — the discipline doesn't go away, it just serves something else now*

### Dark Trapper (Rogue)
- **Trigger:** Rogue reaches Evil tier
- Poisons become curses; backstab becomes soul-strike
- **Gains:** Soul Tap (backstab variant that drains a portion of target's max HP permanently until they rest), Hex Blade (weapon imbued with curse that spreads on kill), Shadow Mark (mark target; they take bonus damage from all sources for duration)

### Redeemed Necromancer
- **Trigger:** Necromancer reaches Exalted tier (extremely difficult — starts at -1600)
- Undead control becomes spirit guidance; pets are willing, not compelled
- **Gains:** Bound Soul (summon willing ancestor spirit as ally; stronger but temporary), Passage Rite (briefly shields a dying ally, buying cast time for a healer), Unshackle (free an undead mob from its controller, turning it neutral)
- *Nobody believes you've done it. The ancestor spirits are grudgingly impressed.*

---

## Earned Permanent Transformations

*Require meeting alignment + class + level conditions. Permanent once triggered. More dramatic than the drift transformations.*

### The Hunger (Vampiric Proto-Stage)
- **Alignment:** Evil
- **Classes:** Any — but Blood Mage and Shadow Knight reach it fastest
- **Level:** 18
- **Trigger:** Accumulated lifedrain casts above a threshold, combined with Evil alignment
- **Effect:** Precursor to Vampire Lord. Gains minor lifesteal on all attacks. Sunlight causes discomfort (visual effect, minor damage). NPCs in cities react with suspicion. Thirst mechanic activates — must feed periodically or suffer stat debuffs
- *The door before the door. Some players stop here. Most don't.*

### Void-Touched
- **Alignment:** Neutral to Evil
- **Classes:** Wizard, Sorcerer, Magician (arcane schools)
- **Level:** 22
- **Trigger:** Casting a high volume of arcane spells without nature or holy counterbalance; the void starts leaking through
- **Effect:** Arcane damage +15%. Occasional uncontrolled spell discharge (visual). Resistance to arcane damage. Eyes become starfield-black. Some NPCs react with academic fascination; others flee
- *You pulled too much from the other side and left a door open. It's fine. Probably.*

### Plague Bearer
- **Alignment:** Evil
- **Classes:** Necromancer, Shaman (dark path)
- **Level:** 24
- **Trigger:** Applying disease/poison effects on a very high number of targets over lifetime
- **Effect:** Passive disease aura (enemies within melee range accumulate a disease stack). Immune to disease and poison. Healing effects on the player are reduced (the corruption resists cleansing). Visual: skin mottled, breathing visible as faint miasma
- *The bodies told you to stop. You didn't.*

### Phantom (Rogue/Shadow specialization)
- **Alignment:** Evil or Neutral
- **Classes:** Rogue
- **Level:** 20
- **Trigger:** Sustained use of stealth combined with Evil/Neutral alignment and a high kill count from stealth
- **Effect:** Partial incorporeality — physical attacks have a small chance to phase through the Phantom (miss regardless of hit roll). Shadow spells cast against the Phantom are partially absorbed. Visual: edges of the character blur and trail
- *You spent so long in the shadow that some of it stuck.*

### Battle-Fury Scar (Berserker Threshold)
- **Alignment:** Neutral to Evil
- **Classes:** Warrior, Monk
- **Level:** 18
- **Trigger:** Taking an extremely high total amount of damage in one's lifetime and surviving; accumulated scars
- **Effect:** At low HP, damage output increases instead of decreasing (inverts the normal combat pressure). Stun/fear resistance. Visual: the scars glow faintly red at low HP. Cannot be charmed while below 25% HP
- *You've been at the edge so many times you stopped being afraid of it.*

### Spirit Merged
- **Alignment:** Any
- **Classes:** Shaman
- **Level:** 28
- **Trigger:** Extended use of ancestor-spirit communion; the bond deepens past the point of separation
- **Effect:** Ancestor spirit becomes semi-visible — always manifested as a faint overlay on the player's body. Shaman spells gain an echo effect (each spell has a small chance to fire twice). Immune to fear and mind control (the spirit holds). Healing from Shaman HoTs improved
- *You asked them to come so many times they decided to stay.*

### Beast King
- **Alignment:** Any
- **Classes:** Beast Master
- **Level:** 25
- **Trigger:** Warder survives a very high number of battles without dying; the bond deepens
- **Effect:** Warder grows in permanent power beyond normal scaling. Player gains passive predator instinct (+DEX, +AGI when warder is within range). When warder dies, player enters a brief rage state. Warder's visual appearance changes to reflect the bond's depth — larger, marked with the player's colors
- *You stopped commanding it. Now you move together.*

### Elemental Fusion
- **Alignment:** Neutral
- **Classes:** Magician, Sorcerer
- **Level:** 26
- **Trigger:** Summoning and dismissing elemental pets an extreme number of times; the boundary dissolves
- **Effect:** Player gains the elemental affinity of whichever school they've used most. Fire fusion: fire resistance + fire damage boost. Ice fusion: movement slow on hit + cold resistance. Each fusion type mutually exclusive — you merge with what you've called most
- *They came when you called them long enough that they started coming without being called.*

### Seraphim Aspect
- **Alignment:** Exalted
- **Classes:** Paladin, Cleric
- **Level:** 35
- **Trigger:** Sustained maximum Exalted alignment; must have resurrected players, healed extreme total HP, and killed a named undead boss
- **Effect:** Wings (cosmetic but powerful signal). Holy aura expanded radius. Undead mobs within a larger radius are automatically damaged and debuffed. Some undead will flee on sight. NPCs kneel
- *You became something the faith always said was possible. Most of them weren't sure they believed it until now.*

### Grove Heart
- **Alignment:** Exalted
- **Classes:** Druid
- **Level:** 30
- **Trigger:** Healing a total threshold of HP in outdoor/natural zones; communing with natural sites
- **Effect:** In natural zones: passive HP regen even in combat. Animals in the zone are non-hostile. Visual: flowers bloom briefly at footsteps. The player becomes partially visible as living wood in certain light — bark texture at the edges. Blight effects in the zone are weakened
- *The forest recognized you and offered the other half of the bargain.*

---

## Race-Specific Transformations

*Locked to one race. Reflect the race's own mythology and history.*

### Dragon Kin (Kobold)
- **Alignment:** Any
- **Classes:** Sorcerer, Shaman
- **Level:** 20
- The Kobold dragon-ancestor mythology activates literally. Small scale patches develop on the face and hands. Minor fire breath ability (short-range, limited use per combat). Enemies may react with the specific confusion of something encountering a Kobold that is actually doing what Kobolds claim they can do
- *The pack said the blood was real. You found out they were right.*

### Kel`varath Ascendant
- **Alignment:** Evil
- **Classes:** Necromancer, Shadow Knight
- **Level:** 28
- Reclaims Dominion-era power. Scale plating thickens visually. Undead control capacity increases (can hold more simultaneous summons). Former Dominion spirits answer more readily. In Kel`varath ruins: gain additional abilities. Other Kel`varath react with a complicated mixture of reverence and fear
- *The Dominion fell. But what the Dominion knew did not.*

### Troll Ancient
- **Alignment:** Neutral to Evil
- **Classes:** Any
- **Level:** 35
- A Troll who has simply survived everything long enough. Size increases slightly. Regeneration rate roughly doubled. Warts calcify into natural armor plating. Memory of old injuries manifests as resistance to the damage type that's killed you most. Very old Trolls develop partial immunity to fire (the usual weakness)
- *You outlasted the things that were supposed to kill you. Now you are a different kind of problem.*

### Dark Spider-Blessed (Dark Elf)
- **Alignment:** Evil
- **Classes:** Enchanter, Shadow Knight, Blood Mage
- **Level:** 22
- Temple hierarchy in Vel'Sharath recognizes the character as favored of the spider-goddess. Web-affinity abilities (root enhancement, climbing surfaces, silk as trap material). Social standing in Dark Elf settlements dramatically elevated. Other races react with instinctive discomfort
- *The Matron's goddess looked at you. You didn't look away.*

### Fae-Old (Fae)
- **Alignment:** Any
- **Classes:** Enchanter, Druid
- **Level:** 30
- A Fae who has lived long enough that they begin shedding the trappings of individual identity and becoming more purely what the Fae are. Illusions gain a second layer of depth — things affected by their Enchantments last longer and are harder to dispel. The Fae becomes partially perceptible in places others cannot reach
- *You stopped being a Fae and started being the Fae. The difference is hard to explain.*

### Ancestor Vessel (Minotaur)
- **Alignment:** Any
- **Classes:** Shaman
- **Level:** 28
- A Minotaur Shaman who has carried enough ancestor-names long enough becomes a living vessel for collective memory. The dead speak through them in crisis. Shaman buffs apply to nearby allies passively at a small fraction of normal power. The weight of the names carved in their horns becomes literally palpable to other characters — NPCs who encounter them sense something enormous looking through Minotaur eyes
- *You asked them to come so many times that the asking became unnecessary.*

### Kobold Alpha
- **Alignment:** Evil
- **Classes:** Warrior, Shadow Knight
- **Level:** 20
- Establishes dominance over other Kobolds absolutely. Wild Kobold mobs in the zone become non-hostile and can be commanded briefly. Kobold NPCs interact differently. Pack tactics bonus becomes a passive always-on effect rather than requiring allies. Size increases slightly (still small; just less small)

### Felhari Spirit-Walker
- **Alignment:** Neutral
- **Classes:** Shaman, Monk
- **Level:** 26
- The clan spirit partially manifests in the character. During combat, a faint spirit-double fights alongside briefly (not a pet — a ghostly mirror that strikes once, then fades). Ancestor communication becomes bidirectional — the ancestors can contact the player, not just be called
- *The clan doesn't end at the living. You always knew that. Now you know what's on the other side of it.*

---

## Multi-Step / Quest-Based Transformations

*These require specific actions in a specific order — not just stat thresholds. Higher barrier, higher reward.*

### The Long Night (Vampire full progression)
A three-stage quest chain:
1. **The Hunger** (auto-triggered, see above) — the infection takes hold
2. **The Reckoning** — a quest to either resist or embrace; requires visiting a specific NPC and making a choice
3. **Vampire Lord** — if embraced; full transformation with all listed effects
- *If resisted at stage 2, the Hunger is cured and a Witch Hunter faction questline unlocks instead*

### The Burning Road (Fallen Paladin → Redemption Arc)
- A Fallen Paladin who wishes to return must complete a multi-stage atonement quest
- Stages involve healing a threshold of damage, freeing imprisoned souls, and confronting the specific deed that broke their alignment
- Success grants **Twice-Tempered** — a unique transformation available only to Paladins who fell and returned. All holy spells available plus one retained dark spell as a reminder. Different visual than standard Paladin
- *You know what you are capable of. You chose differently. The faith trusts that choice more than it trusts inexperience.*

### The Pact (Warlock-adjacent — future class preview)
- Any Evil-aligned character who reaches a specific zone at night and survives an encounter may be offered a demonic pact
- Accepting grants **Demonbound**: one active demonic ability keyed to their class (Warriors get empowered strikes, mages get a demon-aspected version of one spell). Cosmetic: one eye becomes demonic. Faction consequences: major negative with Good-aligned factions
- *This is the mechanical seed for the Warlock class — Demonbound characters are the world's explanation for how Warlocks exist*

### The White Death (Lich full quest)
- Lich is not automatic. The Lich transformation requires the Necromancer to craft a phylactery — a questline involving rare materials, a ritual location, and a specific enemy kill
- The phylactery must be kept safe; if it's destroyed, the transformation reverses and the Necromancer suffers extreme stat penalties while rebuilding it
- *The death is the point. If the death has somewhere to go, you can endure it.*

---

## Mechanical Notes & Open Questions

**Reversibility:**
- Alignment-drift transformations (Fallen/Redeemed and variants) reverse automatically if alignment shifts back
- Earned permanent transformations should be irreversible by default — the point is consequence
- Quest-based transformations could offer a reversal quest at significant cost
- Exception: The Long Night (Vampire) has a designed-in reversal at stage 2

**Visual indicators:**
- Transformations should be visibly legible to other players — not hidden
- NPCs should recognize and react to transformation state; some vendors may refuse service, others unlock
- Consider: a transformed player entering a city should have consequences (Revenant in a Good-aligned city, Vampire Lord anywhere in daylight, etc.)

**Stacking:**
- Most transformations should be mutually exclusive — you are one thing
- Exception candidates: Fallen (alignment drift) + one earned transformation could coexist
- The Lich and Revenant are close enough in concept that they should probably be exclusive

**Trigger design:**
- Threshold-based (total lifedrain casts, damage taken, etc.) is invisible and can surprise players — consider whether this is a feature or a bug
- Level + alignment + class gate is more predictable and lets players aim for it intentionally
- Quest-based is the clearest — players know exactly what they're pursuing

**The Transformations autoload** is already stubbed in project.godot. The field `PlayerStats.transformation` exists. Implementation is a design target.
