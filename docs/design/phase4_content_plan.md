# Phase 4 Content Plan: an Evening's Worth of Content

**Drafted 2026-09-10** (phase 4 window: Sep 10 to Oct 1, target 2026-10-05).
Status: DRAFT, awaiting the user's calls on the decision list in section 7.

The bar, from `docs/schedule.md`: **two friends can play for three hours without
running out of things to do.** This doc inventories what actually exists (verified
against server data and code, not memory), does the XP math for that bar, names the
gap, and prices the work to close it.

---

## 1. What exists today, verified

### 1.1 Camps (server `zone_camps.toml`: 9 camps, 27 spawn points)

| Ring | Camp | Mob | Lvl | Spawns | Respawn |
|---|---|---|---|---|---|
| 1 | Bonepile | Decrepit Skeleton | 1 | 4 | 35 s |
| 2 SW | Rat Warrens | Plague Rat | 2 | 4 | 35 s |
| 2 NE | Shallow Graves | Rotting Skeleton | 3 | 3 | 35 s |
| 3 NW | Bandit Outpost | Bandit Scout | 5 | 3 | 35 s |
| 3 SE | Festering Mound | Plagued Ghoul | 6 | 3 | 35 s |
| 4 N | The Broken Crypt | Undead Champion | 9 | 3 | 50 s |
| 4 S | Gnoll War Camp | Gnoll Brute | 10 | 3 | 50 s |
| 5 W | Ossuary | Bone Colossus | 14 | 2 | 90 s |
| 5 E | Wraith Gate | Ancient Wraith | 16 | 2 | 90 s |

Level coverage: 1, 2, 3, 5, 6, 9, 10, 14, 16. **The gaps that matter are 4, 7, and 8**
(see the math in section 2).

### 1.2 Quests (4 real + 1 dev)

XP at turn-in is tier% of the cubic band at `level_req` (fixed, so quests gray out
for high levels, classic EQ).

| Quest | Giver | Lvl | Tier | Turn-in XP | Item reward |
|---|---|---|---|---|---|
| Rat Infestation (kill 8 Rat) | Brom | 1 | trivial | 150 | none |
| The Wolf Threat (kill 5 Wolf) | Aldric | 1 | standard | 300 | Tarnished Silver Ring (AGI +1) |
| Drive Back the Raiders (kill 8 Gnoll) | Brom | 3 | standard | 5,700 | Scout's Leather Boots (AGI +2, AC 6) |
| Hunt the Beast (kill Rotfang) | Aldric | 5 | named | 48,800 | Hunter's Medal (STR +2, CON +2) |
| test_q1 (dev, Test Panel) | n/a | 1 | standard | 300 | none |

Kill objectives use bidirectional substring matching (`quests.rs::kill_matches`:
"Wolf" matches "Grey Wolf"). Each quest lives in three lockstep files: server
`quests.toml`, client `quest_definitions.gd`, client `dialogue_definitions.gd`.

### 1.3 Named mobs (5 authored, 0 placed)

All five exist in `named_mobs.toml` with stat multipliers, enrage behaviour, and
guaranteed + rare loot **already authored**. Nothing spawns any of them. Placement is
one `named_id` tag on a camp mob in `zone_camps.toml` (the file documents this
itself), so every row below is minutes of work, not a build.

| Named | Lvl | Guaranteed drop | Rare drop |
|---|---|---|---|
| Sable the Dark | 5 | Sable Wing Membrane | Shadow Signet (20%) |
| Rotfang the Feared | 6 | Rotfang's Fang | Predator's Collar (30%) |
| Ancient Crawler | 8 | Pristine Venom Sac | Chitinous Ring (25%) |
| Greth Bonecrusher | 10 | Gnoll Chief's Seal | Bonecrusher's War Axe (25%) |
| The Undying | 12 | Undying Marrow | Cursed Femur (20%) |

The two rare weapons are the best in the game (Cursed Femur 14-26 dmg, the War Axe
12-24), so chase items exist. They are just unreachable.

### 1.4 NPCs placed in the world (from `world.tscn` + server `npcs.toml`)

Aldric the Guard (quests), Brom (vendor + quests), Sister Maelis (soul binder),
Thalia Mourne (banker), and Elara (General Merchant, vendor node only).

### 1.5 Itemization

172 items, of which 42 are gear. The gear ladder is coherent: worn/frayed starter
pieces, then cloth, leather, copper chain, iron chain, plus a handful of uniques.
But almost none of it is obtainable:

- The two placed vendors sell food, tools, and crafting mats. **No placed vendor
  sells a single weapon or piece of armor.** The Blacksmith / Leatherworker / Tailor
  stock lists are fully authored in `vendor_definitions.gd`; no NPC of those types
  is placed.
- **No loot table drops gear.** All 11 server tables (`loot.rs`) drop mats and meat.
- So the only gear a player can acquire is the three quest rewards, plus whatever
  they rolled at character creation.

Loot-table coverage has a second hole: tables are matched by mob-name substring, and
Plagued Ghoul, Undead Champion, Bone Colossus, and Ancient Wraith **match no table**,
so the entire leveling path from 6 up drops coin only (and there is nothing to spend
coin on but food). Meanwhile seven authored tables (Wolf, Boar, Snake, Bear, Spider,
Bat, Zombie) have no camp that uses them.

---

## 2. The XP math, from code

Constants from `progression.rs` and `char_data`:

- Even-con kill: `mob_level² × 262.5` XP (ZEM 75 × 3.5 scale).
- Band to go from L to L+1: `(L³ − (L−1)³) × 1000`.
- A group splits the kill pool per member (playtest-verified: `pool=315
  per_member=157`), so a duo needs about twice the kill *events*, offset by killing
  roughly twice as fast and far more safely.

| Level | Band | Even-con kill | Solo kills | Duo kill events |
|---|---|---|---|---|
| 1 to 2 | 1,000 | 262 | 4 | 8 |
| 2 to 3 | 7,000 | 1,050 | 7 | 14 |
| 3 to 4 | 19,000 | 2,362 | 8 | 16 |
| 4 to 5 | 37,000 | 4,200 | 9 | 18 |
| 5 to 6 | 61,000 | 6,562 | 10 | 19 |
| 6 to 7 | 91,000 | 9,450 | 10 | 20 |
| 7 to 8 | 127,000 | 12,862 | 10 | 20 |
| 8 to 9 | 169,000 | 16,800 | 11 | 21 |

Time model, stated as assumptions to calibrate in the first phase 4 playtest: a duo
pull cycle (approach, fight, loot, recover) averaging 45 to 60 seconds at levels 1
to 3 and 60 to 120 seconds at 5+. That puts a fresh duo at **roughly level 6 to 8
after three hours**, most of it in the second half. That is the right shape for the
bar. Two problems, though:

1. **The 7-to-8 wall.** After the level 6 ghouls, the next camp is level 9. A level
   7 duo grinding green level 6 mobs needs ~27 kill events per level and slows to a
   crawl exactly when the session should be peaking. One level 7-8 camp fixes the
   single worst pacing hole in the zone.
2. **Level 4 sag.** Between the level 3 graves and level 5 bandits there is nothing
   even-con. Softer than the 7-8 wall (level 3 mobs stay yellow-ish through 4), so
   fix only if cheap.

Quest XP is seasoning, not the meal: the entire quest book pays about 55,000 XP,
and 48,800 of that is Rotfang's. That is fine. Quests exist to direct players at
camps and hand out gear; camps carry the leveling.

---

## 3. Broken content found during this survey

These are world-data mismatches, invisible to `cargo test`, and they gate everything
else. The first quest a new player receives cannot be completed.

1. **No wolves exist.** `wolf_threat` targets "Wolf"; no camp mob's name contains
   it. The first quest Aldric offers is uncompletable in the live world. (The wolf
   loot table, wolf pelts, and wolf meat all exist, waiting.)
2. **Rotfang is never spawned**, so `rotfang_hunt` (the 48,800 XP finale) is also
   uncompletable.
3. **`gnoll_raiders` is a level 3 quest whose only matching mob is the level 10
   Gnoll Brute** in Ring 4. Technically completable, practically a death sentence at
   the level Brom offers it.
4. `rat_infestation` works (Plague Rat matches), but Brom's dialogue sends you to a
   cellar and the rats live in an outdoor camp to the southwest. Flavor mismatch,
   harmless, fix whenever the dialogue file is next open.
5. **Elara's dialogue tree is unreachable.** She is placed as a plain vendor node,
   so right-click opens the shop directly; her written dialogue, including the
   Greywood foreshadowing that seeds future content, never plays. She is also
   absent from `npcs.toml` and her shop works only because she stands inside the
   15 m radius of Brom's vendor entry.

---

## 4. The plan

Effort codes: **S** = data-only, minutes; **M** = an hour or two; **L** = a real
build. Items 4.1 and 4.2 are pure `zone_camps.toml` edits: the client renders any
mob name through the shared `remote_enemy.tscn`, so new mobs and camps need no
client change, no protocol bump, and no re-export. One server deploy carries all of
it.

### 4.1 Repair the quest loop (S) — do first

- **Grey Wolf camp**, level 1-2, 4 spawns, south of the eastern road (matching
  Aldric's "the pack hunts south of the road"). Loot table already exists.
- **Gnoll Raider camp**, level 3, 3 spawns, east (matching Brom's "rocky flats
  about a mile east"). "Gnoll" substring keeps quest credit; the existing gnoll
  loot table applies; also gives level 3-4 duos a second even-con option (softens
  the level 4 sag).
- **Rotfang's den**, single spawn south, `named_id = "rotfang"` on a wolf-based
  template, long respawn (~300 s, matching the client's old named respawn intent).

### 4.2 Place the remaining named mobs (S)

- **Ancient Crawler (L8)** anchors a **new spider camp, level 7-8, 3 spawns**,
  placed between Ring 3 and Ring 4. This is the 7-to-8 wall fix and the spider
  loot table (silk, venom sacs) finally enters play.
- **Greth Bonecrusher (L10)**: `named_id` on one Gnoll War Camp spawn. The war
  camp gets a boss and the War Axe becomes real.
- **Sable the Dark (L5)**: a small bat camp (level 4-5, 2-3 spawns) somewhere dark,
  north toward the Greywood edge fits Elara's foreshadowing. Bat loot table exists.
- **The Undying (L12)**: single spawn near the Broken Crypt as a stretch boss
  between Rings 4 and 5, long respawn. Source of the Cursed Femur.

### 4.3 Second quest tier (M: ~30-45 min per quest, three data files, no code)

Proposal, five quests hooked to existing NPCs and the camps above, forming two
chains plus one standalone:

| Quest | Giver | Lvl | Tier | Targets | Reward idea |
|---|---|---|---|---|---|
| Restless Bones | Aldric | 2 | standard | 8 Skeleton | small XP + coin-priced item |
| Road Toll | Brom | 5 | standard | 6 Bandit | a copper chain piece |
| The Silk Harvest | Brom | 7 | hard | 10 Spider | leather piece + Crawler leads in dialogue |
| Champion's Crypt | Aldric | 9 | hard | 6 Undead Champion | iron chain piece |
| The Undying | Aldric | 12 | named | The Undying | a unique (finale, gray after) |

Turn-in XP at those tiers: ~5,600 / ~18,300 / ~63,500 / ~84,500 / ~140,600. The two
hard quests are each worth roughly half a level at-level, which makes walking back
to town worth it, and the finale gives the duo a reason to push past the three-hour
bar. Names, dialogue, and rewards are mine to draft, yours to veto.

Authoring checklist per quest (the lockstep rule): `quests.toml` (with
`turn_in_npc` set so the proximity gate applies), `quest_definitions.gd`,
`dialogue_definitions.gd`.

### 4.4 Itemization beats (M)

The three-hour session currently awards 3 gear items and unspendable coin. Two
cheap moves and one deferred:

- **Place a Blacksmith vendor in town** (stock list already authored: copper and
  iron weapons + full iron chain set). Coin from bandits, gnolls, and undead gains
  a purpose immediately. Cost: one `world.tscn` vendor node + one `npcs.toml` row.
  Caveat to accept: per-vendor stocking is client-side only (the server sells
  anything with a `vendor_price` to anyone in range of any vendor); fine at
  friends scale, already tracked server-side as deferred.
- **Named drops** (4.2) supply the chase items and the quest rewards (4.3) fill
  slots along the way.
- **Deferred**: gear in loot tables (`loot.rs` is code, not data) and loot tables
  for the ghoul/champion/colossus/wraith line. Coin-only from those camps is
  acceptable once coin has a sink.

### 4.5 Explicitly out of scope for Oct 5

- **The procedural dungeon** (`F:\Projects\ProceduralDungeon`): the generator is
  real, but the server simulates a single zone (`conn.zone` unpopulated,
  `npcs.toml` carries no zone field yet), so wiring it in means multi-zone
  infrastructure, a protocol change, and new deploy surface. Recommend: revisit
  after the friends build ships.
- Fetch/delivery/dialogue quest objective types (server counts kills only).
- Per-vendor server-side stocking; faction; the client-only spell backlog.

---

## 5. Three hours, replayed with this plan in place

Arrive in Valdis; Brom's rats and Aldric's wolves (level 1-3, both completable);
skeleton quest at the Bonepile and graves (3-4); gnoll raiders east (4-5); bandits
plus the Road Toll and maybe Sable (5-6); Rotfang's den for the finale of the
starter book (6); ghouls and the new spider camp with the Silk Harvest (6-8); and
if they are still going, the Broken Crypt quest at 9 with Greth and The Undying
visible on the horizon as the reason to come back tomorrow. Two named windows, two
rare weapons, a blacksmith to spend bandit coin at, and no dead air until 8+.

---

## 6. Sequencing and cost

| Step | What | Effort | Deploy |
|---|---|---|---|
| 1 | 4.1 quest-loop repairs | S | server only |
| 2 | 4.2 named placements + spider/bat camps | S | rides step 1 |
| 3 | 4.4 Blacksmith vendor | S/M | client re-export + npcs.toml |
| 4 | 4.3 five quests | M each | server + client together (lockstep files) |
| 5 | Playtest: calibrate the section 2 time model | | checklist |

Steps 1 and 2 are one sitting and one deploy. Step 4 is the bulk of the authoring
and can land quest by quest.

---

## 7. Decisions for you (phone-answerable)

1. **Build 4.1 now?** The three repairs are toml edits; I can have them committed
   and ready for your next R720 deploy today.
2. **The spider camp at 7-8 with Ancient Crawler**: yes/no?
3. **Named homes in 4.2**: agree with the four placements, or move any?
4. **Quest count and shape in 4.3**: five as proposed? Any veto on the chains
   going through Aldric/Brom only, or do you want a third quest giver (a hunter
   type for the Sable/Crawler side) placed as new content?
5. **Blacksmith vendor in town**: yes/no?
6. **Procedural dungeon deferred past Oct 5**: confirm?
