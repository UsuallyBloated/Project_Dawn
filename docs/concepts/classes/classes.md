## Classes

*Seventeen classes are currently available. Several have race restrictions reflecting culture, physiology, or the requirements of the discipline. See `LOCKED_COMBOS` in `data/character_data.gd` for current code state — full restrictions are design targets, not yet fully implemented.*

### Class List

| Class | Role | Alignment | Power Source |
|---|---|---|---|
| **Warrior** | Melee / Tank | Any | Martial training |
| **Paladin** | Holy Warrior | Good only | Divine faith |
| **Shadow Knight** | Dark Warrior | Evil preferred | Dark faith / undeath |
| **Cleric** | Healer / Support | Any | Deity |
| **Druid** | Nature Caster | Any | Living world |
| **Shaman** | Spirit Caster | Any | Ancestor spirits |
| **Beast Master** | Melee Hybrid / Pet | Any | Bond with nature and animal spirits |
| **Rogue** | Stealth / DPS | Any | Skill |
| **Monk** | Unarmed Martial | Any | Inner discipline |
| **Ranger** | Nature / Archer | Any | Skill + nature |
| **Witch Hunter** | Anti-Magic | Good preferred | Training |
| **Bard** | Support / Hybrid | Any | Music magic |
| **Magician** | Arcane DPS | Any | Study (generalist) |
| **Wizard** | Arcane DPS | Any | Study (specialist) |
| **Sorcerer** | Arcane DPS | Any | Innate bloodline |
| **Enchanter** | Crowd Control | Any | Mind magic |
| **Necromancer** | Undead Master | Evil preferred | Death magic |
| **Blood Mage** | Dark Caster | Neutral–Evil | Life force |

*Planned future classes: Assassin (stealth / kill), Warlock (pact magic).*

### Pet Classes

Three classes use companions in combat, each with a fundamentally different relationship to them:

| Class | Pet Type | Duration | Control |
|---|---|---|---|
| **Beast Master** | Permanent spirit warder — levels with the character | Always present | Fights automatically; Warder's Fury is the only mid-fight command |
| **Necromancer** | Summoned undead skeleton | Persistent until killed or dismissed | Fights automatically |
| **Enchanter** | Charmed enemy | 60 seconds | Fights automatically; must re-charm before timer expires |

### Arcane Caster Distinctions

Four classes draw on arcane power. They are related but not interchangeable:

| Class | Power Source | Strength | Weakness |
|---|---|---|---|
| **Magician** | Learned — broad generalist spell pool | Versatile; reasonable in most situations | No ceiling, no floor — master of none |
| **Wizard** | Studied — spells memorized from a spell book | Highest damage ceiling; widest spell variety | Finite resources; goes dry; demands preparation |
| **Sorcerer** | Innate — born with it, cannot be removed | Always-on; no preparation required | Fewer spells known; less adaptable |
| **Enchanter** | Mental / social — bends will and perception | Best crowd control in the game; group-wide debuffs | No direct damage; very high skill floor |

### Good-Aligned Classes

- **Paladin** — Holy warrior in service to a good-aligned deity. Healing, protection, and undead-slaying. Requires genuine faith; cannot be performed by evil-aligned races.
- **Witch Hunter** — Anti-magic specialist; hunts corrupted spellwork and those who wield it. Morally committed without being religious. Deeply hostile to evil-aligned casters by vocation.

### Neutral Classes

Most classes carry no inherent moral weight — they are disciplines, not callings. Warrior, Beast Master, Rogue, Monk, Ranger, Bard, Magician, Wizard, Sorcerer, Enchanter, Cleric, Druid, and Shaman are open to any alignment. The player's choices, not the class, determine how they are remembered.

### Evil-Aligned Classes

- **Shadow Knight** — Inverted paladin. Requires commitment to a dark patron. Dark faith, undead summons, life drain.
- **Necromancer** — Commands undead armies. The dead are tools. Taboo or illegal in most good-aligned cities.
- **Blood Mage** — Uses suffering as fuel. Converts life force — enemy and self — into spell power.