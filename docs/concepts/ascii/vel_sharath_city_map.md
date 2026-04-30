# Vel'Sharath — City Map (ASCII)

*The Dark Elf undercity. Deep beneath the central mountain range. Beautiful, trap-like, and designed so you never see the same path twice.*

---

## Approach and Entry

```
                    SURFACE
                      │
    ══════════════════╪═══════════════════
    MOUNTAIN RANGE    │
                      │ [no surface
                      │  presence —
                      │  entry is
                      │  underground]
                      │
               ╔══════╧══════╗
               ║  THE DESCENT ║
               ║  [3 levels   ║
               ║   of guard   ║
               ║   checks]    ║
               ║  [name log]  ║
               ║  [purpose   ║
               ║   stated]    ║
               ╚══════╤══════╝
                      │ ↓ deeper
```

---

## City Layout — Vertical Cross-Section

```
    SURFACE ─────────────────────────────────────────
                                         (no presence)

    LEVEL 1 — THE APPROACH (transition zone)
    ┌───────────────────────────────────────────────┐
    │  guard posts │ visitor processing │ name log   │
    │  [outsider-facing; designed for control]       │
    └───────────────────────────┬───────────────────┘
                                │ ↓

    LEVEL 2 — OUTER VEL'SHARATH (commercial)
    ┌───────────────────────────────────────────────┐
    │                                               │
    │  [TRADE DISTRICT]          [INN DISTRICT]     │
    │  ┌──────────────┐          ┌──────────────┐  │
    │  │ market stalls│          │ outsider inns│  │
    │  │ refined metals│         │ [you are     │  │
    │  │ alchemicals  │          │  watched     │  │
    │  │ obsidian work│          │  here]       │  │
    │  └──────────────┘          └──────────────┘  │
    │                                               │
    │  [FUNGAL GARDENS] ← bioluminescent; beautiful │
    │  permanent light source; also food supply     │
    │                                               │
    └───────────────────────────┬───────────────────┘
                                │ ↓ [deeper requires standing]

    LEVEL 3 — MID CITY (residential, craft)
    ┌───────────────────────────────────────────────┐
    │                                               │
    │  [LESSER HOUSE DISTRICT]   [CRAFT HALLS]      │
    │  Drak' prefix houses       ┌──────────────┐  │
    │  lower status but          │ Blacksmithing │  │
    │  still House rules apply   │ Enchanting    │  │
    │                            │ Bone Carving  │  │
    │                            │ Necro Scribing│  │
    │  [OBSIDIAN BRIDGES]        └──────────────┘  │
    │  ← connecting the mid-city sections          │
    │  ← some bridges only in certain directions   │
    │  ← the path back is usually not the same     │
    │                                               │
    └───────────────────────────┬───────────────────┘
                                │ ↓ [requires High standing or escort]

    LEVEL 4 — UPPER VEL'SHARATH (power)
    ┌───────────────────────────────────────────────┐
    │                                               │
    │  ╔══════════════╗   ╔══════════════════════╗ │
    │  ║  GREAT HOUSE ║   ║  TEMPLE OF THE LOOM  ║ │
    │  ║  DISTRICT    ║   ║  (Aracheth)          ║ │
    │  ║  Vel' prefix ║   ║  [all-female clergy] ║ │
    │  ║  all female  ║   ║  [THE THREAD]        ║ │
    │  ║  leadership  ║   ║  [connects spire     ║ │
    │  ║  political   ║   ║   to vault below]    ║ │
    │  ║  intrigues   ║   ║  [oldest archive]    ║ │
    │  ╚══════════════╝   ╚══════════════════════╝ │
    │                                               │
    │  [UNLICENSED WING — off the map]              │
    │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░              │
    │  ░  intake hall   wrong geometry  ░           │
    │  ░  experiment wing              ░           │
    │  ░  the revoked                  ░           │
    │  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░              │
    │                                               │
    └───────────────────────────┬───────────────────┘
                                │ ↓ [restricted — High Matron authorization]

    LEVEL 5 — DEEP CITY (secret / dungeon)
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
    ░  [VAULT DISTRICT LAB — see necromancer doc] ░
    ░  [intelligence archive — Temple of the Loom]░
    ░  [THE THREAD — Temple spire to vault shaft] ░
    ░  [underground lake — obsidian bridges over] ░
    ░  [the oldest part of the city]              ░
    ░  [something was here before the Dark Elves] ░
    ░  [the architecture changes at a certain     ░
    ░   depth — Dark Elf hand stops; different    ░
    ░   hand begins; six-finger span on the       ░
    ░   original doorframe measurements]          ░
    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

---

## The Temple of the Loom — Detail

```
    ╔══════════════════════════════════════════════╗
    ║          TEMPLE OF THE LOOM                  ║
    ║                                              ║
    ║  [MAIN HALL — ritual space]                  ║
    ║  ████████████████████████████████████████   ║
    ║  █                                      █   ║
    ║  █   spider-leg pillars (8)              █   ║
    ║  █   central altar — web-form obsidian  █   ║
    ║  █   Aracheth image — always seated,    █   ║
    ║  █   always writing                     █   ║
    ║  █                                      █   ║
    ║  ████████████████████████████████████████   ║
    ║                                              ║
    ║  [ARCHIVE LEVEL 1]  [ARCHIVE LEVEL 2]        ║
    ║  open to Strand-Walker+  sealed to all but  ║
    ║                          Thread-Cutter+     ║
    ║                                              ║
    ║  [THE THREAD] ↓                              ║
    ║  connecting shaft: spire top ↕ vault below   ║
    ║  outsiders may not see this                  ║
    ║  the High Priestess has entered 3 times      ║
    ╚══════════════════════════════════════════════╝
```

---

## Navigation Note

The architecture of Vel'Sharath is deliberately designed to confuse. Key features:
- **Bridges are directional** — many obsidian bridges only cross in one direction; the return path requires a different route
- **Levels are not strictly horizontal** — some sections of Level 3 connect to different parts of Level 2 depending on which path you took to get there
- **Lighting is calibrated** — the bioluminescent fungal light is beautiful and makes everything look slightly different than it is; shadow placement is deliberate
- **No map is sold** — the Visitor Processing office on Level 1 does not provide maps; they provide an escort service (priced to be prohibitive) or a written description that is technically accurate but practically useless

Players visiting Vel'Sharath for the first time will get lost. This is intended. Players who have been there multiple times will get less lost. Players with high Vel'Sharath standing will be offered a guide.

---

## Key Locations Summary

| Location | Level | Purpose | Access |
|---|---|---|---|
| Visitor Processing | 1 | Entry control, name log | All |
| Trade District | 2 | Metals, alchemicals, obsidian work | All |
| Inn District | 2 | Lodging for outsiders | All (watched) |
| Fungal Gardens | 2 | Light source, food supply, aesthetic | All |
| Lesser House District | 3 | Dark Elf housing (minor Houses) | Moderate standing |
| Craft Halls | 3 | Enchanting to 175, Bone Carving, Necromantic Scribing | Moderate standing |
| Great House District | 4 | Political center; all Great Houses | High standing or escort |
| Temple of the Loom | 4 | Aracheth temple; intelligence hub | Varies by rank |
| Unlicensed Wing | 4 (off-map) | Dungeon — experimentation, the Revoked | Discoverable |
| Vault District Lab | 5 | Necromancer research | High standing + Dark Elf or Necromancer |
| Deep archive | 5 | Temple intelligence records | Thread-Cutter or above only |
