# Citizen
*Non-Combat / Economic — Any Alignment — Mobile merchant, field money-exchanger, and employer of hired arms*

> **Status:** Design sketch. The **field money-exchange** role (copper→platinum conversion at adventurer camps — the player-run counterpart to the Banker's NPC exchange; there is no separate "moneychanger" NPC, see `world/currency.md`) is committed; the rest of the kit is still being scoped. Not yet on the to-do list — author additional sections only when a system here is being implemented.

## Overview

The Citizen is the project's non-combat playable class — a mobile player-merchant who serves the same economic function NPC vendors do, but in the field, where adventurers actually are. They buy loot at camps, exchange heavy copper for portable platinum, and travel between settlements as walking auction houses. Power comes from margins, contracts, and reputation, not weapons.

Citizens cannot tank, heal, or out-DPS any combat class. They survive by employing hired arms: a permanent low-tier apprentice bodyguard at low levels, and contract mercenaries hired with platinum at higher levels. The class trades direct combat capability for unique economic and social tools no other class can access.

## Combat Profile
- **Armor:** Light cloth / leather only — merchant clothing, never plate
- **Weapons:** Basic 1H melee (daggers, short swords, clubs) for self-defense only
- **Primary Resource:** Stamina (defensive skills); no mana, no spells
- **Pet:** Hired bodyguard — see [The Bodyguard System](#the-bodyguard-system) below

## Primary Stat: Charisma

CHA is the Citizen's defining stat, the way STR defines Warrior or INT defines Wizard. See [project-wide CHA design](../../../CLAUDE.md) — CHA matters for every class, but Citizens itemize around it harder than anyone.

CHA scales:
- Vendor buy/sell margins (buy lower, sell higher)
- Disguise duration and detection resistance
- Hired-merc roster quality, contract length, and hire cost
- Faction-rep gain rate (boosted further on Citizen)
- NPC dialogue unlocks (more on Citizen than other classes)

## Skills

| Skill | Type | Effect | Notes |
|---|---|---|---|
| Mercantile | Passive | Improves buy/sell margins; gates access to better hires | Citizen-exclusive |
| Currency Exchange | Active | Convert copper ↔ silver ↔ gold ↔ platinum for self or another player; small fee retained | **Committed.** The core gameplay loop hook. |
| Appraise | Active | Reveal an item's NPC-vendor value before purchase | Reduces risk on field buys |
| Disguise | Active | Temporarily impersonate a non-hostile faction; broken by combat or suspicious behavior | KoS-area traversal tool, the Citizen's analogue to Rogue Stealth |
| Hire Contract | Active | Engage a temporary merc from the local hireable roster | Cost and roster scale with CHA; see [The Bodyguard System](#the-bodyguard-system) |
| Self-Defense | Passive | Modest 1H melee skill cap | Citizens can fight back; they can't win |

## The Bodyguard System

The Citizen's "pet" is a humanoid bodyguard — economic and contractual, distinct from the [Beast Master](beast_master.md)'s nature-bonded warder. Reuses the engine's existing pet plumbing (`PetManager`, `WarderAI`) with a different model and behavior set.

**Two tiers:**

| Tier | Acquired | Cost | Duration | Power |
|---|---|---|---|---|
| Apprentice | Level 1, automatic | Free | Permanent | Weak; scales slowly with Citizen level |
| Hireable Merc | Higher levels, at hire-points in towns | Platinum, CHA-scaled | Fixed contract (hours of play / per-zone / per-job) | Scales with the price tier paid |

The apprentice solves the early-game travel problem on its own: low-tier outdoor mobs lose to a Citizen + apprentice pair. Hireable mercs handle contested zones. Dungeons still require the Citizen to travel with an adventuring party — no merc is a substitute for a group.

**Design intent:** Merc hiring is **Citizen-exclusive**. Other classes cannot pay platinum to skip a tank or a healer. This preserves the project's group-play pressure (see [no solo mode](../../../CLAUDE.md)) while giving Citizens an identity no other class can replicate.

## Race Availability

*TBD when the class is committed.* Early thinking: CHA-friendly races (Human, Half-Elf, Elf, Fae) feel most natural, but the class is fundamentally about temperament and trade — no race is *blocked* on combat grounds. Final restrictions will mirror the existing patterns in `data/character_data.gd` (`LOCKED_COMBOS`).

## Playstyle

A Citizen logs in, gathers field information (where parties are camping, what's dropping), and tours the adventurer outposts. At each camp they buy loot at a discount, run a copper-exchange table for any party member sitting on heavy coin, and move on. Back in town, they sell at full NPC value, restock supplies (potions, food, ammo) to resell on the next circuit, and renew merc contracts if they're expiring.

Disguise is for the high-margin runs: walk into a faction-hostile capital, sell to a vendor whose pricing isn't poisoned by your reputation, walk out. Detection breaks the disguise and the Citizen has to flee — combat capability is intentionally inadequate to fight through.

The Citizen's social position is unusual: every adventurer is potentially a customer, every dungeon party is potentially an escort employer, every town is potentially a market. The class rewards players who like reading the economy and managing relationships.

## Travel Survival Tiers

- **Safe overworld zones:** solo with permanent apprentice
- **Contested zones:** hire a tier-appropriate merc (CHA determines availability)
- **Dungeons:** travel with a player adventuring party in exchange for a cut of trades — the social-coupling tier

## Lore Notes

*To be written.* The Citizen tradition predates the adventuring class system — they are the surviving form of the pre-Dominion-War merchant guilds, the people who kept goods moving even when the roads were not safe. They organize informally; there is no Citizen "academy." Reputation is earned by being where adventurers need you, not by training.

## Open Design Questions

- Race CHA distribution (depends on [Charisma stat decision](../../../CLAUDE.md))
- Disguise detection rules (time? proximity to faction NPCs? combat? specific actions?)
- Merc roster scope — fixed NPCs per town, or generated archetypes?
- Contract enforcement — what happens if a Citizen logs out mid-contract?
- Auction / bazaar interaction — when player-run shops exist, does Citizen get bonuses there too?
- Whether CHA also helps charm/turn/fear effects on other classes (cross-class CHA design)

## Related

- [Currency system](../world/currency.md) — four-tier coin + per-coin weight; the system the Citizen's exchange skill operates on
- [Crafting philosophy](../../crafting/crafting_philosophy.md) — Citizen plugs into the SWG-style economy
- [Beast Master](beast_master.md) — comparison: nature-bonded warder vs. contractual bodyguard
- [Rogue](rogue.md) — comparison: stealth traversal vs. disguise traversal
- [Bard](bard.md) — comparison: another social/support class, but combat-capable
