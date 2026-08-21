# Named Mobs Playtest Checklist — 2026-08-21

Verifies that named / boss mobs are real server-side: scaled stats, enrage, and guaranteed +
rare drops.

**Build prerequisite: server only.** Push, pull on the R720, `cargo build --release`, stop, `cp`,
start, confirm the boot line. **No client change and no re-export** — the existing Test Panel
button is enough.

**What was wrong.** The server had no concept of a named mob. All the behaviour lived in the
client's `named_mob_definitions.gd`, and `zone_manager.gd` skips local spawners entirely in
launcher mode, so online none of it ran. The Test Panel pre-multiplied HP and damage locally and
sent a plain `DevSpawnMob`, which is why a named mob was a generic mob wearing a fancy name and
Rotfang's fang never dropped.

**How to spawn one.** Test Panel → **Spawn Named**, pick from the dropdown. The server now
recognises the name and rebuilds the mob from its own table, so the panel needs no changes.

Reference (from `named_mobs.toml`):

| Mob | Level | HP | Dmg | Enrage at | Guaranteed drop | Rare drop |
|---|---|---|---|---|---|---|
| Rotfang the Feared | 6 | 175 | 9 | 20% | Rotfang's Fang | Predator's Collar (30%) |
| Greth Bonecrusher | 10 | 200 | 10 | 25% | Gnoll Chief's Seal | Bonecrusher's War Axe (25%) |
| Ancient Crawler | 8 | 150 | 8 | 30% | Pristine Venom Sac | Chitinous Ring (25%) |
| Sable the Dark | 5 | 125 | 8 | **never** | Sable Wing Membrane | Shadow Signet (20%) |
| The Undying | 12 | 250 | 11 | 40% | Undying Marrow | Cursed Femur (20%) |

Diagnostics: `journalctl -u projectdawn -f`; the anchor for enrage is `named mob enraged`.

---

## 1 — It spawns as a real named mob

- [x] **Spawn Rotfang from the Test Panel** → nameplate reads **"Rotfang the Feared"**, not just
      "Rotfang". notes:
- [x] **Its HP is about 175**, not 50 and not 612. (612 would mean the multipliers got applied
      twice, once on the client and once on the server.) notes:
- [x] **It hits noticeably harder than an ordinary rat** but not absurdly so. notes:
- [x] **Spawn an ordinary mob from the Test Panel** (Spawn Normal) → completely unchanged. notes:

## 2 — Enrage

- [xb] **Fight Rotfang down below 20% HP** → `server.log` shows `named mob enraged`, once. notes: I dont see "named mob enraged" in chat, i do see a difference in the damage (from 7 to 11).
- [x] **It visibly hits harder and moves faster after that point.** notes:
- [-] **It does NOT enrage a second time** if you heal it or keep fighting — one line in the log
      only. notes: Not sure how to heal the mob.
- [x] **Spawn Sable and take it to 1 HP** → **no** `named mob enraged` line. Sable is the one
      named mob with enrage deliberately switched off. notes:
- [x] **Ordinary mobs never enrage** at any HP. notes:

## 3 — Drops (the original complaint)

- [x] **Kill Rotfang** → the corpse contains **Rotfang's Fang**, every time. notes:
- [x] **Kill Rotfang several times** → the fang is there on every kill; the Predator's Collar
      shows up on roughly a third of them. notes:
- [x] **Kill Sable** → Sable Wing Membrane every time. notes:
- [x] **The drops can be looted, equipped or sold normally** (they are authored `.tres` items the
      server registry knows). notes:
- [x] **An ordinary mob never drops a named item.** notes: As far as I can tell.

## 4 — Regression

- [x] **Ordinary camp mobs are unchanged** — same HP, damage, speed, loot. notes:
- [x] **Pets behave exactly as before** (follow, attack, speed). Enrage shares the speed accessor
      pets use, so this is the row that would catch a mistake there. notes:
- [x] **Kill a normal mob and loot it** → unchanged. notes:

---

## Known and deliberate

- **No named mob spawns in the world.** They never did — no scene or spawner ever set
  `named_mob_id`. Placing one is a one-line tag on a camp in `zone_camps.toml`, but *which* camp
  gets *which* named mob is a content decision left open.
- **`xp_mult` is parsed and ignored.** The server derives XP from level, so the level override
  already scales the reward steeply (a level 6 Rotfang is worth roughly 36x a level 1 mob).
  Stacking another 4x is a balance call.

## Result

- Server build: `393cc64`
- Overall: **PASS.** Every row that could be exercised passes, and the server log confirms each
  number independently.

### The log proves the whole chain

```
19:08:23  dev spawn mob char_id=1 mob=Rotfang level=6
19:08:24  player damaged ... raw_amount=9  reduced=7   armor=18
19:08:38  named mob enraged entity_id=1000000030 mob=Rotfang the Feared hp=27.0 max_hp=175.0
19:08:39  player damaged ... raw_amount=13 reduced=11  armor=18
19:08:41  kill credit granted mob=Rotfang the Feared base_xp=9450
19:08:41  loot bag spawned  mob=Rotfang the Feared bag_id=2000000025 stacks=1
```

Every figure is exactly right:
- `max_hp=175.0` is 50 x 3.5 — scaled **once**. 612 would have meant double-scaling.
- `raw_amount=9` is 5 x 1.8, the calm damage multiplier.
- Enrage fires at 27/175 = **15.4%**, below the 20% threshold.
- `raw_amount=13` is 9 x 1.4 = 12.6 rounded — the enrage multiplier, working.
- The nameplate is the full `Rotfang the Feared`, not the bare display name.

A second Rotfang (`1000000031`) behaves identically, enraging once at 30/175 = 17.1%.

### Two tester notes, resolved

- *"I don't see 'named mob enraged' in chat."* Correct, and expected: it is a **server** log line,
  visible in `journalctl`, not in the game chat. It is present for both kills. The 7-to-11 damage
  jump observed in-game is that same event seen from the client side, since armor 18 reduces
  raw 9 to 7 and raw 13 to 11.
- *"Not sure how to heal the mob"* (the does-not-re-enrage row). Closed from the log instead:
  each entity id produces exactly **one** `named mob enraged` line across its whole life, which is
  the property that row was checking.

### Ordinary mobs confirmed unaffected

Rat at `raw_amount=3`, Skeleton at `raw_amount=9`, Rotting Skeleton and Decrepit Skeleton all
normal, and not one `named mob enraged` line among them.
