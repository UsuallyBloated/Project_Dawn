# Session 2026-11-28: the vault in the cursor grammar

The user, asked what could be worked on unattended: "1 sounds good, go ahead." Option 1 was
the one decided thing not yet built: the three asks from the held-item sheet (2026-11-06),
decided on 11-09 with "FULL bags in the bank" and "all three ride the next bump".

Built on `feat/vault-grammar` in both repos, in new worktrees (`F:\Projects\server-vault`,
`F:\Projects\Project_Dawn-vault`), from the deploy tips (server `9a7c3ba`, client `e43af13`).
**Local commits only (server `127f11f`, client `b3b4223`): nothing merged, pushed, deployed or
exported.** The zip to send is still `ade04e1` and the R720 still runs `9a7c3ba`.

## What it does
- **Lift from the vault.** A left click on a vault item with an empty hand puts it on the
  cursor.
- **The cell you click is the cell you get.** A held stack goes into the empty vault slot
  clicked; onto the same item it merges up to the stack size and the rest stays in hand; onto a
  different item the two swap. The same law every pair of inventory slots follows.
- **Bags in the bank, with what they hold.** A bag rests in a vault slot with its contents; a
  right click on it opens a window on it; its inner slots take the same clicks, and the quick
  deposit fills them once the vault's own slots are taken (a banked bag's slots are the vault's
  room, EQ's model). Nothing in a vault is weighed. A bag never goes inside a banked bag.

## How (server, `feat/vault-grammar`)
- **`ItemVault` holds a bags map** keyed by vault slot, exactly as `PlayerInventory::bags` keys
  a carried bag's contents by its base slot and the held bag's by `CURSOR_BAG_KEY`. A vault
  knows which it is (`VaultKind::Personal` / `Shared`), so the NO DROP rule of the shared vault
  is the vault's own on every way in and no caller can forget it.
- **`ItemVault::cursor_move(inventory, cell, to_cursor)`** is the click: every refusal is
  decided before anything moves and what follows cannot fail, so there is no half of a swap.
  A cell is `VaultCell::Slot(k)` or `VaultCell::Inner(k, i)`. It returns what crossed
  (`banked`, `taken`, a bag first and then its contents) for the ledger rows, and the hand's
  coordinates to re-send.
- **The vault's placer** (`deposit`) follows the inventory's order: top up stacks in the
  vault's slots, then inside banked bags, then empty vault slots, then empty slots inside
  banked bags. `room_for` asks the same placer on a copy (the `can_accept` rule), replacing
  `capacity_for`, a second implementation that would have drifted.
- **A bag leaves a vault only by the hand.** The quick withdraw (`take`) and the quick deposit
  refuse a bag: they move a count, not a container.
- **Wire, `PD_W0032`:** `BankMoveItem { shared, vault_slot, inner_slot, to_cursor }` appended
  last; `BankWithdrawItem` gains a trailing `inner_slot`; `BankItemSnapshot` gains a trailing
  `bag_entries`. The DLL: `send_bank_move_item`, a third argument on
  `send_bank_withdraw_item`, four more arrays on `bank_item_snapshot`.
- **Migration `0020_bank_bag_contents.sql`:** both vault tables are rebuilt with a `bag_slot`
  column in the primary key (-1 for a vault slot, else the vault slot of the bag whose inner
  slot the row is). One table per vault, so the one transaction that writes a vault writes the
  bag and its contents together, and the ledger's conservation query counts them unchanged.
  Forward-only. Numbered 0020 because the hosting branch already holds 0018 and 0019; sqlx
  applies whatever is missing in any order (read in `sqlx-core 0.8.6`).
- **The step** (`tick/banking.rs`): the banker gate is one helper for the three item loops; a
  vault that changed is sent once at the end of the step, so a burst of clicks costs one
  snapshot; a refused click re-sends the hand and the vault, since an honest client only
  reaches a refusal with a stale view.

## How (client, `feat/vault-grammar`)
- `BankerManager` mirrors each vault's bags and owns the click rules (`click_cell`,
  `quick_withdraw`, `entering_refusal`): which request a click is, and the refusals said before
  anything is sent, with the server's lines.
- `bank_window.gd`: a left click is `click_cell`; a right click opens a banked bag or
  withdraws. `VaultBagWindow` (extends `BagWindow`, which now reads its cells through one
  overridable `_contents()`) is the window on a banked bag; it closes when its slot no longer
  holds a bag and with the bank.
- With the bank open, a right click on a carried BAG opens it (it used to try to deposit it,
  which the server refused, so a bag could not be opened at the bank at all).

## Exploit lens
- **A dupe through a half-finished swap:** none exists to fail. Validation first, then moves
  that cannot fail; the property test runs random clicks and moves between the bags, the hand
  and both vaults and holds the per-item totals, the vaults' soundness, and that a refused
  click changes nothing.
- **A crash:** both stores and the ledger rows are written in one transaction
  (`save_stores_atomic`); a bag's contents are rows of the same table as the bag.
- **NO DROP out through a bag:** the shared vault refuses a bag for what it carries, a NO DROP
  item into a bag banked there, and the placer refuses it too.
- **The death penalty:** every vault intent stands behind the banker gate and the dead gate
  (a whitelist, so a new message is refused while dead unless someone adds it).
- **A flood:** one snapshot per vault per tick however many clicks arrive. The per-connection
  intent budgets are on the hosting branch, whose exhaustive `intent_class` will not compile
  until `BankMoveItem` is placed in it.

## Found on the way
1. **A leftover empty "held bag" store could wipe a banked bag** (mine, found re-reading the
   move before the review, fixed before any commit). Destroying, dropping or selling an EMPTY
   bag from the hand left its empty contents store under the hand's key. The inventory's own
   moves tolerate that; the first cut of `cursor_move` carried the store along with whatever
   the hand held next, and placing a loaf into a banked bag's inner slot wrote the empty store
   over that bag's contents. Now a contents store travels with a bag and nothing else, a store
   is never written under an inner cell's slot, and `destroy_at` takes the empty store with the
   bag. The property test gained a step that plants the stale store; it and a unit test both
   fail on the first cut.
2. **The property test's first oracle was wrong, not the vault:** swapping two identical
   pouches moves both and changes nothing, so "the stores changed exactly when the move says
   so" failed on its first run. It now asserts the direction that matters (a change that is
   not reported would never be marked dirty, so never saved).
3. **Migration files and line endings (older than this build).** sqlx checksums a migration by
   its bytes. With `core.autocrlf` on, a Windows worktree checks the files out with CRLF, and
   the main server checkout holds 0013, 0015, 0016 and 0017 as CRLF today. A server built there
   refuses a database an LF build migrated ("migration 1 was previously applied but has been
   modified"), which is how the dry run first failed. The host builds on Linux and is not
   affected. The branch adds `.gitattributes` (`migrations/*.sql text eol=lf`) and a test,
   `every_migration_is_embedded_with_lf_line_endings`. **At the merge, each existing Windows
   checkout needs its `migrations/` files deleted and checked out again once**, or that test
   fails there (its message says so).
4. **The window geometry fixture was stale since the flight merge (11-25):** the Test Panel's
   Fly row and the two keybind rows were never recorded, so `probe_window_geometry.gd` has
   failed on the deploy branch since (it is not in `check_all.ps1`). Re-recorded on this
   branch, with the bank window's shorter hint.
5. **I deleted my own uncommitted migration file** while renormalizing line endings (`rm
   migrations/00*.sql` before a re-checkout) and rewrote it from the session's text; the new
   files are now `git add -N`'d. The dry run and the migration test ran on the rewritten file.

## The review pass (`/code-review`, high, on the server diff)
No dupe and no exploit found. Eight findings, each read in the source first:
- The lint job failed on one line of a new test (`nonminimal_bool`). Fixed.
- `.gitattributes` does not renormalize checkouts that already exist. True; item 3 above, and
  the guard test.
- **Two clicks inside one 50 ms tick are applied by kind, not in the order sent** (inventory
  moves, then the bank step: store, withdraw, vault clicks). True, and older than this build
  for the first two. Every click is still validated against what the server holds, so nothing
  is duplicated or lost; the result can differ from the order clicked. Recorded as a known
  limit; a per-connection sequence across the inventory steps is its own change.
- A refused click re-sent the hand but not a held bag's inner slots. Fixed: `resend_hand`
  sends the cursor and every inner slot of a held bag, filled or empty.
- **A double click showed a refusal line** (the second click lands on a cell the first has
  emptied). Fixed the way a refused `MoveItem` behaves: a click on a cell or a hand that is not
  as the client believed says nothing and re-sends the hand and the vault. Only the two rules
  about what may enter a vault are said ("A bag cannot go inside a bag.", the NO DROP line).
- The DLL clamped a negative vault slot to 0, so a missed lookup would have acted on the first
  slot. Fixed: no slot, no message, in both vault sends.
- `ItemVault::from_rows` dropped rows silently. Fixed: a `vault row dropped at load` warning
  per row, with why.
- The new world tests read the database after a fixed wait. Fixed: the first read after each
  save polls for the expected rows; the crash test waits for the drop's own save before it
  kills the world.

## Checks
- **Server** (`F:\Projects\server-vault`): 498 unit tests (481 before) and 207 world tests (201 before), two migration tests, the ledger, persistence and auth suites unchanged; `cargo fmt --check` and
  `cargo clippy --workspace --all-targets -- -D warnings` clean.
- **The property test at 30,000 cases:** random inventory moves and vault clicks (both vaults,
  vault slots and inner slots, lift and place) over inventories and vaults seeded with pouches
  that hold things and a NO DROP shirt; totals conserved, both vaults sound, a refused click
  changes nothing.
- **Fourteen planted faults, each caught** (thirteen by a script that plants one, runs the
  vault's unit and world tests, and restores the file; the stale store by hand): NO DROP in a
  held bag unchecked, a bag into a banked bag, a lifted bag leaving its contents behind, no
  banker gate, the quick withdraw taking a bag, the vault not marked dirty, a bag's contents
  not written to rows, the dead allowed to click, no ledger rows, NO RENT kept inside a banked
  bag, swapped bags keeping each other's contents, a merge ignoring the stack size, the placer
  putting NO DROP in the shared vault, the stale store.
- **The migration:** `migration_0020_keeps_every_vault_row_and_then_holds_a_bags_contents`
  upgrades a database migrated to 0017 with rows in both vaults, then saves and loads a bag's
  contents in each. Dry run: the vault server booted on a copy of the dev `world.db` (last
  migrated to 0011), applied 0013 to 0017 and 0020, and logged `ledger check mismatches=0`;
  all 24 vault rows came through identical.
- **Client** (`F:\Projects\Project_Dawn-vault`, with a DLL built from the server branch): all
  21 checks green against `-ServerRoot F:\Projects\server-vault`; every probe green
  (`probe_vault_grammar.gd` is new, 46 checks; `probe_held_item_bank_vendor.gd` follows the new
  click rule; the geometry fixture re-recorded); a headless boot with no script error.

## Calls made in the build, the user's to overrule
1. **A bag moves by hand only.** A right click on a banked bag OPENS it, and the quick deposit
   and quick withdraw refuse a bag ("Pick the bag up and place it in the vault by hand.",
   "Pick the bag up to take it out of the vault."). So no right-click path moves a container.
2. **With the bank open, a right click on a carried bag opens it** instead of trying to
   deposit it.
3. **A right click in the vault still withdraws while you hold something** (the 11-06 sheet's
   passed row), to the bags, never the hand.
4. **Stale clicks are corrected quietly** (item 5 of the review).
5. **Migration number 0020**, leaving the hosting branch's 0018 and 0019 alone.
6. **Not bundled:** the command confirmations and the three dead wire intents are not on this
   branch (the question went unanswered, so the smaller thing was built).

## To merge (a bump: both sides together, on a go)
1. Server: merge `feat/vault-grammar` into the deploy branch; in each Windows checkout, delete
   `migrations/*.sql` and `git checkout -- migrations/` once (item 3).
2. Client: merge `feat/vault-grammar`; `addons/gdext_net/build.ps1`; `check_all.ps1`; export.
   The tester README's bank lines want the new clicks.
3. The R720: everyone out, **back up `world.db` first** (migration 0020 is forward-only: an
   older binary refuses to boot on the migrated database), then the usual stop, copy, start;
   the boot line, then `ledger check mismatches=0`.
4. The hosting branch, at its merge-forward: place `BankMoveItem` in `intent_class` (it will
   not compile until then).
5. `vault_grammar_checklist.md` (on the client branch), one seat plus a second character on
   the same account.

## Not built
- A direct move between two vault cells (every move goes through the hand, as in the bags).
- Splitting a stack into the vault.
- A drag gesture.
- The two standalone vault writers in `db/mod.rs` (`save_bank_items`,
  `save_account_bank_items`) have no caller since every store is written together; they were
  kept and given the new column. Deletable on the user's word.
