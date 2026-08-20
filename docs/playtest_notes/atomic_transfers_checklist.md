# Atomic Store Transfers Playtest Checklist — 2026-08-20

Verifies that moving items or coin between stores cannot half-happen. Closes exploit-audit
finding 8 ("cross-store transfers persist as separate txns").

**Build prerequisite: server only.** Push, then on the R720 pull, `cargo build --release`, stop,
`cp`, start, and confirm the boot line. No client change, no re-export.

**What was wrong.** An item never simply changes; it *moves*, and every move spans two tables:

| Action | Stores touched |
|---|---|
| Bank item deposit / withdraw | `character_items` + `bank_items` (or `account_bank_items`) |
| Bank coin deposit / withdraw | wallet columns + bank columns |
| Vendor buy / sell | `character_items` + wallet |
| **Death** | `character_items` + wallet + `corpses` |

Each store was written by its own function opening its own transaction, with an `.await` between
them. A crash landing in that gap either **loses** the item (gone from inventory, never arrived) or
**duplicates** it (arrived and still in inventory). Now every store for a connection is written in
one transaction (`db::save_stores_atomic`), in both the periodic checkpoint and the disconnect
flush; and death creates the corpse **and** strips the owner inside a single transaction.

This is not something a playtest can trigger on purpose — it needs a crash at a precise moment.
The rows below confirm the rewrite did not break the ordinary paths, which is the actual risk of a
change like this. Correctness under crash is covered by the unit test
`save_corpse_strips_the_owner_in_the_same_transaction`.

Diagnostics: `journalctl -u projectdawn -f`; watch for `store checkpoint failed` or
`final store save on disconnect failed`, which should never appear.

---

## 1 — Bank, the main cross-store path

- [ ] **Deposit several items, withdraw some back, close and reopen the bank** → all correct.
      notes:
- [ ] **Deposit and withdraw coin across tiers** → wallet and bank both correct. notes:
- [ ] **Deposit to the SHARED vault, then log in as another character on the account** → the
      shared item is there and the personal vault is that character's own. notes:
- [ ] **Bank something, then log out immediately** (inside 60 s, before the next checkpoint) →
      log back in and it is still banked. This exercises the disconnect flush, which was rewritten.
      notes:

## 2 — Vendor

- [ ] **Buy a few items** → items arrive, coin decreases correctly. notes:
- [ ] **Sell a few items** → items leave, coin increases correctly. notes:
- [ ] **Sell something then log out immediately** → coin total survives the relog. notes:

## 3 — Death, which now strips inside the corpse transaction

- [ ] **Die with gear AND coin on you** → corpse holds both; you respawn naked with an empty
      wallet. notes:
- [ ] **Loot your own corpse** → everything comes back, gear and coin. notes:
- [ ] **Die, then log out before looting; log back in** → the corpse is still there with its
      contents, and you are still empty. Neither side duplicated. notes:
- [ ] `server.log` shows `corpse created` with the expected `item_stacks`. notes:

## 4 — Regression: ordinary inventory work

- [ ] **Move items around, equip and unequip, use consumables** → unchanged. notes:
- [ ] **Loot a mob, pick up a dropped item** → unchanged. notes:
- [ ] **Play for a few minutes, then relog** → everything is where you left it. notes:
- [ ] **No `store checkpoint failed` or `final store save on disconnect failed`** anywhere in the
      log. notes:

---

## Result

- Server build (`build=` on the boot line):
- Overall:
