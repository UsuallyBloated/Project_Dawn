# Corpse Epic, Slice 3 — Cleric / Paladin Resurrection — Playtest Checklist — 2026-06-25

> **RECONCILED (Phase 0, 2026-07-17) — this checklist is STALE; the work SHIPPED. Do not
> re-open it.** The `[-]` rows below (Cleric res rejected, no Accept/Decline prompt, higher tiers
> erroring) are the pre-reset run where the test Cleric was too low-level to afford the res
> spell's 100-300 mana — the "TEST-SETUP GOTCHA" this file itself warns about — so the cast was
> rejected server-side *before* the res logic ran. It was not a bug. A thorough two-client run
> on 2026-06-26 confirmed all FOUR tiers (Cleric 25/50/75% + Paladin Reclaim Soul 20%)
> end-to-end plus every guard and persistence; see `session_2026_06_25.md:72`
> ("PLAYTESTED + COMMITTED 2026-06-26"). Committed server `98728ea` / client `a04ed07`.

A Cleric (or Paladin) can resurrect a dead player's corpse: target the corpse, cast a Resurrection tier,
the dead player gets an **Accept/Decline** prompt, and on accept they're **summoned to their corpse** and
**refunded a % of the XP that death cost**. No res-sickness in v1. Wire is **PD_W0022**.

**The model:** you respawn immediately, naked, at your bind when you die. A res does NOT revive you from
death (you're already alive), it **summons you back to your corpse + refunds XP**, saving the corpse run.
You still loot your gear off the corpse afterward.

**Tiers (XP of that death refunded):** Cleric `Resurrection (Minor)` 25% / `Resurrection` 50% /
`Resurrection II` 75% instant; Paladin `Reclaim Soul` 20%.

> **TEST-SETUP GOTCHA (learned the hard way 2026-06-25):** the res spells cost **100-300 mana** with **min
> levels 20-45**, gated **server-side**. A low-level test Cleric can't afford / isn't allowed to cast them,
> the cast is rejected before the res logic runs (this looked like "the res is broken" but wasn't). Use the
> Test Panel **"Level Up"** button (one click = one full level, server-authoritative) to get the Cleric to
> **level 20+** (Minor), 30+ (Resurrection), 45 (Resurrection II). Make the DEAD player **level 5+** so the
> death actually costs XP (below 5 is a grace period → the refund is 0).

**Build prerequisites (all three):**
- Re-export / reload Project_Dawn, reload the Godot editor so the rebuilt `gdext_net.dll` (PD_W0022) loads.
- Restart the server: `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:/Projects/server`.
  Migration `0008_corpse_resurrection.sql` auto-applies (`lost_xp` + `resurrected` on `corpses`).
- Old PD_W0021 clients/servers refuse to talk. Capture: `... | Tee-Object server.log`.

Diagnostics (server.log): `resurrection cast received`, `resurrection offered`, `resurrection accepted`
(with `xp_percent` + `refund`), `resurrection rejected — ...` (with the reason). Two clients ideally (a
dead player + a Cleric); a Cleric reseing their OWN corpse also exercises the flow solo.

## Setup
- [x] Re-export client, reload editor (PD_W0022 DLL), restart server. notes:
- [x] A Cleric at **server-level 20+** (use "Level Up"), `Resurrection (Minor)` on the hotbar, ~100 mana.
  A second player (the one who dies) at **level 5+**. notes:

## 1 — Core resurrection flow
- [x] Player A (lvl 5+) dies and **loses a chunk of XP** (note the XP bar). A respawns naked at bind; a
  corpse is left where they fell. notes:
- [x] Player B (Cleric) walks to A's corpse, **left-clicks it to target** (target frame shows "A's
  corpse", no HP bar), and **casts Resurrection (Minor)**. notes: resurrection rejected
- [-] Player A gets an **Accept / Decline prompt** ("B offers to resurrect you. Return 25% ..."). notes: Player A does not get accept/decline prompt
- [-] A clicks **Accept** → A is **teleported to the corpse**, and the **XP is refunded** (watch A's XP
  bar jump back up ~25% of what was lost). notes:
- [x] A can then **loot their corpse** normally for gear. No res-sickness debuff appears (none in v1). notes: A can loot their corpse, but res was not cast on corpse.

## 2 — Tiers + Paladin
- [-] Higher Cleric tiers refund more (50% / 75%); `Resurrection II` is **instant cast**. (Needs a
  higher-level Cleric for the mana.) notes: Tested higher rank cleric res, receiving error message.
- [x] A **Paladin** with `Reclaim Soul` can also res (refunds ~20%). notes: Reclaim Soul succesfully worked.  returning XP, and character A was able to loot their body! WOOHOO!

## 3 — Decline + guards
- [x] **Decline** the offer → the prompt vanishes; nothing happens (no teleport, no refund). notes: Confirmed with Paladin's Reclaim Soul
- [x] **Double-res:** a second Resurrection on the **same corpse** is rejected ("That corpse has already
  been resurrected."). notes: Confirmed with Paladin's Reclaim Soul
- [x] **Offline owner:** res a corpse whose owner has logged out → "Their spirit is not present." notes: Confirmed with Paladin's Reclaim Soul
- [x] **Out of range:** cast from far away → "You are too far from the corpse." notes: Confirmed with Paladin's Reclaim Soul
- [x] **Class gate:** a non-Cleric/Paladin can't cast a Resurrection (not on their bar; server also
  rejects a forged cast). notes: This appears to work, but I havent built something to get around this barrier.

## 4 — Edge: zero-loss corpse
- [x] Die at **level < 5** (grace, no XP lost) → the corpse has 0 lost XP. A res on it still **summons** A
  to the corpse (refunds 0 XP). notes:

## 5 — Persistence
- [x] Res a corpse, then **restart the server** and relog → that corpse is **still marked resurrected** (a
  second res on it is rejected; no free re-refund). Boot log shows a fresh `loaded persisted corpses`. notes: Confirmed with Paladin's Reclaim Soul
- [x] A corpse that was NOT rezzed still rezzes fine after a restart (lost_xp survived). notes: Confirmed with Paladin's Reclaim Soul

## Notes / observations
- Smoke test 2026-06-25 (pre-reset) CONFIRMED server-side: cast → offer → accept → refund (2759 XP at
  25%), the teleport-to-corpse (eyeball confirmed), the grace-death 0-refund, and the double-res
  rejection. This pass is the thorough run.
- **To investigate (flagged by tester):** "players de-leveling to level 1 / lost XP not working." The
  death penalty FLOORS at level 5 (a death cannot drop you below 5), and the log shows char 81 de-levelling
  correctly (20 → 19 on a death). Likely (a) testing with a <5 char (grace = 0 loss, by design) and/or (b)
  a level-persistence / client-display issue separate from Slice 3 — note the before/after level if it
  recurs and we'll dig in.
-
- Can we temporarily change the cooldown of these res spells to 15 seconds?  waiting for each spell to cool down for this test is very time consuming.

Player corpse will eventually be a seven day counter to despawn.

After a player loots an empty corpse, the corpse should disapear.