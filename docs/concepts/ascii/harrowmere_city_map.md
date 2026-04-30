# Harrowmere — City Map (ASCII)

*Independent coastal port city. Five districts. 40,000 people. Neutral by policy and profitable by design. Built on the assumption that trade does not care who you are — and neither do the docks.*

---

## City Overview

```
              ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
              ≈         HARROW BAY          ≈
              ≈  [sea content — mid-level]  ≈
              ≈  [the Drowned Hold island   ≈
              ≈   is visible from the docks]≈
              ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
                   |         |         |
              [PIER A]  [PIER B]  [PIER C]
                   |         |         |
    ┌──────────────────────────────────────────────┐
    │              THE DOCKFRONT                   │
    │                                              │
    │  [HARBORMASTER'S OFFICE]   [IRON ROPE GUARD] │
    │  Jeven Crost (14 years)    [checkpoint]      │
    │  [ship registry]           [harbor watch]    │
    │  [salvage license desk]    [not cheap]       │
    │  [cargo manifests]                           │
    │                                              │
    │  [BONDED WAREHOUSES — east dockfront]        │
    │  ████████████████████████████████████████   │
    │  █  cargo by client  █  restricted section  █│
    │  █  (Compact-insured)█  (Compact authority) █│
    │  ████████████████████████████████████████   │
    │                                              │
    └─────────────┬──────────────────┬─────────────┘
                  │                  │
       ┌──────────┴──────┐  ┌────────┴────────────┐
       │  MERCHANT       │  │  SAILORS' QUARTER   │
       │  DISTRICT       │  │                     │
       │                 │  │  [THE GREY ANCHOR]  │
       │ [DOCK-           │  │  Orreth (Minotaur)  │
       │  MASTERS' HALL] │  │  [corner table —    │
       │ [five seats;     │  │   someone is always │
       │  two empty;      │  │   there already]    │
       │  everyone        │  │  [deals made here;  │
       │  notices]        │  │   not written down] │
       │                 │  │                     │
       │ [FREIGHT         │  │  [cheap rooms]      │
       │  EXCHANGE]      │  │  [cheaper food]     │
       │ [CURRENCY        │  │  [dock crew inns]   │
       │  EXCHANGE]      │  │  [pilot hire desk]  │
       │                 │  └─────────────────────┘
       └──────────┬──────┘
                  │
       ┌──────────┴──────────────────────────────┐
       │           TRADE DISTRICT                 │
       │                                          │
       │  [MARKET HALL — open daily]              │
       │  □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □      │
       │  □ □ □ □ □ □ □ □ □ □ □ □ □ □ □ □      │
       │  goods from everywhere; prices           │
       │  competitive because the Compact         │
       │  takes 5% and doesn't care what you sell │
       │                                          │
       │  [THIRD DOCK IMPORT STALLS]              │
       │  Delvar Senne's operation               │
       │  [eastern goods] [underground goods]     │
       │  [the manifests don't always match]      │
       │  [the Iron Rope guard at this end        │
       │   is paid to have slow eyes]             │
       └─────────────────────────────────────────┘
                  │
       ┌──────────┴──────────────────────────────┐
       │           RESIDENTIAL DISTRICT           │
       │                                          │
       │  [SILVER ROAD INN — the good one]        │
       │  [VETHIS TEMPLE — door open]             │
       │  [small Mireth shrine — above the        │
       │   inn's back doorframe; locals touch     │
       │   it before anything important]          │
       │                                          │
       │  [HOUSING — mixed races, mixed income]   │
       │  Harrowmere does not sort by race        │
       │  or alignment; it sorts by rent          │
       └─────────────────────────────────────────┘
                  │
       [LAND GATE] → roads to wider region
```

---

## Harrow Bay — Sea Content

```
    ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
    ≈                                         ≈
    ≈  [SEA LANES — active shipping]          ≈
    ≈  [salvage zones — wrecks from past      ≈
    ≈   storms; Compact issues licenses]      ≈
    ≈                                         ≈
    ≈  ┌────────────────────────────────┐     ≈
    ≈  │  THE DROWNED HOLD ISLAND       │     ≈
    ≈  │  (visible from the docks;      │     ≈
    ≈  │   accessible by boat;          │     ≈
    ≈  │   three licensed expeditions   │     ≈
    ≈  │   have left; none returned     │     ≈
    ≈  │   with significant profit)     │     ≈
    ≈  │                                │     ≈
    ≈  │  [dungeon — levels 20-30]      │     ≈
    ≈  │  [Captain Morreth the Returned]│     ≈
    ≈  └────────────────────────────────┘     ≈
    ≈                                         ≈
    ≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈
```

---

## The Dockmasters' Hall — Detail

```
    ╔══════════════════════════════════════════╗
    ║         DOCKMASTERS' HALL                ║
    ║                                          ║
    ║  ┌──────────────────────────────────┐   ║
    ║  │     COUNCIL CHAMBER              │   ║
    ║  │                                  │   ║
    ║  │  [SEAT 1 — Margot Hale]          │   ║
    ║  │  [SEAT 2 — Cam Oreigh]           │   ║
    ║  │  [SEAT 3 — Delvar Senne]         │   ║
    ║  │  [SEAT 4 — Wren Ashford]         │   ║
    ║  │  [SEAT 5 — VACANT   ] ← 6 years │   ║
    ║  │  [SEAT 6 — VACANT   ] ← 6 years │   ║
    ║  │  [SEAT 7 — Thalia Mourne]        │   ║
    ║  │                                  │   ║
    ║  │  the two empty chairs are always │   ║
    ║  │  present at the table            │   ║
    ║  │  nobody sits in them             │   ║
    ║  │  nobody moves them               │   ║
    ║  └──────────────────────────────────┘   ║
    ║                                          ║
    ║  [RECORDS OFFICE]  [ARBITRATION ROOM]   ║
    ║  [tariff schedules][dispute resolution] ║
    ║  [sailing licenses][current: 3 active   ║
    ║                     Drowned Hold        ║
    ║                     licenses; 0 open]  ║
    ╚══════════════════════════════════════════╝
```

---

## The Grey Anchor — Detail

```
    ┌────────────────────────────────────────┐
    │           THE GREY ANCHOR              │
    │                                        │
    │  ┌────────────────────────────────┐   │
    │  │           MAIN ROOM            │   │
    │  │                                │   │
    │  │  [tables — round; all of them] │   │
    │  │  [no bad seat at a round       │   │
    │  │   table; Orreth chose these    │   │
    │  │   deliberately]                │   │
    │  │                                │   │
    │  │  ╔══════════════════╗          │   │
    │  │  ║  CORNER TABLE    ║ ← always │   │
    │  │  ║  [someone is     ║   occupied│   │
    │  │  ║   already here]  ║           │   │
    │  │  ║  [they are there ║           │   │
    │  │  ║   for a reason]  ║           │   │
    │  │  ╚══════════════════╝          │   │
    │  │                                │   │
    │  │  [BAR — Orreth]                │   │
    │  │  [charges everyone the same]   │   │
    │  │  [has heard every deal made    │   │
    │  │   in this room for 8 years]    │   │
    │  │  [has not repeated any of them]│   │
    │  └────────────────────────────────┘   │
    │                                        │
    │  [back room — private; costs extra]    │
    │  [the Dockmasters use it; so does      │
    │   anyone with enough coin and the      │
    │   sense to ask Orreth correctly]       │
    └────────────────────────────────────────┘
```

---

## Key Locations Summary

| Location | District | Purpose | Notes |
|---|---|---|---|
| Harbormaster's Office | Dockfront | Ship registry, salvage licenses | Jeven Crost; most trusted person in city |
| Iron Rope Guard Post | Dockfront | Harbor security | Contracted; loyalty is to the rate |
| Bonded Warehouses | Dockfront | Insured cargo storage | Restricted section requires Compact Standing 1000 |
| Dockmasters' Hall | Merchant | City governance | Five active seats; two empty; the chairs stay |
| Freight Exchange | Merchant | Cargo brokerage | Connects buyers to shippers |
| Currency Exchange | Merchant | Money changing | Seventh Dock rates; weekly update |
| Third Dock Stalls | Trade | Eastern/underground imports | Delvar Senne's operation; irregular manifests |
| Market Hall | Trade | Open trade | Competitive prices; 5% Compact tax; no questions |
| The Grey Anchor | Sailors' | Tavern, deal-making | Orreth; the corner table; the back room |
| Dock Crew Inns | Sailors' | Cheap lodging | Functional; not comfortable |
| Silver Road Inn | Residential | Quality lodging | The one travelers ask for by name |
| Vethis Temple | Residential | Funerary rites | Door always open; busier than expected |
| Mireth Shrine | Residential | Luck acknowledgment | Above the inn's back door; locals touch it |
| Drowned Hold Island | Harrow Bay | Dungeon (lvl 20-30) | Visible from docks; boat required; license required |
