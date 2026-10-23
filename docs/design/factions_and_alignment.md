# Factions and Alignment (design, 2026-10-20)

Research and a v1 scope, no code. The user's calls are in §6; nothing is built until they
land. Written after the EQ parity pass, when the alignment build's open questions turned
into this: **"I think casting spells should have a pretty miniscule effect in the over all.
perhaps we can come up with an equation for that. We need factions: Killing mobs and
running quests are the big two that stand out to me."** Then, on the equation: **"spells:
.001% of their spell cost."**

That matches both reference games. Classic EverQuest had no alignment axis at all; it had
factions, and exactly two things moved them: killing a mob and turning in a quest. Star Wars
Galaxies the same, with kills and missions. Spells moving anything is our own invention
(`docs/concepts/alignment/events.md`), and the user has sized it to nothing.

## 1. What exists today

**Alignment, client-only.** `autoloads/alignment.gd` keeps a score from -2000 to 2000 with
five tiers (Exalted at 1500 and up, Good from 300, Neutral, Bad from -300 down, Evil below
-1500), seeded from `CharacterData.CLASS_STARTING_ALIGNMENT` at `apply_character` (Paladin
500, Cleric 400, Monk and Witch Hunter 100, most classes 0, Blood Mage -500, Shadow Knight and
Necromancer -1600) and moved only by the client's own `modify_alignment`. Two things read it:
`get_effective_class` (a Paladin at Evil is a `Paladin_Fallen`, a Shadow Knight at Exalted a
`Shadow Knight_Redeemed`, the names seven client-only spells and four active-skill variants
carry), and `Spells._get_alignment_effectiveness` (a Paladin casts at 0.7 when Neutral and
0.4 when Bad, a Shadow Knight the mirror). **The server has none of it**: no score, no
column, and the prestige spells and skills are refused for everyone (the active-skills build
of 2026-10-19 says so). The client-authority audit listed alignment as item 6's last part,
and the user's standing rule applies: "Events happening on the client are a no-go." As it
stands a modified client can declare itself Exalted; the only thing that buys today is its
own 1.0 multiplier, since the server applies none, which is why the item could wait.

**Factions: nothing.** No standing of any kind. The six NPCs (`npcs.toml`: Brom, a vendor and
quest giver; Aldric the Guard, a quest giver; Sister Maelis, the soul binder; Thalia Mourne,
the banker; Elara and Hadrik, vendors) serve anyone. The sixteen camp templates and five
named mobs (`zone_camps.toml`, `named_mobs.toml`) carry no faction. The nine quests
(`quests.toml`) pay XP, coin and items, never standing. The To-Do's "Faction system" entry
holds the user's framing of 2026-05-05: players should be able to attack NPCs and suffer the
consequences, and guards should attack on sight. Neither NPCs as targets nor guards as
fighters exist; the only guard, Aldric, is a quest NPC.

## 2. EverQuest's model

Sources, read 2026-10-20: EQEmu's `zone/client.cpp` (`SetFactionLevel`, `SetFactionLevel2`,
`GetModCharacterFactionLevel`, `GetFactionLevel`, `UpdatePersonalFaction`,
`SendFactionMessage`), `common/faction.cpp` (`CalculateFaction`), `common/faction.h`,
`common/ruletypes.h` (the Faction rules), `zone/hate_list.cpp` (`DoFactionHits`) and
`zone/attack.cpp` (`NPC::Death`), all from the master branch; the Project 1999 wiki's Faction,
Starting Faction Standings, Faction Quests and Game Mechanics pages and two forum threads,
through search summaries (the wiki refuses direct fetches).

**Many factions, no axis.** Every NPC has a primary faction and a faction-hit table: a list
of `(faction, value)` entries. Killing the NPC applies each entry's value to the player's
personal standing with that faction: negative on its own faction, positive on its enemies'.
The same table serves quests with the sign flipped (`SetFactionLevel(..., is_quest)` negates
every entry), so helping a faction's NPC is the mirror of killing it; quests also carry
their own explicit hits (the P99 Faction Quests page lists +10s and the like).

**Who gets a kill's hit.** EQEmu's default path (`DoFactionHits`) gives it to **every player
on the mob's hate list**, no group test, no range or level test; a healer who never touched
the mob is not on the list and gets nothing. An optional rule (`EnableMeritBasedFaction`,
off by default) gives it instead the way XP is given, to the killer's whole group or raid.
A charmed mob's death gives no hits at all (`!IsCharmed()`).

**Standing and its range.** Personal standing is capped per faction relative to the
faction's base (`min - base` and `max - base`; the code comments call the personal range
"1200-3000 (4200)"), and the GM flag freezes it. The level an NPC shows is personal standing
plus the faction's base plus class, race and deity modifiers plus any Alliance-line spell or
item bonus; EQEmu's `GetFactionLevel` applies **no charisma term** (P99 lore credits CHA with
small con effects; EQEmu uses CHA only in merchant prices, which also take faction, at most
plus or minus four percent). A feigned, invisible or non-combat-zone player cons Indifferent;
a pet cons Amiable to its owner and Indifferent to everyone else; a mob that would aggro cons
Threatening whatever the number says, unless it already Scowls.

**The nine levels** (EQEmu's rule defaults, `CalculateFaction`): Ally at 1100 and up, Warmly
750, Kindly 500, Amiable 100, Indifferent 0, Apprehensive -100, Dubious -500, Threatening
-750, Scowls below that. The P99 wiki's Faction page draws them differently (Ally 1051 to
2000, Warmly 701 to 1050, Kindly 451 to 700, Amiable 51 to 450, Indifferent -49 to 50,
Apprehensive -50 to -449, Dubious -450 to -699, Threatening -700 to -1049, Scowls -1050 to
-2000) and its own Game Mechanics page disagrees with that; a forum thread calls the table
approximate. The two agree on the shape: a 4,000-point span, nine bands, Indifferent at zero.

**What each level allows** (P99's Faction page): Dubious is the lowest standing that is not
kill-on-sight, and vendors will not deal at it; Apprehensive vendors deal at bad prices;
Indifferent is what most rewarding quests need; Threatening and Scowls are kill-on-sight.
EQEmu's merchant fix cons a Threatening or Scowling merchant as Dubious so the merchant does
not attack. The lines: "Your faction standing with X has gotten better" / "worse", and at a
cap "could not possibly get any better" / "worse" (the `FACTION_BEST` / `FACTION_WORST`
strings; a modern option prints the number instead).

**Starting standings** come from race, class and deity (an Erudite Cleric of Cazic-Thule
starts Threatening where an Ogre Shadow Knight of the same god starts Apprehensive), so a
character's first con with a city is decided at creation. **Hit sizes** on P99 run small: a
guide puts Live's at about ten points a kill and P99's lower; the Iksar guide counts about
450 kills from kill-on-sight to Threatening and 801 to Dubious.

## 3. Star Wars Galaxies' model

Sources: the SWG fandom wiki's Faction page, the SWGEmu manual archive, ZAM's SWG faction
guide and the SWG Legends Factional Presence page (search summaries, 2026-10-20).

Two systems side by side. **The Galactic Civil War**: Rebel and Imperial faction points,
earned by killing the other side's NPCs (the most consistent solo route) and from mission
terminals; a recruiter admits you at 200 points; covert membership allows limited PvP, overt
constant PvP; ranks are bought with points and granted on a weekly cycle; **points are also a
currency**, spent on uniforms, schematics, deeds and followers. **Every other faction**
(Jabba's, the Nightsisters, the Meatlumps, dozens more) keeps a standing from -5000 to
5000 per faction that governs how its NPCs treat you, raised by killing that faction's
enemies and by missions; it is EQ's model with bigger numbers.

What SWG adds that EQ lacks, for later: standing as something to **spend** (the recruiter's
perks) and a faction you **join**, with a rank. Neither is a v1 need; both fit the user's
standing wish for more SWG influence and are noted in §5 as a later slice.

## 4. The design

### 4.1 Factions as data

`data/factions.toml` on the server, mirrored into a client table for names and nothing
else (the client never computes standing):

```toml
[[faction]]
id = "greyveil_town"      # Brom, Sister Maelis, Thalia Mourne, Elara, Hadrik
name = "The Folk of Greyveil"
allies = ["greyveil_watch"]
enemies = ["gnoll_raiders", "bandits", "restless_dead"]

[[faction]]
id = "greyveil_watch"     # Aldric the Guard; the standing that decides whether guards attack
name = "The Greyveil Watch"
allies = ["greyveil_town"]
enemies = ["gnoll_raiders", "bandits", "restless_dead"]

[[faction]]
id = "gnoll_raiders"      # Gnoll Raider, Gnoll Brute, Greth
name = "The Gnoll Raiders"
enemies = ["greyveil_town", "greyveil_watch"]

[[faction]]
id = "bandits"            # Bandit Scout (the road_toll quest's quarry)
name = "The Road Bandits"
enemies = ["greyveil_town", "greyveil_watch"]

[[faction]]
id = "restless_dead"      # every skeleton, zombie, the Bone Colossus, the Ancient Wraith, The Undying
name = "The Restless Dead"
enemies = ["greyveil_town", "greyveil_watch"]

[[faction]]
id = "wildlife"           # wolves, boars, bats, rats, spiders, Rotfang, Sable, the Ancient Crawler
name = "Wildlife"
# no links: killing an animal moves nothing, as in EQ
```

Every mob template in `zone_camps.toml` gains `faction = "..."`; a named mob inherits its
base template's. Every NPC in `npcs.toml` gains `faction = "..."`. A faction may carry
starting modifiers by race and class (`[faction.start] race = { "Dark Elf" = -300 }`),
EQ's creation-time standing; v1 ships the table empty (§6, decision 7).

### 4.2 Hits

A kill applies `-hit` to the mob's faction and `+hit / 2` to each faction that lists it as
an enemy; allies of the mob's faction are untouched (EQ's tables could name any value for
any faction; v1 derives the values from the links, one knob per mob instead of a table per
mob). `hit` defaults to `4 + level` (a Plague Rat 6, a Gnoll Brute 14, in EQ's tens) and a
named mob triples it; a template may override `faction_hit`. A charmed mob's death gives
nothing (EQ's rule, and ours already pays no XP or loot for one). The standing clamps to
plus or minus 2000 per faction (EQ's personal range). Pets credit their owner, as XP does.

A quest carries `faction_hits = { greyveil_town = 25, greyveil_watch = 10 }` in
`quests.toml`, explicit per quest (EQ's sign-flipped kill table is clever but opaque; a
quest's standing is content and should read as content). Default when absent: +20 to the
turn-in NPC's faction.

**Who gets a kill's hits** was decision 2, and the user chose **EQ's rule: every player on
the mob's hate list** (`Entity::aggro`, which the server already keeps), no group or range
test ("EQ's hate list is the way", 2026-10-23). A healer who never touched the mob gets
nothing, as on P99; a puller who tagged it and ran gets the hit from across the zone, as on
P99. The alternative, the XP eligibility rule, is recorded here only as the road not taken.

### 4.3 Standing and the con

Standing shown = personal standing + the faction's start modifier for the character's race
and class. The nine levels at EQEmu's rule defaults (decision 3): Ally 1100, Warmly 750,
Kindly 500, Amiable 100, Indifferent 0, Apprehensive -100, Dubious -500, Threatening -750,
Scowls below. No charisma term (EQEmu has none).

A new `Consider { target }` intent (the EQ `/con`, right-click's "consider" later) answers
with one chat line built server-side: the level con the client already colours (the target's
level against yours) and the faction con in EQ's words ("Brom looks upon you amiably",
"Greth scowls at you, ready to attack"). It requires the target in reach (the inspect rule),
so standing is never an oracle for an NPC the player cannot see. The NPC dialogue header
shows the same line when a conversation opens.

**Consequences in v1** (decision 4): a vendor at Dubious or below refuses to trade ("Elara
will not deal with you."), a quest giver at Apprehensive or below ignores you ("Brom has
nothing to say to you."), the banker refuses like a vendor, and the soul binder always serves
(bind is the safety net; refusing it builds a death loop). Guards attacking on sight needs
guards that fight, which do not exist; the con line says it ("ready to attack") and the
attack itself is slice 2. Merchant prices by standing (EQ's plus or minus four percent) are
a knob left at zero.

### 4.4 Alignment, server-owned

One score per character, a float from -2000 to 2000, persisted (`characters.alignment_score
REAL`, NULL until seeded), moved by three things:

- **Kills.** Each mob template carries an alignment tier (`alignment = "undead"`), and the
  delta is `events.md`'s table: killing an Exalted -80, a Good -30, a Neutral 0, a Bad +10,
  an Evil +25, a named Evil +50, an Evil undead +20, an innocent -60. Proposed tiers for the
  world: the dead and The Undying `undead` (+20, the named +50), gnolls and bandits `bad`
  (+10), wildlife `neutral` (0); the town's NPCs `good` for the day they can be attacked.
  PvP kills by the victim's tier, when PvP flagging is designed.
- **Quests.** `alignment_delta` per quest in `quests.toml`, `events.md`'s ranges (+20 to +100
  for a good faction's quest). Proposed: the town's nine quests +20 to +40 each.
- **Spells**, the user's equation: **a cast moves alignment by 0.001% of the spell's mana
  cost**, toward the school's side (holy and healing up; shadow, necromantic, blood, fear and
  charm down; `events.md`'s school list). Smite (12 mana) is 0.00012 a cast: eight thousand
  casts move one point, eight million cross the axis. Present and never decisive, which is
  the point; it needs the float column to accumulate at all.

All three go through the momentum rule as written: a delta that moves the score away from
zero is scaled by `1 - |score| / 2000`, so the extremes resist. No decay (the design's rule).

**Seeding** (decision 5): a character with no stored score gets its class's starting value
on first load (`CLASS_STARTING_ALIGNMENT` moves to the server, lockstep-tested against the
client's copy), written once; a new character is seeded at creation.

**What reads it.** The server's `effective_class` (a Paladin at Evil is `Paladin_Fallen`, a
Shadow Knight at Exalted `Shadow Knight_Redeemed`), fed to the cast gate's class check and the
active-skill class gate, so the seven prestige spells and four skill variants become real
for the characters who earn them (and refused for everyone else, as today). The off-side
penalty (a Paladin at Neutral casts at 0.7, at Bad 0.4; the Shadow Knight mirrored) moves to
`spell_power`, the one multiplier left there (decision 6). The client learns the score and
tier through a private `AlignmentUpdate { score }` on entering the world and on every change,
stops computing its own, and keeps its sheet and the "You feel your soul darken" style lines.

### 4.5 Wire and persistence

Migration `0016_factions_and_alignment.sql`: `character_factions (char_id, faction_id,
standing REAL, PRIMARY KEY (char_id, faction_id))` and `ALTER TABLE characters ADD COLUMN
alignment_score REAL` (NULL = unseeded). Forward-only like every other, so an older binary
will not boot on the migrated `world.db`; it ships with the next migration-bearing deploy.
Standing and alignment write with the resource checkpoint and the reap through
`save_stores_atomic`.

Wire, appended under the unshipped PD_W0028 if built before the bump, or under the next one:
`ClientWorldMsg::Consider { target: EntityId }`; `ServerWorldMsg::FactionUpdate { faction_id,
standing, level }` (private, on a change and on entering the world for every faction the
character has standing with), `ServerWorldMsg::AlignmentUpdate { score }` (private). The
refusal lines ride the existing System chat line. No client decides anything.

### 4.6 Exploit ledger (the test list)

1. **Farming a camp for standing.** Finite: the clamp at 2000 (about 160 Gnoll Raider kills
   from Indifferent to Ally with the town, EQ's shape) and the hit sizes. There is no reward
   past Ally in v1 but the con line, so there is nothing to farm past it.
2. **A quest's hits pay once** (quests are once per character already).
3. **A client cannot set its standing or its alignment**: both are the server's, the client's
   `modify_alignment` and its own effectiveness multiplier are retired, and the prestige class
   gates key on the server's `effective_class`.
4. **Kill credit** for hits is the mob's hate list (decision 2, EQ's rule): a player who never
   touched the mob gets nothing, however close or grouped; a player who did gets the hit
   wherever they stand, which is EQ's own puller rule and no gain over a kill.
5. **Pets** credit the owner; **a charmed mob** gives no hits when it dies and credits the
   charmer for its kills, as XP does.
6. **No standing oracle:** `Consider` works only on a target in reach; an absent, far or
   never-existed id gets one generic line (the inspect rule).
7. **Spells at a hundred-thousandth of their mana** cannot be farmed into anything: a bot
   casting a thousand Smites an hour moves alignment 0.12 an hour.
8. **The seed writes once**: a character cannot re-seed by relogging (NULL becomes the class
   start exactly once, then the column holds the number).
9. **Vendor refusal** at Dubious is only a wall once NPCs can be attacked (slice 2); until
   then no player can reach Dubious with the town, since nothing in the world lowers it.
10. **No GM freeze** (decision 9): a GM's standing moves like anyone's, so a GM playtest
    shows the real lines; the GM's faction sliders are a dev command, GM-only, audited, and
    move only the GM's own standing, so no player can be handed a standing by it and no
    plain account can reach it.

### 4.7 Slices

**Slice 1 BUILT 2026-10-23** (server `5efd45d` + `30c270a`, client `22ebde7`;
`docs/playtest_notes/factions_checklist.md`; the To-Do's "Faction system" entry has what
exists and the calls made in the build). Not built from the list below: the faction on the
character sheet and the dialogue header.

- **Slice 1 (server and client, one bump):** `factions.toml` with the race-and-class start
  table read from day one (empty in v1), the mob and NPC fields, hits on kills (to the hate
  list) and quests, standing persisted, the con line and `Consider`, vendor and quest-giver
  refusals; alignment server-owned with kills, quests and the spell equation, the seed, the
  class gates and the off-side penalty, `AlignmentUpdate`; the client's sheet and dialogue
  header, `/con`; **the GM's faction panel** in the Test Panel (user, 2026-10-23: "GMs will
  need tools to test the factions. Probably a tool with sliders that allows the GM to adjust
  only their own faction with any of the listed factions"): one slider per faction, setting
  the GM's own standing to an absolute value through a new `DevSetFaction { faction_id,
  standing }` intent, GM-only and audited like every dev command, the server clamping to the
  faction's range, and no GM freeze on ordinary hits (decision 9). EQEmu's own GM tools for
  comparison: `#faction review` (a targeted player's standing with every faction), `#faction
  reset` (back to base), `#faction view` (an NPC's primary faction) and `#factionassociation
  <faction> <amount>` (a delta on the GM's own or a targeted player's standing); EQ Live's
  Guides wore marked robes (the Sage Robe of Tranquility and its kin, +100 HP, 40 AC), but
  the powers came from the account flag and commands, not the clothes, so a "Breastplate of
  Indifference" stays a cosmetic for later (it would need the no-drop flag and a GM-only item
  gate). Tests: unit (the hit derivation, the clamp, the nine levels, the momentum rule, the
  spell equation, the seed-once rule, the start table) and integration (a gnoll kill moves
  two factions by the right amounts for everyone on its hate list and nobody else, a quest
  turn-in pays its hits, a vendor refuses a Dubious character, a Paladin driven to Evil casts
  a Fallen spell and a plain Paladin cannot, `Consider` on a far target gets the generic
  line, a plain account's `DevSetFaction` does nothing and a GM's moves only their own
  standing and writes one audit row).
- **Slice 2 (content and server):** guards as combat NPCs with the Watch's faction (attack on
  sight at Threatening and below), attackable town NPCs with the consequences the user asked
  for (a kill hits the town and the Watch; the evil-race reputation farm then has a cost),
  starting standings by race.
- **Slice 3 (later, SWG's half):** a faction you join with a rank, standing as a currency at
  a recruiter.

## 5. Scheduling

Not a friends-build item: the schedule has it on the after-the-door strip, and slice 1 is
about two to three days with a migration and a bump. If the user wants it before Nov 8 it
competes with the alignment-free items already queued; the recommendation is after.

## 6. Decisions for the user (ALL NINE DECIDED 2026-10-23)

1. **The first faction set** (§4.1's six) and the derived hit rule (`-hit` to the mob's
   faction, `+hit / 2` to its enemies, `hit = 4 + level`, named x3). Recommendation: yes.
   **DECIDED: yes** ("Your recommendations looked great for 1 and 8. Good to go.").
2. **Who gets a kill's hits.** Recommendation was the XP eligibility rule. **DECIDED: EQ's
   hate list** ("EQ's hate list is the way"); §4.2 and the ledger follow it.
3. **The level thresholds.** Recommendation: EQEmu's rule defaults (1100 / 750 / 500 / 100 /
   0 / -100 / -500 / -750), since P99's own two pages disagree. **DECIDED: EQEmu's** ("I think
   we can trust EQEmu"). What P99's pages say, for the record: the Faction page's table runs
   Ally 1051 to 2000, Warmly 701 to 1050, Kindly 451 to 700, Amiable 51 to 450, Indifferent
   -49 to 50, Apprehensive -50 to -449, Dubious -450 to -699, Threatening -700 to -1049,
   Scowls -1050 to -2000; its Game Mechanics page puts Apprehensive at -101 to -500 and
   Scowls below -801; both are player estimates from counting kills, and a forum thread on
   the table calls it "not so correct". The edges differ from EQEmu's by 50 to 100 points
   either way; nothing in play hinges on them.
4. **v1 consequences.** Recommendation: vendors and the banker refuse at Dubious, quest givers
   at Apprehensive, the soul binder always serves, guards' attack waits for slice 2, prices
   untouched. **DECIDED: as recommended** ("This sounds good").
5. **Alignment seeding.** Recommendation: the class start on first load, written once.
   **DECIDED: yes** ("this is great").
6. **The off-side penalty** (0.7 at Neutral, 0.4 at Bad for a Paladin; the Shadow Knight
   mirrored). Recommendation: keep, moved to the server. **DECIDED: keep.**
7. **Starting standings by race.** Recommendation: none in v1 (everyone Indifferent with the
   town); the table is there for the content pass. **DECIDED: everyone Indifferent, and the
   system built now** ("Everyone indifferent is important right now. But can we build the
   system for this?"): the per-faction race-and-class start table is read from day one and
   ships empty; filling it is a content edit, no code.
8. **The content values**: mob alignment tiers (undead +20, gnolls and bandits +10, wildlife
   0, The Undying +50) and the nine quests' `alignment_delta` (+20 to +40) and `faction_hits`
   (+25 town, +10 Watch, more for the named hunts). Recommendation: as proposed; the
   playtest tunes them. **DECIDED: as proposed.**
9. **The GM freeze.** Recommendation: no freeze (a GM playtest should show the real lines).
   **DECIDED: no freeze, and a GM tool** ("GMs will need tools to test the factions. Probably
   a tool with sliders that allows the GM to adjust only their own faction with any of the
   listed factions"): the Test Panel's faction sliders in slice 1 (§4.7), the server-side
   `DevSetFaction` behind them, GM-only and audited. The user also asked whether EQ gave its
   GMs their abilities through gear ("a breastplate of indifference or some shit"): EQ Live's
   Guides wore marked robes, but the powers were the account flag and commands (EQEmu's
   `#faction` and `#factionassociation` are the faction ones); a GM cosmetic can follow later.

## 7. Sources

- EQEmu Server, master branch, read 2026-10-20: `zone/client.cpp` (`SetFactionLevel`,
  `SetFactionLevel2`, `GetCharacterFactionLevel`, `GetModCharacterFactionLevel`,
  `GetFactionLevel`, `UpdatePersonalFaction`, `SendFactionMessage`, `GetReverseFactionCon`),
  `common/faction.cpp` (`CalculateFaction`, `FactionValueToString`), `common/faction.h`,
  `common/ruletypes.h` (the eight `Faction` rules, `NPC:EnableMeritBasedFaction`,
  `Merchant:PriceBonusPct` and `PricePenaltyPct`), `zone/hate_list.cpp` (`DoFactionHits`),
  `zone/attack.cpp` (`NPC::Death`'s faction block).
- Project 1999 wiki (search summaries): Faction, Starting Faction Standings, Faction Quests,
  Game Mechanics, Consider, An Iksar's Guide To Love and Friendship Through Murder, Glumf's
  Spectacular Faction Guide; forum threads "A Question About Faction" and "Faction levels on
  wiki table".
- Star Wars Galaxies (search summaries): the SWG fandom wiki's Faction and Galactic Empire
  pages, the SWGEmu manual archive, ZAM's "SWG Guide Factions", SWG Legends' Factional
  Presence page, SWG Infinity's Galactic Civil War page.
- Ours: `docs/concepts/alignment/events.md` and `alignment.md`, `autoloads/alignment.gd`,
  `data/character_data.gd` (`CLASS_STARTING_ALIGNMENT`), `autoloads/spells.gd`
  (`_get_alignment_effectiveness`), `npcs.toml`, `quests.toml`, `zone_camps.toml`,
  `named_mobs.toml`, the To-Do's "Faction system" and "Client-decided outcomes" entries.
