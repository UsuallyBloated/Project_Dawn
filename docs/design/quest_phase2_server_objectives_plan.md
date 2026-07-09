# Quest Phase 2: Server-Side Objective Tracking (build-ready plan)

**Written 2026-07-08 for handoff to a fresh Claude session.** Everything you need is in this file plus
the pointers below. Read `CLAUDE.md` (repo root) first; it has the working conventions.

## Context for a fresh session (do not skip)

- **Two repos:** Godot 4.4 client at `f:\Projects\Project_Dawn` (GDScript only), Rust authoritative
  server at `F:\Projects\server` (toolchain 1.95.0). Work branch in both: `fix/xp-leveling-overflow`.
  LOCAL git only, do not push/pull/fetch any remote.
- **Wire protocol is PD_W0023** (`crates/protocol/src/world.rs`, `WORLD_PROTOCOL_ID`). Bincode encodes
  enums POSITIONALLY: new variants and struct fields go at the very END of their enum, never mid-enum.
  Any wire change bumps the id (next: PD_W0024, ASCII `0x5044_5f57_3030_3234`) and requires rebuilding
  the client bridge DLL: `addons/gdext_net/build.ps1` from the client repo, then reload the Godot editor.
- **Server run (playtest):** `$env:PD_DEV_CMDS=1; cargo run -p projectdawn-server` from `F:\Projects\server`,
  piped `| Tee-Object server.log`. That log is UTF-16: read it with a proper file-search tool, raw
  `grep`/`Select-String` byte tricks return garbage or empty.
- **Tests:** `cargo test -p projectdawn-server --lib` (fast, ~160 tests). The `world_two_clients`
  integration suite is timing-flaky in parallel runs; re-run failures individually before blaming your
  change (`server/docs/flaky_integration_tests.md`).
- **Workflow:** build, run an adversarial review pass, author a playtest checklist from
  `docs/playtest_notes/TEMPLATE_checklist.md`, then STOP: the user playtests before anything is
  committed. Commits: one server + one client, never include `.claude/*` or
  `docs/playtest_notes/banker_slice2_checklist.md`. End commit messages with
  `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- **The user's standing directive:** be vigilant about player-exploitable holes; dev tools (Test Panel,
  PD_DEV_CMDS) are intentional and stay.

## What already exists (phase 1, committed 2026-07-08, server `ff9e156` / client `d943cb6`)

- **Kill credit online:** the server sends a private `ServerWorldMsg::KillCredit { mob_name }` to
  whoever earned a kill (solo killer, pet owner, or each grouped member on the XP split, via the
  `award_kill` helper in `world/tick.rs`). Client: `net.gd` feeds it to `QuestManager.notify_kill`,
  which advances "kill N X" objectives by bidirectional substring match (`quest_manager.gd:52`).
- **Server-authoritative rewards:** the client sends `ClientWorldMsg::CompleteQuest { quest_id }`
  (snake_case ids only). The server looks the id up in `crates/projectdawn-server/data/quests.toml`
  (5 quests: id, level_req, reward_tier), computes XP itself in `world/quests.rs`
  (tier fraction x cubic band at level_req; tiers trivial .15 / standard .30 / hard .50 / named .80),
  enforces `level_req`, and records the completion in the `completed_quests` table (migration 0009)
  BEFORE paying. A quest pays once per character, ever. `GrantQuestXp` is dev-gated (Test Panel).
- **Client data:** `data/quest_definitions.gd` (ids, objectives, item_rewards, giver/turn-in NPC,
  REWARD_TIERS). `quests.toml` is its server mirror; the lockstep rule is the same as
  `spell_definitions.gd` vs `spells.toml`: edit both in the same commit.

## What phase 2 must fix (all one root cause: objective STATE lives only in client memory)

1. **The quest journal wipes on logout.** `QuestManager._quests` is in-memory; launcher mode has no
   save path for it. Players lose active quests and their kill counts on every relog.
2. **The completed set is invisible to the client.** A relogged player can re-accept a done quest,
   redo it, and get silently zero XP (the server rejects with only a log line). Confusing and rude.
3. **Item rewards are Test-Room-only.** Client-side grants were ghost items online, so they are gated
   off in `quest_manager.gd`. Online quests currently pay XP only.
4. **Kill quests auto-complete in the field** the moment the last kill lands
   (`notify_kill` calls `complete_quest`); the designed `turn_in_npc` dialogue is decorative.
   Classic EQ requires returning to the giver. DESIGN FORK, see below.
5. **No abandon-quest button** (the journal UI has no way to drop a quest; blocked re-testing too).
6. **Brom's quest dialogue is unwired**: `rat_infestation` and `gnoll_raiders` are unreachable via
   NPCs (Brom is vendor-only in `data/dialogue_definitions.gd`).
7. **Residual exploit from the phase-1 review (accepted, now closable):** the server never verifies
   objectives were performed. A forged `CompleteQuest` for every known id a character qualifies for
   pays out with zero gameplay (bounded to ~6.4k XP once-ever by the level_req guard). Server-side
   progress tracking closes it completely.

## Design

Move quest STATE to the server; the client becomes a renderer. The server already generates the one
event that matters (its own kill events drive `KillCredit`), so it can count kills itself.

**Server data:** extend `quests.toml` per quest with objectives:

```toml
[[quest]]
id = "wolf_threat"
level_req = 1
reward_tier = "standard"
objectives = [ { kind = "kill", target = "Wolf", count = 5 } ]
# item_rewards = ["res://data/loot/items/tarnished_silver_ring.tres"]   # slice B
```

Matching rule must mirror the client's bidirectional substring match (lowercased contains in either
direction) or the two sides will disagree about whether "Grey Wolf" ticks "Wolf". Port it exactly and
anchor-test it.

**Server state:** `active_quests` table (migration 0010):
`char_id INTEGER, quest_id TEXT, progress TEXT (JSON array of ints, one per objective), PRIMARY KEY (char_id, quest_id)`.
Loaded with the character (extend `db::load_character` and `CharacterSpawn`, then
`PerConnection.active_quests: HashMap<String, Vec<i32>>`; the `completed_quests` HashSet already
exists on the connection). Persist progress on change (either immediately per increment, or fold into
the periodic checkpoint in `world/persistence.rs`; immediate is simpler and quest kills are rare).

**Wire (append-only, bump to PD_W0024):**
- `ClientWorldMsg::AcceptQuest { quest_id }` (validate: known id, level_req met, not active, not completed)
- `ClientWorldMsg::AbandonQuest { quest_id }` (drops active + progress; completed stays forever)
- `ServerWorldMsg::QuestSnapshot { active: Vec<(String, Vec<i32>)>, completed: Vec<String> }`
  (sent on EnterWorld; the client seeds its journal from it, which FIXES the logout wipe)
- `ServerWorldMsg::QuestProgress { quest_id, objective_index: u32, count: i32 }`
  (private, on each increment)
- `ServerWorldMsg::QuestRejected { quest_id, reason: String }` (accept/turn-in feedback; the client
  prints it to CombatLog, which fixes the silent zero-XP redo)

**Progress flow:** in `award_kill` (tick.rs), where `send_kill_credit` fires per member, ALSO run the
server-side objective increment for that member's active quests and fan `QuestProgress`. Keep sending
`KillCredit` during migration or retire it: recommended is to RETIRE the client-side counting once
`QuestProgress` drives the journal (one source of truth; `notify_kill` becomes Test-Room-only). Note
`KillCredit` stays in the enum (wire ids are append-only), just stops being load-bearing online.

**Turn-in flow:** `CompleteQuest` gains a server-side objective check: every objective count met, else
`QuestRejected("objectives incomplete")`. This closes exploit item 7.

### DESIGN FORK for the user (ask before building slice C)

**NPC turn-in gating.** Option 1 (classic EQ, recommended): quests complete only at the `turn_in_npc`
dialogue; killing the last wolf marks the quest "ready to turn in" in the journal and the reward
lands at the NPC. Option 2 (current behavior): auto-complete in the field. If option 1: the dialogue
action triggers `CompleteQuest`; the client blocks field auto-complete for quests that declare a
`turn_in_npc`; the server does NOT need to know which NPC (proximity/NPC validation can come with the
faction system later; the objective check already prevents early completion).

## Slices (each: build, review, checklist, user playtest, commit)

- **Slice A: server quest state.** quests.toml objectives + parser + matching tests; migration 0010;
  accept/abandon/snapshot/progress wire; `award_kill` increments; `CompleteQuest` objective check;
  client journal seeded from `QuestSnapshot` (persistent journal), progress from `QuestProgress`,
  rejections to CombatLog; QuestManager keeps the local path for Test Room. This alone fixes items
  1, 2, 7 and delivers the abandon plumbing.
- **Slice B: item rewards, server-granted.** Author the 3 reward items as `.tres` under
  `data/loot/items/` (Tarnished Silver Ring, Scout's Leather Boots, Hunter's Medal; stats are in
  `quest_definitions.gd`), register in the server item registry (`items.toml`; see how loot `.tres`
  paths are registered), add `item_rewards` paths to quests.toml, grant via the existing inventory
  machinery + delta fan on completion. Decide the full-inventory case: recommended is to reject the
  turn-in with `QuestRejected("inventory full")` rather than dropping or ghosting the item.
- **Slice C: turn-in gating + abandon UI.** Whichever fork the user picks; abandon button in the
  quest journal window; "ready to turn in" journal state if option 1.
- **Slice D: Brom's dialogue (client content only).** Wire `rat_infestation` + `gnoll_raiders` into
  `data/dialogue_definitions.gd` following `wolf_threat`/Aldric as the pattern.

## Exploit checklist for the review pass

Forged AcceptQuest spam (cap actives, e.g. 20); AbandonQuest then re-accept to reset progress (fine,
progress resets, completion record still blocks double pay); progress forging (impossible: server
counts); turn-in with incomplete objectives (rejected); item-reward duping via full-inventory retries
(grant must be idempotent per completion record); snapshot size (small); quest_id charset already
enforced in the handler (keep for new messages).

## Definition of done

Journal + progress survive relog and server restart; a redo attempt gets a visible rejection line;
item rewards arrive server-granted and survive relog; forged CompleteQuest without kills pays nothing;
155+ lib tests still green plus new quest-state tests; two-client playtest checklist filled clean.
