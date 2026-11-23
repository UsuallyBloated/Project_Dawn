# What the Monsters and Memories roadmap has that our To-Do does not

*2026-11-20. Read from the public M&M board (https://trello.com/b/wjN4owwf/monsters-and-memories-roadmap,
250 cards, last active 2026-08-27) and set against the CLAUDE.md To-Do and the code. A feature is
listed only when no To-Do entry covers it; where one partly does, the entry is named.*

**Sorted 2026-11-22: every open row is add** (user: "everything they've done would probably be the way"); the To-Do carries them as one entry per area, under "From the Monsters and Memories roadmap".

**How it was sorted.** Mark each row **add** (a To-Do entry gets written), **later** (recorded
here, nothing written) or **no**. Rows marked "already ours" or "already in To-Do" need no mark.

## Accounts, support and safety

| M&M feature | What we have | Your call |
|---|---|---|
| Bug submission (an in-game `/bug` form) | Nothing in game; testers report by message and checklist notes | add |
| Petition system (`/petition` to a GM) | Nothing | add |
| Player reporting (`/report` a player) | Nothing | add |
| Chat reporting | Nothing | add |
| Blocking messages and players (`/ignore`) | Nothing | add |
| Chat filtering (a word filter) | Nothing | add |
| Name filtering at character creation | No word filter on names (check what the existing name rules cover) | add |
| Account deletion by the player | Operator bins only; delete/purge still open in "Account admin tooling" | add |
| GDPR-style data handling (export, erase) | Nothing; matters only for a public host | add |
| A landing page and installer | `README_FOR_TESTERS.md` and a zip | add |
| Customer-service tool (ZenDesk and similar) | Nothing | add |
| GM client | The Test Panel and GM commands (`is_gm`), audited | already partly ours |

## Character creation

| M&M feature | What we have | Your call |
|---|---|---|
| Deity selection | Four deities in the lore (`project_lore_foundations`), not chosen at creation | add |
| Starting city selection | One zone, one town | add |
| Attribute allocation (EQ's free points) | Nothing: stats come from race, class and level; the creation screen (`scripts/login.gd`) allocates no points | add |
| Traits and innate abilities | Race abilities designed (`race_stats.md`, Stone Skin); only Troll regen built | partly in "Dwarf racial ability" |
| Resist types | No resist model on the server (named in "Proc follow-ups") | add |
| Vision types | `VisionSystem` (night vision tint) exists | already ours |

## The world

| M&M feature | What we have | Your call |
|---|---|---|
| Moon cycle and variable night sky | Server-driven day and night only | add |
| Seasonal changes (weather, textures, spawns, forage) | Nothing | add |
| Event-based world changes and a scheduler | Nothing | add |
| Indoor and outdoor areas (rules for spells, weather) | Nothing; one outdoor zone | add |
| Environmental hazards (lava, currents, strong wind) | Water and swimming are in To-Do ("Weather system; Water & swimming") | add |
| Ambient sound and zone music | "Sound system" (the friends build ships silent) | already in To-Do |
| Fishing and forage tables | Fishing and foraging exist as tradeskill concepts in `data/tradeskill_definitions.gd`; nothing online | partly ours |
| NPC non-combat animations | Placeholder capsules, no animation | add |

## Getting around

| M&M feature | What we have | Your call |
|---|---|---|
| `/stuck` (get unstuck) | Nothing; matters more now that scenery is solid (obstacle collision) | add |
| Climbing | Nothing; faces past 60 degrees refuse the step | add |
| Dragging a corpse (EQ's `/corpse` drag) | Nothing | add |
| Boats | Nothing | add |
| Text interaction with objects ("MUD objects") | Nothing | add |
| Doors and switches | "Doors & locks" in To-Do | already in To-Do |

## Items and inventory

| M&M feature | What we have | Your call |
|---|---|---|
| Light sources (held torches and lanterns, fuel, slots) | A Candlemaking tradeskill concept names torches; no light item or darkness rule | add |
| Click effects on items | Procs exist; nothing activates by click | add |
| Reagents (spell components) | "Consumables system" names ritual components | partly in To-Do |
| Treasure maps | Nothing | add |
| Artifacts and relics (rare one-off items) | Nothing | add |
| Storage placed in the world (a chest you own) | Nothing | add |
| Consignment containers (sell through a container) | "Auction / bazaar" in the social-layer entry | partly in To-Do |

## NPCs and quests

| M&M feature | What we have | Your call |
|---|---|---|
| Trainer NPCs (skills, languages) | Nothing; "Language system wiring" says it needs trainers | add |
| Merchant price scaling by faction | Merchants refuse at Dubious; prices do not move | add |
| A faction status window | `/factions` text only (flagged in "Faction system") | partly in To-Do |
| Relationship system (an NPC remembers you) | Nothing | add |
| Dynamic NPC names (unknown until you ask "Who are you?") | Nothing | add |
| Quest flagging (progression gates) | Quests count kills only | partly in "Quest and loot content plumbing" |
| Spell scrolls and scribing | Spells are learned by level; no scroll item | add |

## Combat, groups and PvP

| M&M feature | What we have | Your call |
|---|---|---|
| NPC combat abilities (mobs that cast and use specials) | Mobs melee only; named mobs enrage | add |
| Expanded NPC behaviours (fleeing, calling for help) | Wolf packs join each other's fights | partly ours |
| Combat animations (players and NPCs) | None (art) | add |
| Group experience bonus | 20% on the group's pool (`GROUP_XP_BONUS`, server `world/groups.rs`) | already ours |
| Duels | Named in the social-layer entry | already in To-Do |
| PvP arenas, PvP nametag colours, a PvP server ruleset, guild wars, PvP-flagged NPCs | "PvP flagging" is one open entry with no design | add |

## Mounts, homes and rest

| M&M feature | What we have | Your call |
|---|---|---|
| Pack animals | Nothing | add |
| Pulled carts | Nothing | add |
| Vessels | Nothing | add |
| Player housing | "Player-owned towns + guild taxes" in the social-layer entry, as an idea | partly in To-Do |
| Guild housing | Same entry | partly in To-Do |
| Buildable campfires with a rested buff | Nothing | add |
| Inn room and housing rested buff | Nothing | add |
| Tavern and inn chat (a benefit for being in one) | Nothing | add |
| Non-combat pets | Nothing | add |
| Transformations | An offline-era `Transformations` system was removed 2026-11-01 | add |

## Bigger ideas

| M&M feature | What we have | Your call |
|---|---|---|
| Monster cities (a city for the evil races, with its own factions and services) | Nothing; one town | add |
| Play as an NPC ("Project N") | Nothing | add |
| Storyteller system (trusted players running events, spawning NPCs) | GM tools only | add |
| Metrics: suspicious-pattern flagging and currency outliers | The item ledger and its daily balance check; a nightly dupe query is named in "Public-host hardening" | partly ours |
