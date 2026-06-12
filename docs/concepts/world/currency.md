# Currency — Design Reference
*The four-tier coin system. Copper, Silver, Gold, Platinum.*

---

## Overview

Project Dawn uses a four-tier coin system inspired by the EverQuest tradition but on a 100:1 economy: Copper, Silver, Gold, Platinum. Each tier is worth **one hundred** of the tier below it. Coins are **physical objects with weight**, held as four independent stacks. They do not auto-convert.

The design intent: wealth is heavy. A player who has hoarded ten thousand copper coins is encumbered by them. The only ways to make that wealth portable are (a) spend it, (b) convert it at a moneychanger, or (c) deposit it at a bank. Each of those choices has friction, and that friction is the point — it creates errands, geography, and risk.

---

## Tiers and Ratios

| Tier | Symbol | Value in Copper | Notes |
|---|---|---|---|
| Copper | c | 1 | Daily-life unit. Bread, tavern beds, common ammunition, low-tier reagents. |
| Silver | s | 100c | Mid-game adventuring unit. Skill-up trainers, common gear, mid-tier reagents. |
| Gold | g | 10,000c | Significant purchase unit. Quality equipment, rare reagents, dockage fees. |
| Platinum | p | 1,000,000c | Wealth unit. Expensive gear, real estate, long-distance shipping contracts, faction services. |

A price written as **"2g 5s 30c"** means two gold, five silver, and thirty copper — equivalent to 20,530 copper if fully reduced. The four numbers are independent and the player is **not required** to be at the reduced form. They can hold 20,530 copper coins and zero of every other tier if they want to (and they will feel it in their carrying weight).

**Design note on the 100:1 ratio.** Classic EQ used 10:1; we deliberately go wider. Reasons: (a) it gives finer-grained pricing at the bottom (a candle, a bed, and dinner can all sit at distinct copper values), (b) it gives platinum real heft (1 plat = 1,000,000 copper, not 1,000), and (c) it makes the coin-encumbrance lever vastly stronger. The tradeoff is harder mental math on mixed-tier prices, which is acceptable because vendors and trade windows will always show the breakdown explicitly.

---

## Storage Model

Coins are stored as **four separate counts** on the player (and on every container that can hold coin: corpses, banks, etc.). The naive single-int model (store total copper, format on display) is rejected because it cannot represent the *choice* to hold raw copper versus converted silver. That choice has weight consequences, and the weight consequences are the gameplay.

This means:

- `PlayerStats.platinum`, `PlayerStats.gold`, `PlayerStats.silver`, `PlayerStats.copper` — all `int`, all independent.
- The net protocol's `CoinsUpdate` carries four ints, not one.
- `add_coins(p, g, s, c)` / `spend_coins(p, g, s, c)` — additions are straightforward; spending may require "making change" from higher tiers if the lower tier is short. Whether the game auto-makes-change on spend is an open question (see below).
- Save/load persists four fields.
- A `format_currency(p, g, s, c)` helper exists only for display, and it does **not** rewrite the underlying numbers. If the player has `(0, 0, 0, 350)`, the display shows "350c", not "3s 50c". The 350 raw copper coins are heavy; that's the player's choice and the system respects it.

---

## Weight and Encumbrance

Each coin has weight. Holding wealth in low tiers is heavy; holding wealth in high tiers is light. Exact weight values are TBD and should be tuned during playtesting, but the design target:

- A starting character can comfortably carry "starter purse" amounts (low hundreds of copper) without encumbrance.
- A mid-level character who has never converted their coin is noticeably slowed by it.
- A wealthy character who carries everything in copper cannot move at normal speed at all.
- A wealthy character whose wealth is fully converted to platinum can carry it indefinitely without thinking about it.

Suggested starting weights (per coin, in whatever unit the encumbrance system uses):

| Tier | Weight |
|---|---|
| Copper | 0.02 |
| Silver | 0.02 |
| Gold | 0.02 |
| Platinum | 0.02 |

All coins weigh the same per coin. This is the key mechanic: 1,000,000 copper coins (worth 1 platinum) weigh **one million times** as much as the single platinum coin of equal value. The player pays for hoarding low tiers in the literal sense. Even at the more modest scale of "1 gold's worth held as copper," that's 10,000 coins instead of 1 — a 10,000× weight multiplier for the choice not to convert.

(Alternate model worth considering: copper is heavier than platinum *per coin* because copper coins are physically larger. This is more realistic but the math is the same either way — keep it simple at one weight-per-coin until playtest says otherwise.)

---

## Moneychangers and Banks

Two distinct services with different counterparties.

### Moneychanging — primarily a Citizen-class player service

Moneychanging is one of the [Citizen class's](../classes/citizen.md) core revenue streams. A Citizen camped at a dungeon entrance can convert the night's loot for an adventuring party in the field, saving them a vend run back to town. The exchange ratio is fixed at **100:1** in both directions (100 copper ↔ 1 silver, etc.); the Citizen's profit is the fee they negotiate on top.

NPC moneychangers also exist in major town hubs as a **baseline floor**. They charge a published, regulated rate. Their job is to ensure exchange is always available even when no Citizens are online, and to anchor the market price that Citizens compete against. Players will use NPCs by default; they'll seek out Citizens for better rates or — more often — for the convenience of "I don't have to walk back to town."

Suggested fee bands (Citizens and NPCs both):

- **Up-conversion fee** (small → large): 2–5% of the converted amount.
- **Down-conversion fee** (large → small): 0–1%, because the converter profits from re-circulating low-tier coin.
- Hard floor and ceiling on Citizen-set rates (see *Rate caps* below) so the class can't be undercut to zero and can't gouge.

Fee rates also vary by location and faction standing for NPCs. The Dockmasters' Compact (Harrowmere) has standardized NPC rates published weekly. The Grey Market does conversions with rates that depend on standing. Wilderness NPC moneychangers (where they exist) charge whatever they can get.

#### Four mechanical concerns for the Citizen-as-moneychanger system

These need to be designed into the system from day one or it doesn't work:

1. **Capital float.** A Citizen converting 100c → 1s needs to actually have 1 silver on hand. New Citizens won't be able to serve every request; they'll specialize (small conversions only, only one direction) until they build up a working float across all four tiers. This is a feature — it gives the class economic progression on an axis other than combat — but the UX needs to communicate "this Citizen doesn't have the silver to fulfill your request" gracefully.
2. **Atomic trade window.** Exchanges must go through the trade UI: both parties confirm, server-validated atomic swap of (player coin in) ↔ (Citizen coin out + fee retained by Citizen). Never "hand me the coin and I'll give it back" — that's a scam vector and the class becomes uninhabitable.
3. **Discovery.** Players need to find Citizens to do business. Some combination of: a visible "Citizen — Moneychanger" tag on the nameplate, a `/who Citizen` filter, notice-board listings in town hubs ("Mara at Greyveil East Gate, 3% up / 0.5% down"), or a Citizen-specific LFG-style "open for business" flag. At minimum, one of these must exist before the class ships.
4. **Rate caps.** Hard floor and ceiling on Citizen-set fees. The floor prevents a race-to-the-bottom that breaks the class (Citizens charging 0% drive out everyone who needs to make a living at this). The ceiling prevents gouging desperate players in remote zones who have no alternative. Baseline suggestion: floor 0.5%, ceiling 10%. Tune in playtest.

### Banks — NPC, town-anchored

Banks accept deposits and hold coin (and items, eventually) between visits. Coin in the bank has zero weight on the player. Banks are **NPC-only and town-anchored** by design:

- Persistent storage needs a reliable counterparty. Players go offline, quit, or get bored — none of that can be allowed to lose a depositor's wealth.
- Banks have effectively unlimited capacity, which would be unworkable to hold on a player.
- Banks are infrastructure, not a player service. The geography of "where can I deposit" is part of the world map.

Banks are tier-agnostic — a deposit of 10,000 copper stays as 10,000 copper until the player asks for consolidation (which the bank can also do, at NPC moneychanger rates).

Bank fees TBD:
- A flat deposit/withdrawal fee per session, or
- A storage fee scaled by total wealth and time, or
- Nothing for low-balance customers and a fee above a threshold

Tie-break with playtest feel. EQ banks were free; the friction was the travel to reach them.

---

## World Hooks

The following NPCs/locations are already canonized as currency infrastructure:

- **Harrowmere — Seventh Dock (Thalia Mourne).** Officially the Dockmasters' Compact seat for "financial services and currency exchange." Runs the city's banking functions. Rates updated weekly. See [faction_dockmasters_compact.md](faction_dockmasters_compact.md).
- **Greyveil — Trade Quarter.** Already named as the "auction house design target" and "best player-to-player trading infrastructure." Currency exchange is implicit infrastructure here. See [greyveil.md](greyveil.md).
- **Grey Market.** Operates in the contested Underdark sections. Conversions happen in cash with rates that depend on standing. See [faction_grey_market.md](faction_grey_market.md).

Open: the Dwarven Holds almost certainly have a major mint/bank (Dwarves and coin go together canonically). Cogsworth probably has clockwork-themed banking infrastructure. Vel'Sharath has something but it would not be called a "bank." These can be drafted later as the cities are developed.

---

## Vendor Pricing Convention

Rough targets, to keep prices intuitive across the game:

| Item Class | Typical Price Range |
|---|---|
| Candle, single arrow, scrap reagent, sip of ale | 1–10 copper |
| Tavern bed, single meal, common ammunition bundle, low-tier reagent | 10–99 copper |
| Common adventuring gear (basic sword, leather armor, torch bundle) | 1–10 silver |
| Mid-tier gear, skill manuals, rare reagents, dockage for the night | 10–99 silver |
| Quality gear (proper armor sets, named-quality weapons, faction services) | 1–10 gold |
| Excellent gear, expensive faction services, mid-grade real estate | 10–99 gold |
| Top-tier rare gear, ships, guild halls, lifetime contracts | 1+ platinum |

These are not hard rules — a wandering merchant in a dangerous zone can absolutely overcharge for a torch. But the **shape** of the economy should follow the table: copper for survival, silver for adventuring, gold for serious investment, platinum for the truly significant.

Existing item `.tres` files have `vendor_price` as a single int. When the currency system is implemented, those values will be reinterpreted (probably as copper for low-tier items, silver for mid-tier, etc.) and re-tiered during playtesting. Expect prices to churn many times before they settle.

---

## Loot Drops

Mob drops should map roughly to mob tier:

| Mob Type | Typical Drop |
|---|---|
| Wildlife (wolves, rats, crawlers) | 0 — no coin drops from non-humanoid wildlife |
| Bandits / humanoid low-tier | 5–50 copper |
| Mid-tier humanoid (gnolls, kobold raiders) | 50–300 copper, occasional silver |
| Named mobs (Rotfang, Greth Bonecrusher, etc.) | 1–20 silver, occasional gold |
| Bosses and end-game named | 1–10 gold, rare platinum |

This keeps the player's coin tier roughly aligned with their power level. A level 5 character with platinum is probably running an exploit. A level 50 character with bags of raw copper is *encumbered*, which is the design.

---

## Open Questions

These need decisions during implementation:

1. **Auto-make-change on spend?** ~~Open~~ **Decided (2026-05-21): auto-make-change.** Spending breaks coins automatically — low tiers first, breaking a single higher coin only when the lower stacks fall short, so a deliberate copper hoard survives unrelated purchases. A held wallet is never wholesale re-reduced; payouts arrive reduced on top of existing stacks. (EQ-style refusal was considered and rejected as pure annoyance — the encumbrance choice lives in *holding* coin, not in vendor friction.) Implementation: `Coins::spend` in `crates/protocol/src/world.rs` (server) and `Currency.spend` in `autoloads/currency.gd` (client) — keep the two in sync.
2. **Bank fees — flat, scaled, or none?** Tie-break with playtest feel.
3. **Death and coin loss.** If the player dies, do coins stay on the corpse (EQ classic), drop on the ground, or stay on the player? This intersects with the **Corpse Run** to-do item and should be resolved alongside it.
4. **Single-currency or per-faction coin?** Considered and rejected: too much friction for a small project. One coin system worldwide. Lore can describe regional mintage as flavor without mechanizing it.
5. **Per-coin weight values.** Start at 0.02 each and tune.
6. **PvP coin theft.** If PvP is added, can a player loot coin from another player's corpse? Defer until PvP design is settled.

---

## Implementation Notes

**Status (2026-05-21): the plumbing is built.** Four-tier wallet end to end (server `Coins` + wire PD_W0013 + DB migration `0004` + client `PlayerStats`/`Currency`/vendor UI), plus encumbrance v1 (`Encumbrance` autoload: coin/item/equipment weight vs `10 + STR` capacity, movement + stamina-regen penalties). See `docs/concepts/architecture/systems_overview.md` for what exists. Not yet built: moneychanger NPCs, banks, the Citizen trade-window mode, item-weight content pass, weight readout UI. The list below was the pre-implementation file map, kept for orientation:

- [autoloads/player_stats.gd](../../../autoloads/player_stats.gd) — replace `coins: int` with four fields, plus signal and save/load
- [scripts/net/protocol.gd](../../../scripts/net/protocol.gd) — extend `CoinsUpdate` to carry four ints
- Server crates (`f:\Projects\server\crates\projectdawn-server`) — vendor logic, loot generation, save/load of player coin
- [scripts/vendor_window.gd](../../../scripts/vendor_window.gd) — display all four tiers, handle "make change" UX
- HUD — wherever a coin total is shown
- [scripts/item_data.gd](../../../scripts/item_data.gd) — decide whether `vendor_price` becomes four fields or stays as copper-total (probably copper-total, since vendor items have a single canonical price)
- New: `format_currency(p, g, s, c) -> String` helper, probably on a new `Currency` autoload
- New: NPC moneychanger scene/script (town-baseline only; Citizens use the player-to-player trade window with a moneychanger mode)
- New: Citizen-class moneychanger trade-window mode — extend the standard trade UI so a Citizen can offer an exchange rate, the requesting player sees the math, and both confirm atomically. Capital-float check on the Citizen side.
- New: bank NPC scene/script
- New: weight contribution from coin counts, integrated with the encumbrance system

The plumbing change is moderate. The UX work (make-change flow, moneychanger UI, bank UI) is where most of the time will go.
