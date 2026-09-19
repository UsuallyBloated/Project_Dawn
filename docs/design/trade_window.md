# The Trade Window

**Drafted 2026-09-19** (phone-era design pass; build queued behind the phase 4
deploy + playtest and the bags/dead-XP batch).
Mandate, from the slice 1.5 feedback (2026-08-28): *"a click that lands on an
entity (enemy, NPC, player) still targets but ALSO opens a trade window. EQ works
like this."* Entity clicks while holding have been target-only since, waiting on
this design.

Trading is the most storied exploit surface in MMO history. Nearly every classic
dupe came from one of three holes: client-authoritative item state, a time gap
between "remove from A" and "add to B", or a crash between two separate writes.
This project has already built the tools that close all three (server-owned
inventory, `save_stores_atomic`, the cursor slot); the design's job is to never
step outside them.

## 1. The EQ model (reference behavior)

- Click a player while holding an item: a two-sided window opens for both
  parties. Each side has a small grid of item slots and per-tier coin fields.
- You place items INTO your side from the cursor; you can retrieve them freely
  until commit.
- Both parties press Trade to commit. **Any change to either side clears BOTH
  accept states** — the anti-bait-and-switch rule, and the single most important
  line in this document.
- Giving to an NPC uses the same window one-sided (quest hand-ins).
- No-drop items refuse to enter the window.

## 2. What exists to build on

| Piece | Reuse |
|---|---|
| Cursor slot (PD_W0027) | the only way an item enters the window: from the hand |
| `GroupInvite` handshake | the two-party open/accept shape and its refusal patterns |
| `send_refusal` chat channel | every refusal arm reports, no new UI needed for errors |
| `can_accept` (probes the real placer) | receiver capacity check before commit |
| `merge_capped` | stack-cap-honest merging into the receiver |
| `save_stores_atomic` | the commit's model; trade needs a TWO-connection sibling |
| NPC proximity gate | the range-check idiom |

## 3. Design overview

**Escrow by locking, not by moving.** Offered items never leave the owner's
inventory until commit. The session records slot references plus a per-connection
`locked_slots` set; every other intent that touches a locked slot (Move, Drop,
Destroy, Sell, BankStore, Equip, SplitStack, UseConsumable) is refused with a
chat line while the trade is open. This is the crash-safety choice: there is no
moment where an item exists only inside a session object, so a server crash
mid-trade loses nothing — the session simply evaporates and everything is where
it always was.

**One server-held session per pair:**

```
Invited (A clicked B while holding)
  -> Open        (B accepts / B's client auto-opens on first offer, TBD 6.1)
  -> Offering    (either side edits slots/coins; every edit clears both accepts)
  -> OneAccepted (exactly one side has pressed Trade)
  -> Committed   (both accepted -> one db transaction -> deltas fan)
  -> Cancelled   (either side cancels, walks out of range, dies, zones,
                  disconnects, or the invite times out ~20 s)
```

**Commit is one transaction.** A new `db::commit_trade(...)` writes both
characters' inventories and wallets in a single transaction, exactly the
`save_corpse(strip_owner)` lesson. In-memory application happens in the same
tick, before the async write, with the same deferred-send-until-commit pattern
the corpse-loot path proved: deltas fan only after the db commit succeeds, and
an error reverts the in-memory swap.

**Placement on commit.** Each receiver's incoming items go through the real
placer (`add_item_locating`), so they top up stacks (`merge_capped` semantics)
and spill into bags. The pre-commit gate runs `can_accept` for BOTH receivers
against the other side's offer; if either fails, the commit refuses with a chat
line to both and clears both accepts, leaving the window open.

## 4. Wire (PD_W0028 — protocol bump, gdext rebuild, both-sides deploy)

Client intents:
- `TradeRequest { target_id }` (sent by the holding-click path)
- `TradeOfferItem { window_slot, from_location, from_slot }` and its reverse
  (`window_slot` cleared back to the inventory slot it locks)
- `TradeOfferCoins { p, g, s, c }` (absolute values, per the four-tier design)
- `TradeAccept`, `TradeCancel`

Server messages:
- `TradeOpened { partner_id, partner_name }`
- `TradeOfferUpdate { side, slots: [(path, count); 8], coins }` (full-state per
  update, not deltas — tiny payload, no desync class)
- `TradeAcceptState { you: bool, them: bool }`
- `TradeClosed { reason }` (committed / cancelled / out-of-range / timeout)
- On commit, the ordinary `InventoryDelta` + `CoinsUpdate` fans carry the
  results; the window itself never grants anything.

## 5. The exploit ledger (write the tests from this list)

1. **Bait-and-switch**: any offer edit clears both accepts, server-side, always.
2. **Dupe by double-spend**: locked slots refuse every other intent; the same
   slot cannot be offered twice; a locked slot cannot enter a second session
   because one session per player is enforced.
3. **Dupe by crash**: escrow-by-locking plus single-transaction commit; there is
   no two-write window anywhere in the flow.
4. **Coin overdraft**: coins are validated against the live wallet at offer time
   AND at commit time inside the tick (the tick loop is sequential, so nothing
   interleaves between validation and application).
5. **Stack overflow**: receiver placement goes through `merge_capped`; a 41-stack
   can never be built through a trade.
6. **Capacity griefing**: `can_accept` on both sides pre-commit; a full receiver
   refuses cleanly instead of dropping items or half-applying.
7. **Range/state escape**: the session drops on distance (`TRADE_RANGE`, ~10 m,
   checked in the tick sweep), death of either party, disconnect, or zone; a
   dropped session unlocks everything and tells both sides why.
8. **Self-trade / bot spam**: trading with yourself is refused; a `TradeRequest`
   to a player who refused or has a session open is refused quietly to the
   sender; invites time out (~20 s) so a pending invite cannot be farmed as a
   lock-denial on the target.
9. **Forged references**: every `TradeOfferItem` names a location/slot the
   server re-reads from ITS inventory state (`peek_at`); the client never names
   an item path, only a slot.
10. **Enemy/NPC targets**: v1 refuses non-player targets with the standing
    "That does nothing yet." style line; the NPC give variant is slice 2, and an
    ENEMY target is never valid.

Deliberately mirrored from existing rules: dev/GM gates do not bypass any of
this (a GM trades like a player); no-drop item flags do not exist yet, so no
rule for them until itemization grows one.

## 6. The calls — DECIDED 2026-09-19 (user, from the phone)

1. **Window slots per side: 8.**
2. **Open behavior: instant open**, EQ-style, no accept prompt.
3. **Trade range: 10 m for now.** The user's instinct is that 10 m is far for a
   trade; it stands until the first playtest, then it is a tuning candidate
   (probably downward toward the 6 m UI-interact feel).
4. **NPC give stays slice 2**, with a standing instruction: *"Keep this in mind
   while you're working. If there's an opportunity to take care of this
   sooner."* If slice 1's session/locking work leaves the one-sided variant
   nearly free, or an item-objective quest arrives first, pull it forward.

## 7. Slices and cost

- **Slice 1 (player to player)**: protocol bump PD_W0028, session + locking +
  commit server-side (with the exploit-ledger test suite), gdext rebuild, the
  window scene, the holding-click trigger in `targeting.gd`. Both sides deploy
  together (old clients cannot connect across a protocol bump, same as the
  cursor deploy).
- **Slice 2 (NPC give)**: the one-sided variant plus whatever quest-item
  consumption exists by then.
- Playtest checklist to be authored with the build; the exploit ledger above is
  its section list.
