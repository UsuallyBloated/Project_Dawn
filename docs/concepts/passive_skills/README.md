# docs/concepts/passive_skills — Directory Index

Passive skills train through use rather than practice windows or trainers.
Weapon and armor skills are implemented; casting and utility skills are design targets not yet in code.

---

## Contents

| File | Category | Status | Summary |
|---|---|---|---|
| [weapons_passive.md](weapons_passive.md) | Combat | Implemented | Eight weapon skills (1H/2H Slashing, 1H/2H Blunt, Piercing, Hand to Hand, Defense, Dodge); miss chance and damage multiplier scale with skill; class caps at level 60 |
| [armor_passive.md](armor_passive.md) | Combat | Implemented | Four armor skills (Plate, Chain, Leather, Cloth); armor effectiveness multiplier scales with skill; wrong armor type carries a hard 0.5× penalty |
| [casting_passive.md](casting_passive.md) | Magic | Design target | Spell discipline skills (Evocation, Conjuration, Abjuration, etc.); higher discipline skill reduces resist chance and unlocks secondary cast benefits; feeds the existing damage school / enemy resist system |
| [utility_passive.md](utility_passive.md) | General | Design target | Non-combat skills: Meditate (mana regen while sitting), Language (passive comprehension gain), Swim, Safe Fall; each trains through relevant action |

---

## Implementation Notes

- `WeaponSkills.try_advance()` and `ArmorSkills.try_advance_worn()` fire on every relevant combat event
- Cap formula (both weapon and armor): `class_cap_at_60 * level / 60` — caps grow linearly with level
- Damage schools (Fire, Ice, Lightning, etc.) are already tagged on spells in `data/spell_definitions.gd`; the casting discipline layer in `casting_passive.md` sits on top of those tags

---

*To add a passive skill category: add a row to the table above before committing.*
