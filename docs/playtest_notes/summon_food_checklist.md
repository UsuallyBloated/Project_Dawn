# Summon Food and Drink Playtest Checklist — 2026-10-15

Food slice 2, the two conjuring spells (user call 2026-10-15, Monsters and Memories' shape: 1 to 4
items scaling with level). **Summon Food** conjures Conjured Bread (a 48-minute meal) and
**Summon Drink** conjures Conjured Water (a 36-minute drink) into your bags: one at the level
your class learns the spell, one more for every ten levels past it, four at most. 10 mana, a
four-second cast, no cooldown of its own (the global cooldown still applies). The conjured items
have no vendor value, so a merchant will not buy them. **Needs the redeploy (server `4577350`
or later) AND the next export** (the spells and items are on both sides; an old client does not
know the spell or the item).

| Spell | Magician | Shaman | Cleric | Druid |
|---|---|---|---|---|
| Summon Drink | 1 | 2 | 3 | 10 |
| Summon Food | 1 | 9 | 9 | 14 |

| Caster | Count |
|---|---|
| at the level the class learns it | 1 |
| ten levels past it | 2 |
| twenty past | 3 |
| thirty past or more | 4 |

Diagnostics: `server.log` has `SUMMON_ITEM applied` with `qty`; a refusal before the cast is
`CastSpell refused — target pre-flight` with "Your bags are full."; a class below its level is
`CastSpell rejected — class/level not eligible` with `required_level`.

## Setup
- [ ] Server redeployed at `4577350` or later (`build=` on the boot line)
- [ ] The next export (built from this checklist's commit or later)
- [ ] A Magician (any level) and, for §3, a Cleric or Druid below and above its level

## 1 — Conjuring
- [ ] **Magician 1 to 10 casts Summon Food** → a four-second bar, then one Conjured Bread lands in the bags and chat says "You conjure Conjured Bread x1."; 10 mana spent. notes:
- [ ] **Cast Summon Drink** → one Conjured Water the same way. notes:
- [ ] **A Magician 11 or higher (Level Up tool) casts either** → two; at 21 three; at 31 four, stacking onto the earlier ones. notes:
- [ ] **Cast again while the stack is under 20** → the new items join the stack; past 20 a new stack starts. notes:

## 2 — The items
- [ ] **Right-click a Conjured Bread while hungry** → eaten by EQ's rules like a Bread Loaf (refused when full, half when early); the food bar fills by a full meal. notes:
- [ ] **Run out of food with Conjured Bread in the bags** → the server eats it on its own, as it would a loaf. notes:
- [ ] **Offer a Conjured Bread to a merchant** → refused: "The merchant won't take that." (no vendor value). notes:
- [ ] **Conjured items survive a relog** → still in the bags after logging out and in (ours persist; EQ's vanished, flagged in the To-Do). notes:

## 3 — The gates
- [ ] **A Cleric 8 opens the book** → Summon Drink is there (level 3), Summon Food is not (level 9); at 9 both. notes:
- [ ] **A Druid 9** → neither; at 10 Summon Drink; at 14 both. notes:
- [ ] **Fill every bag slot and cast** → refused before the bar with "Your bags are full."; no mana spent. notes:
- [ ] **A Warrior with the spell forced onto the bar (Test Room only, if reachable)** → refused by the class gate; otherwise skip. notes:

## 4 — Regression: nearby behavior unchanged
- [ ] **Bread Loaf and Water Flask** → still bought, sold and eaten as before. notes:
- [ ] **Summon Skeleton (Necromancer)** → still a pet summon, untouched by the new target type. notes:

## Notes / observations
-
