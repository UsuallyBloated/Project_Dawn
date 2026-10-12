# Full Bags Move With Their Contents — 2026-09-27

The 2026-09-17 scope: the cursor may hold a non-empty bag, bag-in-bag stays
banned. Server `fd39b99` + client `8f27abb`. **Both sides ride the next
redeploy + export together** (no protocol bump; an old client against the new
server just keeps its old refusal UX).

---

## 1 — The moves law, now with cargo

- [x] **Left-click a bag with items in it** → it lifts onto the cursor, no
      "Empty the bag" refusal, and the weight readout does NOT dip while held. notes:
- [x] **Place it in a different base slot, right-click open** → same contents,
      same slots, nothing reordered or missing. notes:
- [x] **Drop the held full bag directly onto ANOTHER full bag** → they swap, and
      each bag keeps ITS OWN contents (open both to verify). notes: Are they swapping places or swapping contents?  Swapping places is good.
      **Answer (2026-10-09): places.** The server's record of a bag's contents follows the bag,
      so each keeps its own.
- [x] **Move a full bag base-to-base by lift-and-place across the row** → contents
      follow every hop. notes:

## 2 — The sharp edges (each must refuse)

- [x] **World-click (drop) or Trash the held FULL bag** → refused with "bag must
      be emptied first"; the bag stays in hand, contents intact. notes:
- [x] **Sell a full bag to a vendor** → still refused ("Empty the bag before
      selling it.") — regression row. notes:
- [x] **With base slots full and a full bag in hand, loot a kill / buy from a
      vendor** → nothing lands INSIDE the held bag (grants go to other carried
      bags or refund to the loot bag). notes:

## 3 — Persistence and death

- [x] **Log out holding a full bag, log back in** → the bag is back in hand;
      place it and open it — contents intact (bag_255 rows round-trip). notes:
- [x] **Die holding a full bag, corpse-run** → the corpse holds the bag AND every
      item that was inside it; after looting, nothing is duplicated and nothing
      is missing (the extended clear_all coverage; regression test
      `death_strips_a_held_bag_and_its_contents` pins the server side). notes:

---

## Result

- Server build (boot line): `d593609`
- Client build (`/version`): the 10-05 export (`fc880df`)
- Overall: **PASS, all nine rows (2026-10-09).** Log: lift at 19:11:40, relog, place from the
  cursor at 19:12:06; lift at 19:12:16, death at 19:13:23 with `item_stacks=18`, corpse looted
  empty at 19:14:47; `SellItem rejected — bag has contents`; two bag-in-bag refusals.
