# Player Stalls — Offline Vending

Player stalls are the end-state of the player economy. A crafter sets up a stall in a designated city district, stocks it with items at fixed prices, and logs off. Other players browse and buy while the owner is offline. When the owner logs back in, their stall's earnings are waiting in a lockbox.

This makes the crafting economy function without requiring buyers and sellers to be online simultaneously — which at any realistic server population is the failure mode of every pure player-trade system.

---

## Stall Mechanics

### Setting Up
A player opens a stall by interacting with a **Stall Post** in a designated vending district. Stall posts are fixed structures — a finite number per city, first-come basis. Taking a post costs a small daily fee (faction-scaled copper; prevents AFK squatting).

The stall UI presents:
- Item slot grid (size scales with Cartography skill — see Stall Upgrades below)
- Per-item price field
- Stall name field (defaults to `[CharacterName]'s Stall`)
- A sign field — one line of free text, visible to browsing players

Closing the stall UI while logged in leaves the stall running. Items sell in real time.

### While Offline
The stall remains active for 24 hours after the player logs out. After 24 hours, unsold items are returned to the character's inventory (overflow to a "stall return" window on login). Earnings are held in a stall lockbox, retrieved on next login.

### Browsing
Players browsing a stall district see stall names floating above each post. Clicking a stall opens a read-only shop window: the stall's listed items, prices, and sign text. Any item can be purchased directly — no negotiation, no waiting. Price is final.

### Stall Upgrades (Cartography Skill)

Cartography skill determines stall slot count — representing the crafter's familiarity with commerce routes and display organization:

| Cartography Skill | Stall Slots |
|---|---|
| 0 | 8 slots |
| 50 | 16 slots |
| 100 | 24 slots |
| 150 | 32 slots |
| 200 (Grandmaster) | 48 slots + banner display option |

The banner display (Grandmaster only) lets the stall show a larger sign visible from across the district — three lines of text. Used for advertising specializations, commission offers, and in practice, the full creative range of what players write when given a sign.

---

## Stall Districts by City

| City | District | Capacity | Notes |
|---|---|---|---|
| Greyveil | Trade Quarter — Merchant Row | 40 stalls | Most traffic; highest daily fee; competitive |
| Greyveil | River Quarter — Dock Stalls | 20 stalls | Lower fee; more foot traffic from travelers |
| Harrowmere | Open Market — South Row | 30 stalls | No faction check; Evil-aligned players operate freely here |
| Cogsworth | Clockgate Market (Level 3) | 25 stalls | Gnome/Kobold concentration; Tinkering goods |
| Millhaven | Market Square | 10 stalls | Low fee; small population; niche early-game market |
| Vel'Sharath | Trade District | 20 stalls | Evil-aligned only; unique dark-market goods |
| Stonemark | Clan Exchange | 15 stalls | Minotaur territory; Shaman reagents; limited hours |
| Aelindra | Rune Market | 20 stalls | Elf-adjacent reputation required; premium arcane goods |

---

## Economics

**Daily fee:** Set per city. Greyveil Merchant Row is most expensive; Millhaven is cheapest. The fee is taken from the lockbox earnings — if a stall earns less than the fee, the crafter pays the difference on login (credit system; cannot go negative beyond one session's fee).

**Tax:** Cities take a 5% transaction cut on all sales. This is visible to buyers (`Price: 10gp + 0.5gp city tax`). Faction standing discounts do not reduce tax — it goes to the city, not the vendor. Harrowmere: 3% (independent, no faction, lower overhead). Vel'Sharath: 8% (the Houses take their share).

**Market pressure:** Items that sit unsold for 24 hours can be flagged by the game with `[Slow Mover]` in the stall UI — private to the stall owner only. This is information, not shame. A slow-moving item is priced wrong or the market is saturated; the crafter decides what to do about it.

---

## Commission Board

Adjacent to stall districts in major cities: a **Commission Board** where players post buy orders — "I will pay X for Y quantity of Z." Crafters browsing the board can fulfill orders directly without needing a stall. The gold is held in escrow by the board system; fulfillment auto-transfers it.

Commission Board capacity scales with city size. Greyveil's board holds 200 active orders. Millhaven's holds 30.

This creates a pull economy alongside the push economy of stalls: crafters who don't want to maintain a stall can find guaranteed buyers; buyers who need specific items can post demand rather than hoping a stall has it.
