# Banker NPC — Slice 1 (coins) Playtest Checklist — 2026-06-17

The Banker is a town NPC offering **zero-weight coin storage** (deposit/withdraw) and
**tier exchange** (convert coin between tiers, free for this MVP). This is the relief valve
for the four-tier coin-weight system — bank your heavy copper and carry nothing.
**Design:** `docs/concepts/world/currency.md` → "Banking & Currency Exchange". Item storage
(incl. the 2 account-shared slots) is **slice 2** and is NOT in this build.

> **BUILD PREREQUISITE — this is a PD_W0015 wire bump.** Rebuild the gdext DLL
> (`addons/gdext_net/build.ps1`) **and** the server, or you're rejected at connect (clean
> version error). Run the server with `PD_DEV_CMDS=1` so the Test Panel money buttons work
> for seeding a wallet to bank: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server`.

| Thing | Value / how | Notes |
|---|---|---|
| Banker NPC | **Thalia Mourne** in the town hub (world.tscn, near the vendors) | teal capsule; same interact as a vendor |
| Open the bank | target the Banker + interact (the vendor/NPC interact key), within 6 m | opens the BankWindow |
| Deposit / Withdraw | enter per-tier amounts (P/G/S/C), click **Deposit →** / **← Withdraw** | moves coin between wallet and bank |
| Exchange | qty + From tier → To tier, click **Exchange** | 0% fee; up-conversions must be whole multiples (100c = 1s) |
| Bank weight | banked coin has **zero** weight on the player | the whole point — check encumbrance drops |

Diagnostics: in-game console (backtick / `/console`); the **server console** — the terminal
running `cargo run`; the server logs to stdout, **not a file** (pipe with
`... | Tee-Object server.log` to capture one). Anchors: `bank deposit`, `bank withdraw`,
`bank exchange`.
Wallet readout: inventory window line + the BankWindow's "Carried" row. Bank readout:
the BankWindow's "Bank" row.

## Setup
- [x] Rebuild server (`PD_DEV_CMDS=1`) **and** the gdext DLL from the PD_W0015 commits.
- [x] One client (A) logged in via launcher to the town zone. (Solo is fine for slice 1 —
  the bank is per-character; two clients only matter for slice 2's shared slots.)
- [x] Seed a wallet: Test Panel money buttons, or `/give`-style dev grant, so A has mixed coin.

## 1. Open + display
- [x] **Target Thalia and interact from within 6 m** → the BankWindow opens; "Carried" shows your wallet, "Bank" shows your current bank (0 on a fresh character). notes: When i target Thalia the target HUD does not show the correct name.  It appears to be showing the previous target I had selected.  If I target a Decrepit Skeleton, then click on Thalia Mourne's model, the target HUD still shows "Decrepit Skeleton".  If i target Brom, then target Thalia Mourne, the target HUD still shows "Brom - Provisioner".
- [x] **Interact from > 6 m away** → "You are too far away." (window does not open). notes:

## 2. Deposit / withdraw (the weight relief)
- [x] **Note your carried weight (character window WT row). Deposit a heavy copper stack (e.g. 5000c)** → wallet copper drops to 0, "Bank" shows 5000c, and **carried weight drops** (banked coin is weightless). notes:
- [x] **Withdraw 5000c** → it returns to the wallet, "Bank" → 0, weight rises again. notes:
- [x] **Deposit more than you hold (e.g. 999 platinum you don't have)** → rejected: "You don't have that coin to deposit." Nothing moves. notes:
- [x] **Withdraw from an empty/short bank** → rejected: "Your bank doesn't hold that coin." notes:
- [x] **Deposit with all four fields 0** → nothing happens (no-op, no error spam). notes:

## 3. Tier exchange (0% fee for MVP)
- [x] **Exchange 100 copper → Silver** → wallet loses 100 copper, gains 1 silver; total value unchanged. notes:
- [ ] **Exchange 150 copper → Silver (partial)** → wallet gets **1 silver and keeps 50 copper** (the whole-multiple part converts; the remainder stays). notes: implemented per this feedback 2026-06-18 (was a reject before) — please re-test to confirm. A truly-too-small amount (e.g. 50c → silver) still rejects "not enough … to make even one of the target".
- [x] **Exchange 1 silver → Copper** → wallet loses 1 silver, gains 100 copper (down-conversion always works). notes:
- [x] **Exchange a coin you don't have enough of** → rejected: "not enough of that coin to convert." notes:
- [ ] **Exchange with From == To** — set the *From* and *To* selectors to the **same** coin (e.g. Copper → Copper) and click Exchange → nothing happens (the client guards it; the server rejects "pick two different coin tiers"). notes: clarified 2026-06-18 — this test just confirms the same-tier guard does nothing.

## 4. Persistence
- [x] **Deposit some coin, then log out and back in** → the bank balance is intact (survives relog; the BankWindow shows it on next open). notes:
- [x] **Deposit, then immediately log out (no 60 s wait)** → still intact on return (the disconnect flush saves the bank, not just the periodic checkpoint). notes:

## Known scope (not bugs)
- **Item storage + the 2 account-shared slots** are slice 2 — the BankWindow is coins-only here.
- **Fees are 0%** for this MVP (free exchange + free banking); the currency.md fee bands
  (2–5% up / 0–1% down) land in a later pass.

Note: Your banking fees are making me think about player-owned towns and guilds being able to collect taxes from their towns.  I hadnt considered this until now.  Will you make note of this, and we will revisit this idea at a later date.