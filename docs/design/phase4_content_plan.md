# Phase 4 Content Plan: an Evening's Worth of Content

**Drafted 2026-09-10, revised same day** after the user's call: the current camp
layout is disposable ("We are not at all connected to this layout"), so section 4
proposes a **replacement spawn table** designed around the quests and the level
curve, rather than patches to the old rings.
Status: DRAFT, awaiting the user's calls on the decision list in section 7.

The bar, from `docs/schedule.md`: **two friends can play for three hours without
running out of things to do.** This doc inventories what actually exists (verified
against server data and code, not memory), does the XP math for that bar, names the
gap, and prices the work to close it.

---

## 1. What exists today, verified

### 1.1 Camps (server `zone_camps.toml`: 9 camps, 27 spawn points)

Recorded here as the baseline being replaced; the proposed new table is section 4.1.

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

Level coverage: 1, 2, 3, 5, 6, 9, 10, 14, 16, with holes at 4, 7, and 8, no camp
matching three of the four quests, and four of the nine mobs matching no loot table.

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
guaranteed + rare loot **already authored**. Nothing spawns any of them. Placement
is one `named_id` tag on a camp mob in `zone_camps.toml` (the file documents this
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

Loot tables are matched by mob-name substring. Seven authored tables (Wolf, Boar,
Snake, Bear, Spider, Bat, Zombie) are unused by the old layout, while its four
high-end mobs match no table at all. The replacement layout in 4.1 chooses mob
names so a table backs every camp below level 14.

---

## 2. The XP math, from code

Constants from `progression.rs` and `char_data`:

- Even-con kill: `mob_level² × 262.5` XP (ZEM 75 × 3.5 scale). Kill XP derives
  from the mob's **level**; the `xp` field in `zone_camps.toml` is legacy and
  unused for awards.
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
bar. The old layout undermined it twice: a **7-to-8 wall** (nothing between the L6
camp and the L9 crypt, so the session slowed to green-mob grinding exactly when it
should peak) and a milder level 4 sag. The replacement layout closes both by
construction with camps at 4 and 7.

Quest XP is seasoning, not the meal: the entire current quest book pays about
55,000 XP, and 48,800 of that is Rotfang's. That is fine. Quests exist to direct
players at camps and hand out gear; camps carry the leveling.

---

## 3. Broken content found during this survey

These are world-data mismatches, invisible to `cargo test`. Items 1 to 3 are
solved by the replacement layout (4.1) rather than patched.

1. **No wolves exist.** `wolf_threat` targets "Wolf"; no camp mob's name contains
   it. The first quest Aldric offers is uncompletable in the live world. (The wolf
   loot table, wolf pelts, and wolf meat all exist, waiting.)
2. **Rotfang is never spawned**, so `rotfang_hunt` (the 48,800 XP finale) is also
   uncompletable.
3. **`gnoll_raiders` is a level 3 quest whose only matching mob is the level 10
   Gnoll Brute.** Technically completable, practically a death sentence at the
   level Brom offers it.
4. `rat_infestation` works (Plague Rat matches), but Brom's dialogue sends you to
   a cellar and the rats live in a distant outdoor camp. The new layout puts the
   rat camp behind Brom's shop where his dialogue points.
5. **Elara's dialogue tree is unreachable.** She is placed as a plain vendor node,
   so right-click opens the shop directly; her written dialogue, including the
   Greywood foreshadowing that seeds future content, never plays. She is also
   absent from `npcs.toml` and her shop works only because she stands inside the
   15 m radius of Brom's vendor entry. Not layout-related; small client fix,
   tracked in section 4.4.

---

## 4. The plan

Effort codes: **S** = data-only, minutes; **M** = an hour or two; **L** = a real
build.

### 4.1 Replace the camp layout (S/M, one server deploy)

The whole table below is `zone_camps.toml` data. The client renders any mob name
through the shared `remote_enemy.tscn`, so nothing here needs a client change, a
protocol bump, or a re-export. Mob names are chosen so an existing loot table backs
every camp below 14, and each named mob gets its own single-spawn den entry with a
long respawn. New mobs' hp/dmg/speed get interpolated from the existing per-level
curve when the toml is written.

| Ring (dist) | Camp | Mob | Lvl | Spawns | Loot table | Notes |
|---|---|---|---|---|---|---|
| 1 (18-25) | Bonepile | Decrepit Skeleton | 1 | 4 | Skeleton | kept from old layout |
| 1 | Wolf Run (S of the east road) | Grey Wolf | 1 | 4 | Wolf | **wolf_threat**, per Aldric's directions |
| 1 | Rat Warrens (behind Brom's) | Plague Rat | 2 | 4 | Rat | **rat_infestation**, matches the cellar dialogue |
| 2 (35-50) | Shallow Graves (NE) | Rotting Skeleton | 3 | 3 | Skeleton | kept |
| 2 | Gnoll Raider Camp (E, rocky flats) | Gnoll Raider | 3 | 4 | Gnoll | **gnoll_raiders**, per Brom's directions |
| 2 | Boar Thicket (SW) | Wild Boar | 4 | 3 | Boar | fills the level 4 sag; hides for the leather line |
| 2 | Bat Hollow (N, Greywood edge) | Cave Bat | 4 | 3 | Bat | Elara's foreshadowing gets a place |
| 2 | + Sable's roost | (bat template) | named 5 | 1 | | `named_id = "sable"`, 300 s respawn |
| 3 (60-80) | Bandit Outpost (NW) | Bandit Scout | 5 | 3 | Bandit | kept; the coin camp |
| 3 | Rotfang's Den (S, old rocks) | Dire Wolf | 5 | 2 | Wolf | per Aldric's den directions |
| 3 | + Rotfang | (wolf template) | named 6 | 1 | | `named_id = "rotfang"`, 300 s — **rotfang_hunt** |
| 3 | Festering Mound (SE) | Plagued Zombie | 6 | 3 | Zombie | renamed from Ghoul so the table matches |
| 4 (100-125) | Spider Copse | Giant Spider | 7 | 3 | Spider | **the 7-to-8 wall fix** |
| 4 | + the Crawler's burrow | (spider template) | named 8 | 1 | | `named_id = "ancient_crawler"`, 300 s |
| 4 | The Broken Crypt (N) | Skeleton Champion | 9 | 3 | Skeleton | renamed from Undead Champion so the table matches |
| 5 (140-160) | Gnoll War Camp (S) | Gnoll Brute | 10 | 3 | Gnoll | kept, moved out |
| 5 | + Greth's tent | (brute template) | named 10 | 1 | | `named_id = "greth"`, 600 s |
| 5 | The Sunken Barrow | Barrow Zombie | 12 | 3 | Zombie | stretch camp |
| 5 | + The Undying | (zombie template) | named 12 | 1 | | `named_id = "the_undying"`, 600 s |
| 6 (170-185) | Ossuary (W) | Bone Colossus | 14 | 2 | none (coin) | kept, aspirational |
| 6 | Wraith Gate (E) | Ancient Wraith | 16 | 2 | none (coin) | kept, aspirational |

16 ordinary camps (49 spawns) + 5 named singles = 54 spawn points, double the old
27; spawn points are cheap server-side. Level ladder: 1, 1, 2, 3, 3, 4, 4, 5, 5,
6, 7, 9, 10, 12, 14, 16 with nameds at 5, 6, 8, 10, 12 — continuous even-con
coverage through 7, and the level 7 spiders plus the Crawler hold 8 until the L9
crypt turns yellow.

Cost note: `zones.rs` pins "9 camps / 27 spawn positions" in a test; the layout
change updates that test in the same commit.

### 4.2 Second quest tier (M: ~30-45 min per quest, three data files, no code)

Proposal, five quests hooked to existing NPCs and the camps above, forming two
chains plus one standalone:

| Quest | Giver | Lvl | Tier | Targets | Reward idea |
|---|---|---|---|---|---|
| Restless Bones | Aldric | 2 | standard | 8 Skeleton | small XP + coin-priced item |
| Road Toll | Brom | 5 | standard | 6 Bandit | a copper chain piece |
| The Silk Harvest | Brom | 7 | hard | 10 Spider | leather piece + Crawler leads in dialogue |
| Champion's Crypt | Aldric | 9 | hard | 6 Skeleton Champion | iron chain piece |
| The Undying | Aldric | 12 | named | The Undying | a unique (finale, gray after) |

Turn-in XP at those tiers: ~5,600 / ~18,300 / ~63,500 / ~84,500 / ~140,600. The two
hard quests are each worth roughly half a level at-level, which makes walking back
to town worth it, and the finale gives the duo a reason to push past the three-hour
bar. Names, dialogue, and rewards are mine to draft, yours to veto.

Authoring checklist per quest (the lockstep rule): `quests.toml` (with
`turn_in_npc` set so the proximity gate applies), `quest_definitions.gd`,
`dialogue_definitions.gd`.

### 4.3 Itemization beats (M)

The three-hour session currently awards 3 gear items and unspendable coin. Two
cheap moves and one deferred:

- **Place a Blacksmith vendor in town** (stock list already authored: copper and
  iron weapons + full iron chain set). Coin from bandits, gnolls, and undead gains
  a purpose immediately. Cost: one `world.tscn` vendor node + one `npcs.toml` row.
  Caveat to accept: per-vendor stocking is client-side only (the server sells
  anything with a `vendor_price` to anyone in range of any vendor); fine at
  friends scale, already tracked server-side as deferred.
- **Named drops** (4.1) supply the chase items and the quest rewards (4.2) fill
  slots along the way.
- **Deferred**: gear in loot tables (`loot.rs` is code, not data) and tables for
  the Colossus/Wraith line. Coin-only from the two far camps is acceptable once
  coin has a sink.

### 4.4 Small repairs riding along

- Elara becomes a DialogueNPC (her tree already has an `open_vendor` response), and
  gets an `npcs.toml` row. Client change, rides the next export.
- Brom's rat dialogue already matches the new rat camp placement; no edit needed.

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

Arrive in Valdis; Brom's rats out back and Aldric's wolves down the road (level
1-3, both completable); Restless Bones at the graves (3-4); gnoll raiders east
(4-5), boars and bats filling the gaps; bandits plus the Road Toll and Sable (5-6);
Rotfang's den for the finale of the starter book (6); the Spider Copse and Silk
Harvest with the Crawler window (6-8); and if they are still going, Champion's
Crypt at 9 with Greth and The Undying on the horizon as the reason to come back
tomorrow. Two named windows, two rare weapons, a blacksmith to spend bandit coin
at, and no dead air until 8+.

---

## 6. Sequencing and cost

| Step | What | Effort | Deploy |
|---|---|---|---|
| 1 | 4.1 replacement `zone_camps.toml` + the pinned-count test | S/M | server only |
| 2 | 4.3 Blacksmith vendor + 4.4 Elara fix | S/M | client re-export + npcs.toml |
| 3 | 4.2 five quests | M each | server + client together (lockstep files) |
| 4 | Playtest: calibrate the section 2 time model | | checklist |

Step 1 is one sitting and one deploy, and on its own it already makes every
existing quest completable and every named mob real. Step 3 is the bulk of the
authoring and can land quest by quest.

---

## 7. Decisions for you (phone-answerable)

1. **The replacement layout in 4.1**: approve as drafted, or mark up rows (moves,
   renames, counts). The two renames worth noticing: Plagued Ghoul becomes Plagued
   Zombie and Undead Champion becomes Skeleton Champion, purely so loot tables
   match. On approval I can write the toml and the test the same day; it goes live
   at your next R720 deploy.
2. **Quest count and shape in 4.2**: five as proposed? Any veto on the chains
   going through Aldric/Brom only, or do you want a third quest giver (a hunter
   type for the Sable/Crawler side) placed as new content?
3. **Blacksmith vendor in town**: yes/no?
4. **Elara upgraded to a dialogue NPC**: yes/no?
5. **Procedural dungeon deferred past Oct 5**: confirm?
