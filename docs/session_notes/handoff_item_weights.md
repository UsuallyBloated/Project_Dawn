# Handoff — Full Item-Weight Content Pass

You're picking up Project Dawn — Godot 4.4 / GDScript MMORPG client (this
repo), Rust authoritative server (`F:\Projects\server`). Read `CLAUDE.md`
first; it's the contract.

**This is a content session, not a systems session.** The encumbrance system
is built, playtested, and visible in the UI. What's missing is data: **149 of
169 items** in `data/loot/items/*.tres` still have the default `weight = 0`.
Your job is to propose a value for every one of them, **get the user's
sign-off on the actual numbers**, then apply. The user-in-the-loop part is
not optional — it's the reason this was split out of the 2026-06-12 session
instead of being finished there.

## What already exists (don't rebuild any of this)

- `Encumbrance` autoload: weight = coins (0.02/coin, flat across tiers) +
  inventory (`weight × count`, bags' contents included) + worn equipment.
  Capacity = `10 + STR`. Over capacity → movement slows (×0.25 floor);
  ≥ 2× capacity → stamina regen stops.
- Full visibility UI (2026-06-12, playtested green): wallet line in the
  inventory window, **Weight row in the character window** (yellow/red at the
  two thresholds), HUD encumbered/overloaded warning. You get live feedback
  for free — equip an item and the Weight row moves.
- **20 items already tagged** (2026-06-12 starter pass, playtested). These are
  your anchors — don't change them without asking:

| Band | Items (weight) |
|---|---|
| Weapons 2–8 | copper dagger 2, hunter's shortbow 3, iron short sword 4, carved staff 5, Bonecrusher's war axe 8 |
| Armor 1–10 | cloth cap 1, cloth robe 2, leather boots 2, leather vest 4, copper chain coif 4, iron chain leggings 8, iron chain vest 10 |
| Potions 0.3 | minor healing, healing, mana |
| Reagents 0.1 | bat wing, bone fragment, spiderling silk |
| Food/drink | bread loaf 0.3, water flask 0.5 |

- Catalog shape (by `ItemData.Type`): WEAPON 13 (8 untagged), CONSUMABLE 16
  (11 untagged), armor slots HEAD/CHEST/LEGS/FEET/HANDS/NECK ~29 (22
  untagged), RING 8 (all untagged), BAG 1, and the big one: **MISC 102 (99
  untagged)** — ores, ingots, hides, threads, herbs, gems, tools, quest
  tokens, cooking ingredients.

## Repos at handoff

| Repo | Path | Branch | State |
|---|---|---|---|
| Game client | `F:\Projects\Project_Dawn\` | `feature/ally-buff-routing` | 4 commits landed 2026-06-12 (visibility UI + playtest fixes), **plus uncommitted lore docs — see gotchas** |
| Server | `F:\Projects\server\` | `feature/ally-buff-routing` | untouched by this work; **stays untouched** |

No git remotes — local-only repos. Run `git -C <each> log --oneline -10` and
`git status` before touching anything.

## Read these in order

1. `CLAUDE.md` — conventions.
2. `autoloads/encumbrance.gd` — the consumer of every number you'll write.
   Note `COIN_WEIGHT`, `BASE_CAPACITY`, the penalty constants.
3. `docs/concepts/world/currency.md` — coin weight is the *designed* pressure;
   item weights must not drown it out.
4. `docs/session_notes/session_2026_06_12.md` — how the starter 20 were chosen.
5. `docs/playtest_notes/currency_ui_checklist.md` — what the UI shows and how
   it was verified.

## The process (phases are gates — don't skip ahead)

### Phase 1 — Audit tool

Write `tools/item_weight_audit.gd` (headless script, model it on
`tools/currency_smoke.gd`): loads every `.tres` under `data/loot/items/`,
prints one markdown table row per item — `| name | type | stack_size |
vendor_price | current weight |` — sorted by type then name, plus a summary
line (`N items, M untagged`). This is both your proposal generator and your
final coverage check. Commit it; it's a keeper.

### Phase 2 — Proposal doc → USER SIGN-OFF (the gate)

Create `docs/design/item_weight_proposal.md`: the audit table with a
**proposed weight** column filled in for all 149, grouped by category with a
one-line rationale per category band. Then **stop and hand it to the user**,
the same way playtest checklists work — the user edits numbers in place and
tells you when it's approved. Apply *exactly* what the approved doc says,
including anything they changed.

Suggested bands to seed the proposal (these are starting points, not
decisions):

- **Ore 3.0 / ingots 1.5 / coal 1.0** — ore heavier than ingot rewards
  smelting at a field station before hauling home (fits the SWG-style
  crafting philosophy). A STR-10 miner fills up at ~6 ore; that's the
  emergent-gameplay pressure working, but confirm the user wants it this
  sharp.
- **Hides/pelts 0.5–1.0**, thick leather slab 1.5; threads/silk/cloth scraps
  0.1.
- **Herbs/alchemy reagents 0.1** (matches anchors); essences 0.1; venom sacs
  0.2.
- **Rough gems 0.2; rings/jewelry 0.1**; wire/settings 0.1.
- **Tools**: pickaxe 5, smithing hammer 4, skinning knife 1, sewing needle
  0.1, tinkering kit 2.
- **Food/cooking ingredients 0.2–0.5** (anchors: bread 0.3, flask 0.5);
  ale/mead 0.5 (liquid); raw meats 0.5; flour/salt/grain sacks 0.5.
- **Remaining weapons**: match the anchor scale by class — junk variants
  (bent dagger, cracked club, rusty sword, splintered staff) weigh the same
  as their clean versions; metal junk doesn't get lighter by being bad.
- **Remaining armor**: interpolate the anchors by material (cloth 1–2,
  leather 2–4, chain 4–10) and slot (gloves/boots light, chest heaviest).
- **Misc/quest tokens** (seals, fangs, femurs): 0.1–0.5.
- **Bag (small pouch) 0.5**; mount whistle 0.5; arrow bundle 1.0,
  arrowheads/fletching 0.1; empty bottles/vials 0.1.

**Open questions to put to the user at the top of the proposal** (don't
decide these unilaterally):

1. **Worn-gear budget.** On starter values, a full iron-chain kit will run
   ~30 weight against a fresh STR-10 capacity of 20 — heavy armor on a
   low-STR character encumbers them standing still. EQ-authentic (STR
   matters, plate classes roll STR), but is that the intent, or should armor
   scale down / capacity scale up?
2. **Refining direction.** Confirm ore > ingot (field-smelting reward) or
   equal weights.
3. **Zero-weight allowlist.** Universal minimum 0.1, or do some items
   (feather? quest tokens?) stay 0? If 0 is allowed, list every such item
   explicitly in the proposal.
4. **Stack pressure.** Stacks multiply: 20 × 0.1 reagents = 2.0; a 20-stack
   of 3.0 ore = 60 (triple a fresh capacity). Sanity-check the worst stacks
   in the proposal table.

### Phase 3 — Apply

Mechanical: append `weight = X.X` to each `[resource]` block (same line
position as the tagged 20 — after `vendor_price` where present). One decimal
place. No other `.tres` edits ride along.

### Phase 4 — Verify

- Re-run the audit tool → `0 untagged` (minus any approved zero-list, which
  it should report by name).
- `godot --headless --path . --quit` → no SCRIPT ERROR / resource-load
  errors. (Known pre-existing: `time_of_day.gd:44` null `add_child` in
  `--script` mode only — ignore it.)
- `tools/currency_smoke.gd` still passes (`CURRENCY_SMOKE_PASS`).
- Author a short playtest checklist from
  `docs/playtest_notes/TEMPLATE_checklist.md` — spot-check a heavy haul (ore
  run), a full armor kit, a potion/reagent bag, and the regression rows from
  `currency_ui_checklist.md` §5.

## Acceptance

- Every item's weight matches the **user-approved** proposal doc exactly.
- Audit tool committed and reporting full coverage.
- Headless boot + currency smoke clean.
- Playtest checklist authored and handed over.
- Session note + `docs/session_notes/README.md` row; update the Encumbrance
  entry in `docs/concepts/architecture/systems_overview.md` (it currently
  says "~20 representative items tagged … full pass pending" — make that
  sentence false, then fix it).

## Gotchas (earned the hard way)

- **Weight is client-only.** It is NOT in `tools/export_items.gd`'s
  `FIELD_MAP`, so the server's `items.toml` doesn't carry it — **no toml
  regen, no DLL rebuild, no server rebuild, no server restart.** If you find
  yourself in `F:\Projects\server\`, you've wandered off-task.
- **Uncommitted lore docs in the client worktree** (atlas map files,
  `vrekka_and_threkka.md`, a `session_2026_06_11.md` + README hunk). They
  belong to another session. Do not absorb them into your commits — stage
  your files explicitly, and if you must edit `docs/session_notes/README.md`
  (you will, for the index row), check `git diff` for a pre-existing hunk in
  it and keep that hunk out of your staged change.
- **Concurrent sessions are real here.** Check `git status` before AND after
  long gaps.
- **Don't touch the two `Coins` mirrors** (`autoloads/currency.gd` /
  server `protocol/world.rs`) or `COIN_WEIGHT` — coin weight is settled
  design, out of scope.
- **Tabs, not spaces** in GDScript; follow `tools/currency_smoke.gd` style
  for the audit tool.
- The in-game debug console is backtick (or `/console`) — `F2` is "target
  group member 1" now.

## Out of scope (the backlog after this, ranked — don't start without asking)

1. Moneychanger NPC (town baseline-floor exchange; fee bands specced in
   currency.md).
2. Bank NPC (deposit/withdraw, zero-weight storage).
3. Citizen-class trade-window exchange mode (blocked on the class).
4. Coin loot drops (the economy's faucet).
