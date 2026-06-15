# Group Loot Rights & Coin Distribution — Design

**Status: APPROVED (2026-06-15), build in progress.** This is the contract for the
loot-ownership + coin-drop + group-distribution feature. All four design forks were
ruled by the user; this doc records the decisions and the build plan.

Crosses the wire (server-authoritative). Requires a protocol bump
(PD_W0013 → PD_W0014), a GDExtension `gdext_net` rebuild, and a server rebuild —
client and server must redeploy together.

> Doc-rot note found while scoping this: root `CLAUDE.md` still calls the server
> "pre-alpha — auth only … world UDP simulation not built yet." That's stale — the
> world sim (tick/combat/loot/coin/groups) is substantially built. Fix that line
> when this lands.

---

## Problem

Coins exist end-to-end (four-tier wallet, vendor buy/sell, encumbrance, item
weights) but never enter play — the only faucet is the `GiveCoins` dev command.
Mobs drop items but no coin. And loot has **no ownership**: today *anyone within 6m*
can loot any corpse, so a stranger can steal a kill's drops. We're adding coin drops
**and** the loot-rights system they require — coin auto-distribution is meaningless
without "this corpse belongs to the killer's group."

## What already exists (no need to build)

- **Server group state** — `world/groups.rs`: `GroupManager` with `group_of(cid)`,
  `same_group(a,b)`, `Group { leader, members }`. Client `GroupManager` mirrors a
  server roster (`world_group_roster`).
- **Kill credit** — on death the server picks the top damager from `entity.aggro`
  (`tick.rs` death paths; used for XP). That is the corpse owner.
- **Member positions** — `PerConnection::pos: Vec3f` + `distance_to()`.
- **Group XP split precedent** — `tick.rs` splits XP evenly among *online* group
  members (no proximity gate). Coin split mirrors this, **plus** a proximity gate.
- **Coin infra** — `Coins` (4-tier), `Coins::add_payout`, `CoinsUpdate`; client
  `PlayerStats.add_coin_stacks/add_coins/apply_remote_coins`, `coins_changed`,
  `Currency.format_coins`.
- **Loot pipeline** — `loot.rs` (`LootBag`, `roll_for_mob`), `LootBagSpawn` /
  `LootGranted` wire msgs, client `loot_window.gd` / `remote_loot_bag_manager.gd`.

## Gaps to fill

1. `LootBag` has no **owner** → add the kill-creditor (and thus their group).
2. Loot auth is **range-only** → add "in range **and** has rights."
3. No **loot-mode** (RR/FFA) state, no **coin** roll/drop, no **coin split**, no UI.

---

## Decisions (locked)

### Ownership
- A corpse's loot belongs to the **kill-creditor's group** (if grouped) or the
  **solo killer**. The kill-creditor is the existing top-damager.
- **Strangers get nothing** — a looter not in the owning group is rejected with a
  "That isn't your loot." message. This is the core security fix.
- Solo killer: everything is theirs; mode is irrelevant.

### Loot mode (per group, leader-set, default **Round Robin**)
Stored server-side on the `Group`; synced to clients in the roster. The mode
governs **both** items and coin.

| | **Round Robin** (default) | **Free-for-all** |
|---|---|---|
| **Items** | per-**corpse** turn rotation: each corpse is assigned to the next eligible member; only they loot its items | any group member can take any item (master looter grabs all) |
| **Coin** | auto-split evenly among group members within **30m** of the corpse | **all** coin to the looter (master looter pools it, splits manually later) |

### Coin mechanic
- **Auto-acquired on loot** — credited straight to the wallet, no inventory slot,
  no option to leave it. (Same behavior will apply to own-corpse loot when the
  corpse-run system lands.)
- Shown in the corpse window (display only); looting takes it.
- **Proximity** for the RR split is measured **from the corpse**, radius **30m**
  (`GROUP_COIN_SHARE_RANGE`). Eligible = online, same group, within 30m. The member
  who walked back to town is excluded. Even split; **remainder copper → the looter**.
- Each recipient is credited via the `add_payout` path and gets a `CoinsUpdate`
  (authoritative wallet) + a private `CoinLooted { copper }` for the "You receive…"
  log line.

### Coin amounts by mob tier (per `docs/concepts/world/currency.md` → Loot Drops)
Rolled server-side on death, stored on the bag. Tunable constants in `loot.rs`.

| Tier | Detection (v1) | Coin |
|---|---|---|
| Wildlife / beast | name in a hardcoded beast list (Wolf, Rat, Spider, Bear, Snake, Bat, Boar, …) | **0** |
| Low humanoid | non-beast, level ≤ 9 | 5–50c |
| Mid humanoid | non-beast, level 10–19 | 50–300c, ~20% chance +1–3s |
| Named | non-beast, level 20–29 *(see note)* | 1–20s, ~15% chance +1–2g |
| Boss | non-beast, level ≥ 30 *(see note)* | 1–10g, ~5% chance +1p |

> **Named/boss detection is level-approximated for v1.** Named mobs aren't flagged
> server-side yet (client-only `NamedMobDefinitions`). When they're ported with a
> flag, switch named/boss to the flag. Undead (Skeleton/Zombie) are treated as
> humanoid coin-droppers (grave-coin), not beasts — tunable.

### Explicitly out of scope / unchanged
- **Group XP split stays distance-agnostic** (all online members, any distance).
  Coin is proximity-gated; XP is not. Flagged; not changing XP this pass.
- Round Robin **per-item** rotation (we chose per-corpse).
- Master-looter as a distinct role (FFA + a designated looter covers it socially).
- Own-corpse loot / corpse runs (separate to-do; coin behavior will match).

### Known v1 limitations (acceptable, documented)
- **RR unclaimed corpse**: a corpse is assigned to the next eligible member; if they
  never loot it, it expires at the linger timeout and its items are lost (use-it-or-
  lose-it). Fallback rotation can come later.
- Tier detection by level can mis-rank an off-level named mob until named mobs are
  server-flagged.

---

## Round Robin rotation (per-corpse) — precise rules

- Each `Group` holds a `loot_turn` pointer (index into `members`).
- When a corpse spawns owned by a group, assign `assigned_looter` = the next member
  in rotation **who is eligible** (online + within `GROUP_COIN_SHARE_RANGE` of the
  corpse), then advance the pointer. If none are in range, fall back to the
  kill-creditor. Solo owner → `assigned_looter` = the killer.
- In RR, **only `assigned_looter`** may loot that corpse's **items**. Other group
  members are rejected ("Not your turn.").
- **Coin ignores the turn** — it splits to all eligible (30m) members the moment the
  corpse is looted, regardless of who the assigned looter is.
- In FFA, `assigned_looter` is unset; any group member may loot items.

---

## Wire protocol changes (PD_W0013 → PD_W0014)

- **`LootBagSpawn`** gains: `coins: Coins` (display), `owner: LootOwner` (group id or
  solo player id), `assigned_looter: Option<ClientId>` (RR turn). Each client decides
  locally whether it can loot (knows its own id + group + the mode).
- **`ClientWorldMsg::SetGroupLootMode { mode: u8 }`** — leader-only; server validates
  and re-broadcasts the roster with the new mode.
- **Group roster** (`world_group_roster`) gains `loot_mode: u8`.
- **`ServerWorldMsg::CoinLooted { copper: i64 }`** — private, per recipient, drives
  the "You receive 2s 30c" log line. (Wallet itself updates via the existing
  `CoinsUpdate`.)
- **Loot reject feedback** — reuse/extend the loot result path with a reason
  ("That isn't your loot." / "Not your turn.").

GDScript mirrors in `scripts/net/protocol.gd` + the `addons/gdext_net` Rust shim must
be updated by hand and the DLL rebuilt (`build.ps1` — mind the BOM-less UTF-8 gotcha
from the 2026-05-21 session).

---

## Build plan (layered; each layer a working checkpoint)

1. **Server — loot rights foundation.** `LootBag.owner`, `Group.loot_mode`
   (default RR) + `loot_turn`, and replace the range-only auth with range + rights.
   Fixes stranger-stealing. Pure Rust, `cargo test`. *(no wire/client yet — strangers
   just get silently/explicitly rejected.)*
2. **Server — coin drops + distribution.** `roll_coin_for_mob` by tier; store on bag;
   on loot, RR → 30m even split, FFA → looter-takes-all; credit via `add_payout` +
   `CoinsUpdate` (+ `CoinLooted`). Bag spawns if items **or** coin present.
3. **Server — Round Robin item turns.** Per-corpse `assigned_looter` assignment +
   gate item loot by turn in RR.
4. **Wire + client.** Protocol bump, gdext rebuild, `SetGroupLootMode`, roster
   `loot_mode`, loot-mode toggle in `hud_group_panel.gd`, loot-window rights/turn
   states + coin display + "You receive…" log, coin in corpse window.
5. **Tests + docs.** `cargo test`, headless boot, currency smoke, a playtest
   checklist; flip the stale CLAUDE.md "auth only" line.

---

## Tuning constants (one place to retune after playtest)
- `GROUP_COIN_SHARE_RANGE = 30.0` (m) — coin split proximity.
- Coin tier bands + occasional/rare chances (table above).
- Remainder copper → looter.
- Loot mode default = Round Robin.
