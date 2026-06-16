# Group Loot Rights & Coin Drops Playtest Checklist — 2026-06-15

Coins now drop from mobs and corpses have loot rights: a kill belongs to the killer's
group, coin auto-distributes (or not) by mode, and Round Robin rotates item turns.
This verifies the whole feature two-client. **Design:** `docs/design/group_loot_and_coin.md`.

> **BUILD PREREQUISITE — this is a PD_W0014 wire break.** Both the **server** and the
> **client** must be rebuilt from the loot-rights commits, *and* the GDExtension DLL
> must be regenerated: `addons/gdext_net/build.ps1`. A mismatched client/server pair is
> rejected at connect with a clean version error (not corruption) — if you can't
> connect, you're running a stale half. Server run: `$env:PD_DEV_CMDS=1; cargo run -p
> projectdawn-server` (dev cmds only needed for the Test Panel money/spawn buttons; coin
> now drops on its own).

| Thing | Value / how | Notes |
|---|---|---|
| Coin by mob tier | wildlife **0** · low humanoid 5–50c · mid 50–300c (+occasional silver) · named 1–20s (+occ. gold) · boss 1–10g (+rare plat) | tier ≈ mob level; beasts (wolf/rat/bear/spider/snake/bat/boar) drop **none** |
| Coin split range | **30 m** from the corpse | members further out (e.g. back in town) get nothing |
| `/autosplit on\|off` | per-player; off = coin you loot stays with you | default **on** |
| `/loot rr\|ffa` | leader-only; bare `/loot` reports the mode | default **Round Robin**; shown in group panel header `[RR]`/`[FFA]` |
| Corpse coin | gold "Coins: …" row at the top of the loot window | informational; looting any item / Take All auto-credits it |

Diagnostics: in-game console (backtick or `/console`); `server.log` anchors to grep —
`"coin looted"`, `"loot rejected"`, `"group loot mode set"`, `"kill credit granted"`.
Wallet readout: inventory window line + character-window Weight row.

## Setup
- [x] Rebuild server (release) from the loot-rights commits; run with `PD_DEV_CMDS=1`.
- [x] Rebuild the gdext DLL (`addons/gdext_net/build.ps1`) and re-export/reload the client.
- [x] **Two** clients (A, B) logged in via launcher to the same shard/zone.
- [x] Pick a **humanoid** camp for coin (gnolls / bandits / skeletons). Wildlife is a
      coin-free control case.

> **Known gotcha:** wolves/rats/bears/etc. drop **0 coin by design** — don't read that
> as a bug. Kill humanoids/undead to see coin. And if A can't connect at all, the DLL
> wasn't rebuilt (stale PD_W0013).

## 1 — Solo coin drop + corpse display
- [x] **A (ungrouped) kills a humanoid** → a loot bag spawns. notes:
- [x] **A opens the corpse** → a gold "Coins: …" row sits above any item rows. notes:
- [x] **A clicks Take All (or any item)** → wallet rises by the shown coin; combat log /
      inventory wallet line updates. notes:
- [x] **A kills a wolf (wildlife)** → no coin row (items only, or an empty/quick bag). notes: Tested on "a plague rat", appears to work as intended.
- [x] **A re-opens a looted corpse** → coin row is gone (coin already taken). notes: Not sure how to accomplish this.  "Take All" must be clicked to remove the coin from the corpse, thus leaving the body with no items remaining.

## 2 — Ownership: strangers locked out (the security core)
- [x] **A kills a humanoid; B is NOT grouped with A.** B walks onto the corpse and tries
      to loot → B is refused with **"That isn't your loot."** in B's combat log; B gets
      no items, no coin. notes:
- [x] **A loots normally** → A gets it (ownership didn't block the owner). notes:
- [-] **A drops an item on the ground** (DropItem) → B *can* pick it up (dropped items
      are public, unchanged). notes: We haven't built the ability for a player to drop an item on the ground yet.

## 3 — Group coin auto-split by proximity (Round Robin default)
- [x] **A invites B; B accepts.** Group panel header shows `[RR]`. notes:
- [x] **Both within ~30 m, A kills a humanoid and loots** → the coin splits **evenly**
      between A and B (each wallet rises ~half; odd copper to the looter A). notes:
- [x] **B walks back to town / >30 m away, A kills + loots** → **only A** gets coin; B's
      wallet unchanged (B was out of range). notes:
- [x] **(If a 3rd+ member is available)** all-present kill splits N ways evenly. notes:
- [x] `server.log` shows `coin looted` with `recipients=` matching who was in range. notes:

## 4 — Per-player /autosplit
- [x] **A types `/autosplit off`** → log echoes "Auto-split loot: off". notes: When a group member changes the loot-status all group members should see the "Auto-split loot: off" message.
- [x] **A (autosplit off) loots a humanoid in the group, B nearby** → **A keeps all the
      coin**; B gets none. notes:
- [x] **A types `/autosplit on`, loots again** → coin splits with B again. notes:
- [x] **(Monk angle)** with the *looter's* autosplit off, a member who wants no coin
      simply isn't the looter and receives nothing — confirm coin concentrates on the
      looter. notes:

## 5 — Round Robin item turns (per corpse)
- [x] **RR mode, A & B grouped & nearby. A kills two humanoids.** First corpse: only the
      rotation's member may take items; the other gets **"Not your turn to loot."** notes:
- [x] **Second corpse goes to the other member** (the turn advanced). notes:
- [x] **The off-turn member's click pays out nothing** — no items AND no coin (the turn
      gate is checked before coin). notes:
- [x] **Coin still splits** to both nearby members when the rightful looter loots,
      regardless of whose item-turn it is. notes:

## 6 — Free-for-all (master looter)
- [x] **Leader sets `/loot ffa`** → log "Loot mode set to Free-for-all"; panel header
      flips to `[FFA]`; B sees the header change too. notes:
- [x] **In FFA, either member can loot any corpse's items** (no turn refusal). notes:
- [x] **In FFA, coin goes entirely to the looter** (the master looter pools it), not
      split. notes: Free for all should still follow the /autosplit settings, but group members can loot as frequently as they want.  This is helpful in areas where a groups members have no interest in the loot that is being dropped.
- [x] **Non-leader B types `/loot ffa`** → refused: "Only the group leader can set the
      loot mode." notes:

## 7 — Loot-mode visibility & control
- [x] **Bare `/loot`** → reports the current mode in the combat log. notes:
- [x] **Switching mode re-renders the group panel header for ALL members** (server
      re-fans the roster). notes:
- [x] **A new member who joins mid-session** sees the correct current mode in their
      panel immediately (roster carries it). notes:

## 8 — Regression: nothing nearby broke
- [x] **Group invite / accept / leave / kick / leadership pass** all still work; rosters
      update (now with the `[RR]`/`[FFA]` tag). notes: Leadership pass is not working.  When A right clicks on B in the group window, then selects "Pass Leadership", A no longer sees "GROUP (Leader)[RR]" and sees "GROUP [RR]" instead.  After Player A uses the "Pass Leadership" button on Player B, Player B does not see "GROUP (Leader)[RR]" and never recieves leadership.  If Player C leaves the group after Player A has passed the group to Player B, Player A becomes leader again upon Player C leaving the group.

- [x] **Solo (ungrouped) play**: kills are yours, coin all yours, items all yours. notes:
- [x] **Currency/encumbrance UI** unchanged: inventory wallet line, character Weight row,
      `/pvp` still works. notes: In regards to /pvp, this is not regression,  I noticed that when Player B attacks Player A, Player A does not see when Player B misses Player A.  Player A should see incoming misses, as it helps the player be more aware.
- [x] **Item loot itself** (picking up gear into bags) works as before. notes:
- [x] **Save → quit → reload** → coin balance persisted (server checkpoint). notes:

## Notes / observations
- Awesome work, we are making great progress.  Stay frosty.

---

## Round 2 — triage of the first pass (2026-06-15)

Whole feature passed two-client; coin drops, ownership lockout, 30 m split (incl. the
in-town exclusion), `/autosplit`, RR turns, FFA, mode visibility, reject messages, and
save/reload all verified. Findings:

**Fixed:**
- **FFA coin now follows `/autosplit`** (6.3) — loot *mode* governs only item turns; coin
  distribution is determined solely by the looter's `/autosplit` (split if on, looter
  keeps if off) in both RR and FFA. Master-looter = FFA + autosplit off. Server
  `a96d033`, design doc `397d93d`.
- **Pass Leadership** (8.1) — was local-only in launcher mode (no server handler); the
  next roster fan snapped leadership back. Now a server-authoritative `PassLeadership`
  handoff (validates current-leader → member, re-fans the roster). Server `381acc0`,
  client `10a0674`. *(Pre-existing bug, now load-bearing since leadership gates `/loot`.)*

**Deferred (logged, not yet built):**
- **`/autosplit` group visibility** (4.1) — when a member toggles autosplit, the whole
  group should see it (transparency about who's splitting). Needs a server→group notify;
  small enhancement, not yet built.
- **Incoming-miss visibility in PvP** (8.3) — a defender doesn't see when an attacker
  *misses* them. Separate PvP-feedback gap, unrelated to loot; logged for a PvP pass.

**Non-issues (working as intended):**
- **Re-open looted corpse** (1.5) — Take All empties the bag, which then despawns, so
  there's nothing to re-open. (Take a single item instead and the coin still auto-credits
  on that first loot; the awkward wording was mine.)
- **Drop item to ground** (2.3) — correctly untestable: no client "drop to ground" UI
  exists yet. The server already treats dropped bags as public for when it lands.
- **Plague rat = no coin** (1.4) — correct; rats are wildlife (0 coin by design).
