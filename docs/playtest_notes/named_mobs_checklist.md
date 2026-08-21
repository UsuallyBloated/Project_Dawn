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

- [ ] **Spawn Rotfang from the Test Panel** → nameplate reads **"Rotfang the Feared"**, not just
      "Rotfang". notes:
- [ ] **Its HP is about 175**, not 50 and not 612. (612 would mean the multipliers got applied
      twice, once on the client and once on the server.) notes:
- [ ] **It hits noticeably harder than an ordinary rat** but not absurdly so. notes:
- [ ] **Spawn an ordinary mob from the Test Panel** (Spawn Normal) → completely unchanged. notes:

## 2 — Enrage

- [ ] **Fight Rotfang down below 20% HP** → `server.log` shows `named mob enraged`, once. notes:
- [ ] **It visibly hits harder and moves faster after that point.** notes:
- [ ] **It does NOT enrage a second time** if you heal it or keep fighting — one line in the log
      only. notes:
- [ ] **Spawn Sable and take it to 1 HP** → **no** `named mob enraged` line. Sable is the one
      named mob with enrage deliberately switched off. notes:
- [ ] **Ordinary mobs never enrage** at any HP. notes:

## 3 — Drops (the original complaint)

- [ ] **Kill Rotfang** → the corpse contains **Rotfang's Fang**, every time. notes:
- [ ] **Kill Rotfang several times** → the fang is there on every kill; the Predator's Collar
      shows up on roughly a third of them. notes:
- [ ] **Kill Sable** → Sable Wing Membrane every time. notes:
- [ ] **The drops can be looted, equipped or sold normally** (they are authored `.tres` items the
      server registry knows). notes:
- [ ] **An ordinary mob never drops a named item.** notes:

## 4 — Regression

- [ ] **Ordinary camp mobs are unchanged** — same HP, damage, speed, loot. notes:
- [ ] **Pets behave exactly as before** (follow, attack, speed). Enrage shares the speed accessor
      pets use, so this is the row that would catch a mistake there. notes:
- [ ] **Kill a normal mob and loot it** → unchanged. notes:

---

## Known and deliberate

- **No named mob spawns in the world.** They never did — no scene or spawner ever set
  `named_mob_id`. Placing one is a one-line tag on a camp in `zone_camps.toml`, but *which* camp
  gets *which* named mob is a content decision left open.
- **`xp_mult` is parsed and ignored.** The server derives XP from level, so the level override
  already scales the reward steeply (a level 6 Rotfang is worth roughly 36x a level 1 mob).
  Stacking another 4x is a balance call.

## Result

- Server build (`build=` on the boot line):
- Overall:
