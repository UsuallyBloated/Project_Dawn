# Banker NPC Slice 2 (item storage) Playtest Checklist 2026-06-19

Slice 2 adds item storage to the Banker: a 10-slot per-character vault plus 2 account-shared
slots (the EQ "shared bank", for moving items between your own characters). It also enforces
one character per account in-world. The deposit gesture is the right-click quick-transfer from
the interaction grammar: with the bank open, right-click an item to send the whole stack to the
selected vault; right-click a vault slot to withdraw. Coins gained the same right-click
quick-transfer (the slice-1 buttons are kept). Design: `docs/concepts/world/currency.md`,
`docs/design/inventory_interaction_grammar.md`, `docs/session_notes/handoff_banker_npc.md`.

> BUILD PREREQUISITE: this is a PD_W0016 wire bump. Rebuild the gdext DLL
> (`addons/gdext_net/build.ps1`) AND the server, or you are rejected at connect. Run the
> server with PD_DEV_CMDS for the Test Panel item/money buttons:
> `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server *>&1 | Tee-Object server.log`

| Thing | Value / how | Notes |
|---|---|---|
| Open the Items tab | target Thalia, interact, click the "Items" tab | Coins tab is the default |
| Deposit an item | with the bank open, right-click an item in your bags | whole stack to the selected vault (Personal default) |
| Deposit target | the "Deposit to: Personal / Shared" toggle | picks which vault a deposit goes to |
| Withdraw an item | right-click a vault slot | whole stack back to inventory |
| Personal vault | 10 slots, this character only | warm border |
| Shared vault | 2 slots, all characters on your account | cool blue border |
| Coin quick-transfer | right-click a Carried or Bank coin tier (Coins tab) | deposits/withdraws that whole tier |

Diagnostics: in-game console; server console anchors `bank store item`, `bank withdraw item`,
`duplicate login`. Use a stack-10 item to exercise stacking (Water Flask or a Minor Healing
Potion, both stack to 10).

## Setup
- [x] Rebuild server (PD_DEV_CMDS) AND the gdext DLL from the PD_W0016 commits.
- [x] One character (A) logged in. For the shared-vault and enforcement tests, have a SECOND
  character (B) on the SAME account available to log into.
- [x] Seed some items into A's bags (Test Panel / dev grant), including a stackable.

## 1. Deposit and withdraw (personal vault)
- [x] **Open the bank, switch to the Items tab, right-click a single item in your bags (Personal selected)** then it lands in the first free personal vault slot and leaves your bags. notes:
- [x] **Right-click that vault slot** then the item returns to your bags and the vault slot clears. notes:
- [x] **Deposit 25 of a stack-10 item (e.g. Water Flask)** then it fills three vault slots (10, 10, 5), stacking. notes:
- [x] **Deposit more of the same item so it tops up a partial vault stack** then it merges up to 10 before claiming a new slot. notes:
- [x] **Fill all 10 personal slots, then try to deposit another distinct item** then rejected ("Your bank vault is full."), nothing moves. notes:

## 2. Shared vault (account-shared, cross-character)
- [x] **Switch the toggle to Shared, right-click an item to deposit** then it lands in one of the 2 shared (blue) slots. notes:
- [x] **Log out of character A, log in character B on the same account, open the bank** then the item A deposited is in B's shared vault (the 2 shared slots are the same for both). notes:
- [x] **Withdraw it on B, deposit a different item to shared, switch back to A** then A sees B's change (shared state is per account). notes:

## 3. One character per account (deny the duplicate login)
> Behavior changed mid-session per playtest feedback: a duplicate login is now REFUSED rather
> than booting the session already playing (avoids the Lineage II re-login force-off exploit).
> Retest the new behavior:
- [x] **With A logged in, log in B on the same account (do not log A out first)** then B's login is REFUSED with "You already have a character in this world." shown in the lobby, and A keeps playing, undisturbed. notes:
- [x] **Log A out cleanly, then log in B on the same account** then B connects normally (a clean logout frees the account at once). notes:
- [x] **Kill A's client (unclean), then immediately try to log back in** then login is refused until A's stale session times out, then succeeds (known deny-on-duplicate tradeoff). notes:  Killed A's client, then immediately logged back in successfully.  

## 4. Edge cases
- [x] **Try to deposit a bag (an item that holds other items)** then rejected ("Bags can't go in the bank vault."). notes: Tried with dev command "Give Bags"  Worn Satchel and Small Pouch both tested.  Also noticing that left-click is opening the bags, when it should be right-click, but these bags were created before we did the recent work on the inventory/cursor/bank.
- [x] **With your bags full, withdraw a vault item that does not fit** then it stays in the vault and a "No room in your inventory." line appears. notes:

## 5. Coin quick-transfer (Coins tab, buttons kept)
- [x] **On the Coins tab, right-click a Carried coin tier (e.g. copper)** then that whole tier deposits to the bank. notes:
- [x] **Right-click a Bank coin tier** then that whole tier withdraws to your wallet. notes:
- [x] **The Deposit / Withdraw buttons and the exchange control still work** as in slice 1. notes:

## 6. Persistence
- [x] **Deposit items to both the personal and shared vaults, then log out and back in** then both vaults are intact on next open. notes:
- [x] **Deposit, then log out immediately (no 60s wait)** then still intact on return (disconnect flush). notes:

## Known scope (not bugs)
- **Partial item moves** (grab half, exact-amount split, drag-and-drop) are the separate cursor
  interaction grammar track, not this slice. This slice moves whole stacks via right-click.
- **No proximity gate** on bank actions yet (matches the vendor pattern; value-preserving).
- **Reconnect after a crash** waits out the stale session's network timeout, because a duplicate
  login is refused rather than booting the live session. Refinements (a grace period, or
  detecting a dead session) are future work.


Looking good so far, great work.