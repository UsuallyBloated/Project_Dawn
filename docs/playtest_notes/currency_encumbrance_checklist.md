# Currency + Encumbrance Playtest Checklist — 2026-05-21

Four-tier coin (copper/silver/gold/platinum at 100:1) replaced the single coin count, end
to end: server wallet + wire + client stacks + vendor UI. Encumbrance v1 rides on it —
coins have weight, STR sets capacity, over-cap slows you and chokes stamina regen.

**Build prerequisites (both repos changed + a wire break):**
- Rebuild server: `cargo build` in `F:\Projects\server` (migration `0004` auto-applies to
  `world.db` on boot; existing characters keep their old balance as copper)
- The gdext DLL was rebuilt and copied to `addons/gdext_net/` already — **reload the Godot
  editor** (Project > Reload Current Project) so it picks up the new build
- Old client saves load fine (legacy `coins` lands as copper) — no save wipe needed

| Thing | Effect | Who/Where | Notes |
|---|---|---|---|
| Tiers | 100c = 1s, 100s = 1g, 100g = 1p | everywhere | four independent stacks, never auto-consolidated |
| Coin weight | 0.02/coin, **flat across tiers** | `Encumbrance` | 1000 coins = 20 weight |
| Capacity | `10 + STR` | `Encumbrance` | STR 10 char ⇒ 20 (= 1000 coins) |
| Speed penalty | linear past capacity, floor ×0.25 | `player.gd` | applies even mounted |
| Stamina regen | ×0.5 encumbered, ×0 at 2× capacity | `regen.gd` | HP/MP regen untouched |

Diagnostics: in-game console (F2/backtick) for client state; server greps:
`"BuyItem applied"`, `"SellItem applied"` (both now log `coins_after` as total copper).

## Setup
- [x] Re-export Project_Dawn (or reload editor) so the new DLL + autoloads load
- [x] Restart server
- [x] Client logged in (launcher mode), vendor reachable

**Added after first setup (Test Panel money buttons):** one more rebuild round —
- [x] Close Godot so the DLL copy can land, run `addons/gdext_net/build.ps1`, reopen
- [x] Restart server **with `PD_DEV_CMDS=1`** (PowerShell: `$env:PD_DEV_CMDS=1; cargo run
  --release -p projectdawn-server`) — the money buttons are dev-gated and silently
  ignored without it (wallet not moving after a grant = this gate, by design)

## 1 — Wallet display & legacy carry-over
- [x] **Log in with a pre-existing character** → old coin balance appears as raw copper
  (e.g. old 100 coins reads "100c", not "1s"). notes: Vendor window is the only location i see wallet.  am i missing it?
- [x] **Open vendor window** → wallet footer shows stacks in `Xp Xg Xs Xc` form, prices
  show reduced (e.g. "2s 50c" for a 250-copper item). notes:

## 2 — Buy: server make-change
- [x] **Buy an item cheaper than your copper stack** → copper decreases by exactly the
  price; silver/gold/platinum stacks untouched. notes:
- [x] **Buy an item costing more than your copper but affordable overall** (Test Panel →
  **Give 1p 5g 5s** for higher tiers) → one higher coin breaks into change; remaining
  lower stacks correct; wallet total drops by exactly the price. notes: I cant test this.  I gave myself too much money and i dont know how to drop it

- [x] **Try to buy with insufficient total** → "You don't have enough coins." and no
  server CoinsUpdate (grep: `BuyItem rejected — insufficient coins`). notes: I'm too rich.  what a problem.  We could use a way to drop money

## 3 — Sell: reduced payout on top of stacks
- [x] **Sell an item** → payout arrives reduced (e.g. 250c credit = +2s +50c), existing
  stacks not re-consolidated (your raw copper count stays raw). notes: I think so?

## 4 — Encumbrance
- [x] **Accumulate coins past capacity** (STR 10 ⇒ >1000 coins; Test Panel →
  **Give 1,000 Copper** twice) → "You are encumbered!" in chat log; movement
  visibly slower. notes:
- [x] **Keep stacking (≥2× capacity)** → speed near the 0.25 floor crawl; stamina stops
  regenerating. notes:
- [ ] **Drop back under capacity** (spend/sell so coin count < capacity) → "You are no
  longer encumbered."; speed and stamina regen back to normal. notes:
- [x] **Second client observes** → the encumbered player's avatar moves slowly for the
  remote viewer too (server integrates the scaled direction). notes:

## 5 — Regression: nearby behavior unchanged
- [x] Normal movement / mount speed with a light purse → unchanged. notes:
- [x] HP/MP regen while encumbered → unchanged (only stamina is gated). notes: isn't HP/MP regen disabled?
- [x] Inventory add/remove/stack, equip/unequip → unchanged. notes:
- [x] Save → quit → reload → wallet stacks identical (not re-reduced). notes: Wallet was empty after logging out then logging back in.

## Notes / observations
-Looking good.

---

## Round 2 — fixes from the first pass (2026-05-21, later)

Two findings fixed; needs **server rebuild + restart** (`PD_DEV_CMDS=1` again). Client:
only `test_panel.gd` changed — no DLL rebuild, no editor reload, just restart the game.

- **Wallet wipe on logout (row 5.4) — fixed.** Coins were never written back to the DB
  (write-once at character creation); every login re-seeded the wallet from the stale row.
  Now persisted on the 60 s checkpoint + a disconnect flush (server greps:
  `coin checkpoint failed`, `final coin save on disconnect failed` — absence is success).
- **"Too rich to test" — fixed.** Test Panel now has **Clear Money** (empties all four
  stacks, server-authoritative).

Re-test the rows the first round couldn't reach:
- [x] **Clear Money** → wallet drops to 0c everywhere; "You are no longer encumbered." if
  you were over capacity (covers old row 4.3). notes:
- [x] **Clear Money → buy attempt** → "You don't have enough coins." + server grep
  `BuyItem rejected — insufficient coins` (covers old row 2.3). notes:
- [x] **Give 1p 5g 5s → buy something > your copper** → higher coin breaks into change
  (covers old row 2.2). notes:
- [x] **Buy/sell/grant → log out → log back in** → wallet identical, per-tier (covers old
  row 5.4). notes:

Answers to first-round questions:
- *"Vendor window is the only wallet display?"* — Correct, for now. Wallet line in the
  inventory window + a weight readout are the noted UI follow-ups.
- *"Isn't HP/MP regen disabled?"* — No; the no-food-no-regen design is still a to-do. In
  launcher mode HP/MP regen ticks server-side (slow out of combat), so bars creep.
