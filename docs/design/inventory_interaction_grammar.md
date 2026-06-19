# Inventory Interaction Grammar

**Status:** design spec, not yet built. Author: design session 2026-06-18.
**Audience:** the client session that will wire inventory item-moving, and the
banking session building Banker slice 2 (item storage).

This document specifies *how the player moves items with the mouse*. It is the
combination the project wants: EverQuest's **item model** (per-item stack sizes,
bags, equipment, weight, the cursor that physically carries an item) and
Minecraft's **mouse grammar** (left/right click and modifier keys to grab, split,
and place stacks quickly).

It deliberately does **not** cover the visual layout of the inventory window, the
bag grid, or the bank window. It covers only the input verbs and what each one
does to the items. Coins are **not** items here (see "Coins are separate" below).

---

## 1. The mental model: the cursor

There is one carried slot, called the **cursor**. At any moment it is either:

- **Empty** (you are carrying nothing), or
- **Holding** a stack: an item plus a count, lifted out of some slot and now
  following the mouse as a floating icon.

Every gesture below is read as "(cursor state) + (input) on (a slot)". A slot is
**empty**, **filled with the same item** as the cursor, or **filled with a
different item**.

This cursor already exists in the codebase. Left-click lifts the whole stack onto
a floating overlay that follows the mouse, and a second click places it. See
`scripts/inventory_window.gd` (`begin_drag` / `end_drag` / `cancel_drag`, and
`_on_cell_input`). The same cursor is shared by the bag windows
(`scripts/bag_window.gd`) and the paperdoll (`scripts/paperdoll_window.gd`). The
new gestures extend this model; they do not replace it.

Stack caps are **per item**: `ItemData.stack_size` (`scripts/item_data.gd`). A
value of `1` means the item never stacks (weapons, armor, bags). Stackables
(arrows, reagents, potions) carry their own cap. There is no global "64". Wherever
this doc says "up to the cap" it means up to that item's `stack_size`.

---

## 2. The full gesture grammar

### 2.1 Empty cursor, clicking a filled slot (grabbing)

| Input | Item in slot | Result |
|---|---|---|
| **Left-click** | stack of 1 (or any non-stackable: weapon, armor, bag) | Lift the whole thing onto the cursor instantly. No dialog. |
| **Left-click** | stack of N (N > 1) | Open the **quantity dialog**, pre-filled to N. Confirm (Enter) lifts all N; type a smaller number to lift only that many and leave the rest. See section 3. |
| **Shift + right-click** | stack of N | **Grab half**: lift `ceil(N / 2)` onto the cursor, leave `floor(N / 2)` behind. (Half of 1 is 1.) No dialog. |
| **Ctrl + right-click** | stack of N | **Grab one**: lift exactly 1 onto the cursor, leave N - 1. |
| **Right-click** (no container window open) | any | **Use / equip / open** the item (the existing EverQuest action): equip gear, use a consumable, open a bag, blow a mount whistle. This is today's behavior in `_on_cell_input`; keep it. |
| **Right-click** (a container window, e.g. the Bank, is open) | any | **Quick-transfer** the whole stack to the other container. See section 4. |

Notes:

- The quantity dialog on plain left-click is a deliberate choice: it means the
  player never needs a modifier to pull an exact amount, at the cost of one extra
  keypress (Enter) when they just want the whole stack. Single (non-stack) items
  skip the dialog so routine gear-moving stays instant.
- **Shift + right-click is the "half" key in both states:** grab half with an
  empty cursor, place half while holding (section 2.2). That symmetry is the reason
  grab half lives on shift + right, not shift + left.
- `Shift + left-click` and `Ctrl + left-click` are intentionally left unbound
  (reserved).

### 2.2 Holding a stack, clicking a slot (placing)

| Input | Target slot | Result |
|---|---|---|
| **Left-click** | empty | Place the entire held stack. Cursor becomes empty. |
| **Left-click** | same item, below cap | **Merge**: fill the target up to its cap. Any remainder stays on the cursor. |
| **Left-click** | same item, already at cap | Nothing happens (cannot add, and same-item never swaps). |
| **Left-click** | different item | **Swap**: the held stack drops into the slot, the slot's item lifts onto the cursor. |
| **Right-click** | empty | **Place one**: drop 1, cursor count drops by 1. |
| **Right-click** | same item, below cap | **Place one**: add 1 to the slot, cursor drops by 1. |
| **Right-click** | same item at cap, or different item | Nothing happens. Place-one never swaps. |
| **Shift + right-click** | empty | **Place half**: drop `ceil(held / 2)` into the slot. |
| **Shift + right-click** | same item, below cap | **Place half**: merge `ceil(held / 2)` up to the cap; overflow stays on the cursor. |
| **Shift + right-click** | different item | Nothing happens. |
| **Ctrl + right-click** | same item, cursor below cap | **Grab one more**: pull 1 from the slot onto the cursor (cursor +1, slot -1). |
| **Ctrl + right-click** | different item, or cursor at cap, or empty slot | Nothing happens. |
| **Double left-click** | any | **Gather**: see section 5. |

> Important behavior change from today's code: the current placement path *always
> swaps* on an occupied slot (`scripts/inventory_window.gd`, the swap branch in
> `_on_cell_input`). The grammar above **merges same-item stacks** and only swaps
> on a *different* item. That merge behavior is the Minecraft feel the project
> wants, and the server already supports it (section 6).

### 2.3 Rounding, summarized

- **Grab half** and **place half** round **up** (you take/place the larger half).
  5 grabs 3 and leaves 2.
- **Grab one** / **place one** are exactly 1.
- These are the chosen defaults. They are easy to flip if playtest says
  otherwise; they are not load-bearing.

---

## 3. The quantity (split) dialog

Opened by a plain left-click on a stack of N > 1 with an empty cursor.

- A small modal with a numeric field, **pre-filled to N** (the full stack), min 1,
  max N.
- Enter / Confirm lifts the chosen amount onto the cursor; the remainder stays in
  the source slot.
- Cancel / Escape leaves the stack untouched.
- This is the EverQuest "how many?" prompt. It is the precise-amount path (for
  example, pull exactly 50 arrows to deposit). The half / one gestures are the
  fast paths for the common splits.

The bank's withdraw flow can reuse the same dialog (left-click a bank stack to
pull an exact amount onto the cursor, then drop it into your inventory).

---

## 4. Quick-transfer (the banking deposit gesture)

This is the gesture the banking session most needs.

**Rule:** while the **Bank** window is open, **right-click on an item** sends the
**whole stack** to the *other* container (inventory to bank, or bank to
inventory, whichever side the item is currently on).

Placement on the far side:

1. First **merge** into any existing stacks of the same item there, filling each
   up to its cap.
2. Then drop whatever is left into the **first empty slot(s)**.
3. If the far side has no room for the remainder, leave that remainder where it
   was and surface a short "no room" line. This mirrors how the bank coin path
   already reports rejects through `CombatLog` (`scripts/bank_window.gd`,
   `_on_bank_rejected`).

Scope (decided): **Bank only, for now.** Vendor and Loot windows keep their
current click behavior. When no container window is open, right-click reverts to
its normal use / equip / open meaning (section 2.1). So right-click's meaning
depends on whether a paired container is open. That context switch is the whole
trick; make it explicit in the code (a single "is a transfer target open?" check),
because it is the part most likely to confuse a future reader.

**Both paths coexist:**

- **Right-click** = fast "dump the whole stack across" (deposit / withdraw all).
- **Cursor placement** = precise. Left-click a stack to grab some (whole, half,
  one, or an exact amount via the dialog), then left-click the specific bank slot
  you want it in. This is how a player deposits *part* of a stack, or arranges the
  bank grid by hand.

**Double-click gather** (section 5) also works inside the bank, letting a player
consolidate scattered stacks of one item before or after depositing.

**Coins** follow this same right-click quick-transfer, but only ever between coin
stores (the wallet and the bank's coin store), never into an item slot. See
section 7.

---

## 5. Double-click to gather

**Rule:** while **holding** an item on the cursor, **double left-click** any slot
in a container to pull every other stack of that same item in **that container**
onto the cursor, up to the item's cap.

- Keyed to the **cursor's** item, not the clicked slot's item. You normally
  double-click a matching stack, but the gather always collects the item you are
  carrying.
- Stops as soon as the cursor reaches `stack_size`.
- Stays within one container: double-clicking in the bank gathers from the bank,
  double-clicking in the inventory gathers from the inventory. It does not vacuum
  across the wire from the other side.

**Why holding-only:** with an empty cursor, a single left-click on a stack opens
the quantity dialog (section 2.1), so an empty-cursor double-click would just open
two dialogs. Gather therefore lives in the holding state, where left-clicks are
unambiguous. To start a gather from nothing, grab one stack first (any grab
gesture), then double-click. See the single/double-click note in section 6.

---

## 6. Implementation and netcode notes

The interaction is client-side input, but this is a **server-authoritative**
game, so every item move must be reconciled with the server. Read
`docs/concepts/architecture/README.md` and the server's `server_design.md` before
wiring this.

### 6.1 What the wire already has

Two intents already exist and cover almost everything here:

- `Net.broadcast_move_item(src_location, src_slot, dst_location, dst_slot)`
  (`autoloads/net.gd`). Whole-slot move and swap. The server validates and fans an
  `InventoryDelta` per touched slot.
- `Net.broadcast_split_stack(src_location, src_slot, dst_location, dst_slot, count)`
  (`autoloads/net.gd`). Moves `count` items from src to dst. The dst must be empty
  or hold the **same** item; the server rejects a different-item dst (use
  `move_item` for swaps). It fans one delta per touched slot.

So grab-half, grab-one, place-one, place-half, and the exact-amount dialog are all
"compute a count, send `SplitStack`". Same-item merge is `SplitStack` into a
same-item dst. Swap is `MoveItem`. **No new server combat/inventory math is needed
for splitting itself.** Locations today: `"base"`, `"equip"`, `"bag_<i>"`
(`scripts/net/protocol.gd`, `INV_LOCATION_BASE` / `INV_LOCATION_EQUIP` /
`inv_location_bag`).

### 6.2 The one real design problem: the cursor on the wire

Today the cursor is **client-only**. In launcher mode, picking a stack up does
*not* mutate server state; the source slot stays filled server-side and the move
is sent as a single `MoveItem` only when the player drops it
(`scripts/inventory_window.gd`, the launcher-mode branch). That works **only**
because the whole stack moves as a unit.

Partial gestures break that shortcut. Example: grab half of 20 (cursor shows 10,
source should show 10), then drop the 10 onto a slot holding a *different* item. A
correct result is a swap of "the 10 on the cursor" with that item, while the other
10 stay in the source. That is **not** expressible as one `MoveItem(src, dst)`,
because `MoveItem` would move the whole 20.

Recommended fix: **make the cursor a real, server-tracked slot.** Add a location
(for example `"cursor"`) and resolve **every gesture as its own atomic intent**
against it:

| Gesture | Wire |
|---|---|
| grab whole / single | `MoveItem(src -> cursor)` |
| grab N (dialog), grab half, grab one | `SplitStack(src -> cursor, count)` |
| place all onto empty / different item | `MoveItem(cursor -> dst)` (server resolves swap) |
| merge all / place one / place half into same item | `SplitStack(cursor -> dst, count)` |
| grab one more onto cursor | `SplitStack(dst -> cursor, 1)` |
| quick-transfer (right-click, bank open) | one server-side "move to paired container" intent (merge then first-empty); likely a small new intent the banking session adds |

This makes the client cursor a mirror of an authoritative slot, kills the
partial-cursor desync class entirely, and reuses the existing ops. It is more
per-click traffic than the deferred model, but item-moving is low frequency and
the correctness win is large. If the team instead keeps the deferred client cursor
for feel, it must special-case partial-cursor swaps; flag that as the risk.

### 6.3 Optimistic vs authoritative feel

The current move path waits for the server `InventoryDelta` before repainting (no
optimistic local mutation in launcher mode). The cursor is the thing under the
mouse, so round-trip lag there is very noticeable. Recommendation: predict the
cursor and slot counts locally on click, then reconcile against the delta (snap
back if the server disagrees). Tune during playtest.

### 6.4 Single vs double-click

Gather is a double-click and lives in the holding state, so it does **not** fight
the empty-cursor dialog. Within the holding state, the first click of a
double-click would normally place; the cleanest implementation detects the second
click within the OS double-click threshold and treats the pair as a single gather
intent (suppressing the intermediate place). Note the small added latency on a
held left-click and tune it.

---

## 7. Coins

Coins are the four-tier wallet: platinum / gold / silver / copper
(`PlayerStats.platinum / gold / silver / copper`). They are **not** `ItemData`,
but they now use the **same cursor grammar** as item stacks for moving and
splitting, with one hard constraint:

> **Coins never occupy an item or bag slot.** Their home is a *coin store*: the
> carried wallet, or (once deposited) the bank's coin store. A coin stack lifted
> onto the cursor can only be dropped onto another coin store. Dropping it onto a
> regular inventory or bag slot is rejected and snaps back.

Rules:

- **Each denomination is its own stack** (copper, silver, gold, platinum). You pick
  up one tier at a time. The cursor then holds, for example, "240 copper".
- Picking up and splitting use the exact same gestures as any stack: plain
  left-click opens the quantity dialog pre-filled to the full tier amount,
  `shift + right` grabs half, `ctrl + right` grabs one, and so on (section 2).
- Coins still carry **weight** (per-coin), unlike most items. That is unchanged.

### Bank deposit / withdraw (the change)

- The slice 1 **Deposit and Withdraw buttons and their spinboxes are removed.**
- Depositing is now a **move**: pick coins up from the wallet, drop them on the
  bank's coin store. Withdrawing is the reverse. The dialog / half / one gestures
  give exact or quick amounts.
- The **right-click quick-transfer** (section 4) applies too: while the bank is
  open, right-click a wallet coin tier to deposit that whole tier, or a bank coin
  tier to withdraw it.
- **The free tier exchange control stays** (100 copper = 1 silver, etc.). It is a
  conversion, not a move, so it keeps its existing from / to / quantity control and
  `broadcast_bank_exchange`. Only the deposit/withdraw buttons go away.

### Implementation notes

- The wire intents for coin deposit / withdraw **already exist** and stay:
  `broadcast_bank_deposit` / `broadcast_bank_withdraw` carry per-tier amounts
  (`autoloads/net.gd`). Only the *trigger* changes, from button presses to cursor
  drops and right-click transfers. So this is largely a UI rewire, not new netcode.
- For the gestures to have a target, the wallet line and the bank's coin line must
  become **clickable per-tier coin slots** (four each), not the single read-only
  label they are today (`scripts/inventory_window.gd` `_wallet_label`;
  `scripts/bank_window.gd` `_wallet_lbl` / `_bank_lbl`). That is a layout change,
  noted here only because the interaction depends on it.
- The coin cursor is conceptually distinct from the item cursor (it carries a
  denomination + amount, not an `ItemData`). Implement it as a typed variant of the
  same cursor so the player only ever sees one thing on the mouse at a time, and so
  the "valid drop target" check can reject item slots for a coin cursor (and coin
  stores for an item cursor).

---

## 8. Item flags and edge cases

- **Bags** (`ItemData.Type.BAG`) always have count 1, so they pick up whole with
  no dialog. No bag-in-bag: a bag cannot be placed into another bag's slots
  (existing rule in `Inventory.add_item`). Decide whether bags may go into the
  bank at all (slice 2 storage is a flat slot list today).
- **Equipment / weapons** are non-stackable (count 1), so they skip the dialog and
  pick up instantly. Right-click still equips them when no container is open.
- **Mount whistles** (`is_mount`) are right-click "use" when no container is open;
  they are not consumed.
- **No-drop / account-binding:** there is **no** no-drop / no-trade flag on
  `ItemData` today. EQ's account-shared bank slots (the 2 shared slots in Banker
  slice 2) traditionally reject character-bound items. If that rule is wanted, a
  new flag on `ItemData` is needed, and the bank's placement / quick-transfer must
  reject bound items into shared slots with a `CombatLog` line. Flagging here so
  the banking session can scope it.

---

## 9. What exists today vs what is new

**Already there:**

- The client cursor (lift / place / swap whole stacks): `inventory_window.gd`,
  `bag_window.gd`, `paperdoll_window.gd`.
- Per-item stack caps and merge-on-pickup: `Inventory.add_item`, `stack_all`
  (`autoloads/inventory.gd`).
- Wire ops `MoveItem` and `SplitStack`, and `InventorySnapshot` / `InventoryDelta`
  reconcile (`autoloads/net.gd`, `autoloads/inventory.gd`).
- Bank coin deposit / withdraw / exchange (`bank_window.gd`).

**New for this spec:**

- Grab half (`shift + right`, empty cursor), grab one (`ctrl + right`), place one
  (`right` while holding), place half (`shift + right` while holding), grab one
  more (`ctrl + right` while holding). `shift + right` is the unified "half" key:
  grab half when empty, place half when holding.
- The quantity dialog on plain left-click of a stack > 1.
- Same-item **merge** on placement (replacing today's always-swap).
- Double-click gather.
- Quick-transfer on right-click while the Bank is open.
- A bank inventory **location** on the wire (`"bank"` and a shared variant), the
  bank item grid UI, and `BankSnapshot` / `BankDelta` for items: the banking
  session's slice 2.
- Coins move by cursor instead of buttons: the bank's coin deposit / withdraw
  **buttons are removed**, replaced by cursor drops plus right-click
  quick-transfer; the wallet and bank coin lines become clickable per-tier slots; a
  coin-typed cursor that can only target coin stores. The free exchange control and
  the existing deposit/withdraw wire intents stay (section 7).
- (Recommended) the server-tracked cursor slot from section 6.2.

---

## 10. Open decisions left to the implementer

- Server-tracked cursor (recommended) vs keep the deferred client cursor and
  special-case partial swaps (section 6.2).
- Optimistic cursor prediction vs strict wait-for-delta (section 6.3).
- Half-rounding direction (default: up).
- Whether bags may be stored in the bank, and whether shared bank slots need a
  no-drop flag (section 8).
- Coin cursor shape: per-tier stacks, one denomination at a time (the default
  chosen here), vs a single mixed-coin cursor (section 7).
