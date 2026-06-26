# Corpse Epic — Slice 3: Cleric Resurrection — Build-Ready Plan

> **For a fresh Claude session.** Self-contained. The deep background lives in
> `docs/design/corpse_and_resurrection_plan.md` (the epic master plan); this doc is the build-ready
> Slice 3. Every file:line pointer below was re-read and verified against the real source on
> 2026-06-24 (the codebase moved a lot since the master plan was written — trust this doc's pointers
> over the master plan's where they differ).

---

## 0. Current state (what is already shipped)

All prior corpse-epic work is **committed and playtested** on branch `feature/ally-buff-routing`:

| Slice | What | Commits (server / client) |
|---|---|---|
| 0 | Server-authoritative XP + leveling + 5%-of-band death penalty (de-level cascade, grace + floor at lvl 5) | `fd8e957` / `581db42` |
| 1 | Persisted corpse entity (corpse run): gear+coin onto a corpse, naked respawn, harsh decay | `ed35f9b` / `fdbc4c6` |
| 2 | Loot your own corpse (owner-only, atomic `apply_corpse_loot`) | `403ed9d` / `286e2a4` |
| — | Monster orb → corpse (slain creatures leave a named body, not a golden orb) | `543d884` / `6e593e7` |

**The wire is at `PD_W0021`** (verified: `crates/protocol/src/world.rs:72`,
`WORLD_PROTOCOL_ID = 0x5044_5f57_3030_3231`). Slice 3 bumps it to **`PD_W0022`**.

Two server repos: client = `f:/Projects/Project_Dawn` (Godot 4.4, GDScript), server =
`F:/Projects/server` (Rust). The wire crate `protocol` is shared; the client bridges it via the
`gdext_net` GDExtension (`crates/gdext-net`), whose `.dll` must be **rebuilt** after any protocol/gdext
change via `addons/gdext_net/build.ps1` (client repo). Run server tests from `F:/Projects/server`
with `cargo test -p projectdawn-server --lib`. Run the client headless boot check with
`& "F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --editor --quit --path f:\Projects\Project_Dawn`.

---

## 1. The locked design (do not re-litigate)

From the epic master plan, section 1 + the cleric class doc:

- A **Cleric** spell targets a **corpse**, returns the dead player to it, refunds a **percentage of THAT
  death's LOST xp** (EQ semantics — % of what was lost, NOT % of total xp), and applies a short
  **res-sickness** debuff.
- **Three Cleric tiers**, keyed to the **Restoration** casting skill:
  `Resurrection (Minor)` (req 80, **25%**), `Resurrection` (req 100, **50%**),
  `Resurrection II` (req 130, **75%, instant cast**).
- **Plus one weaker Paladin tier** (decided 2026-06-25): ~20-25% XP, higher level / longer cast, on the
  Paladin's own HOLY casting skill (see decision 7.3). Necro/others later.

### The conceptual adaptation (read this — it's the crux)

In classic EQ you stay a **corpse** and wait for a res (or release to bind). Project Dawn's shipped
death model instead **respawns you immediately, naked, at your bind**, and leaves a lootable corpse
where you fell. So in this model a resurrection is **not a revive-from-dead** (you are already alive) —
it is a **summon-back-to-your-corpse + XP refund + res-sickness** that *saves the corpse run*. The dead
player is alive at bind; the Cleric's res yanks them back to their body and gives the lost XP back. This
is exactly what the master plan's section 6 specifies ("summon the living, naked player back to their
corpse and refund the XP"). Build to this model. (A more authentic "stay dead and choose release vs.
wait-for-res" model is a much bigger change to the death/respawn flow — see Open Decisions, it is NOT
in v1.)

### The res flow (v1)

1. Cleric (Restoration req met) selects a **corpse** as the cast target and casts a Resurrection tier.
2. Server validates: spell is a res tier; target id resolves to a corpse; the corpse **owner is
   in-world** (online); caster in range; corpse **not already resurrected**. Invalid → a cast-fail
   message to the caster.
3. Valid → server sends a **`ResurrectOffer`** privately to the corpse owner:
   `{ corpse_id, caster_name, xp_percent }`. The client shows an accept/decline prompt.
4. Owner accepts → client sends **`ResurrectAccept { corpse_id, accept: true }`**.
5. Server on accept (re-validate first):
   - **Teleport** the living owner to `corpse.pos` (net-new — set `conn.pos` + fan a position/teleport
     message).
   - **Refund** XP: `progression::award_xp(server, conn, +round(corpse.lost_xp * pct))`.
   - **Mark the corpse resurrected** so it can't be re-rezzed (anti-exploit; persisted).
   - *(No res-sickness in v1 — decided 2026-06-25.)*
   - Gear is **NOT** auto-returned. The corpse persists; the player loots it normally via the Slice 2
     path (and the future right-click-re-equip, see `[[project-corpse-auto-reequip]]`).
6. Decline / no owner / timeout → nothing happens (the cast was spent).

---

## 2. The central gap: the lost XP is not stored anywhere (VERIFIED)

To refund "X% of that death's lost xp," the server must remember how much that death cost. **It does
not today.** `apply_death_penalty` (`crates/projectdawn-server/src/world/progression.rs:71-80`)
computes `let loss = (conn.xp_to_next as f32 * DEATH_XP_LOSS_FRACTION).floor() as i32;` and passes
`-loss` straight into `award_xp`, then **discards `loss`**. There is no `lost_xp` on `PerConnection`,
the `Corpse` struct, or the `corpses` table (verified by read + grep).

So Slice 3 must capture the loss at death and carry it onto the corpse:

1. **Capture** the loss in `apply_death_penalty` / `kill_player` (progression.rs:71-104) onto a new
   `PerConnection.death_lost_xp: i32` field (the corpse-creation pass reads conn fields later in the
   same tick — `kill_player` at :86 runs before the pass at `tick.rs:7738-7827`).
2. **Thread** it through the corpse-creation pass into `Corpse::new` (corpses.rs:48-61) and
   `db::save_corpse` (db/mod.rs:706-755).
3. **Persist**: append-only **migration `0008`**:
   `ALTER TABLE corpses ADD COLUMN lost_xp INTEGER NOT NULL DEFAULT 0;` (do NOT edit `0007_corpses.sql`).
   Add `lost_xp` to `save_corpse` (INSERT), and to `load_corpses` + `CorpseRow`/`CorpseHeaderRow`
   (db/mod.rs:676-792) so a corpse reloaded after a server restart still knows its refund.
4. **Boot-load**: the `Corpse::new` call in the boot path (`tick.rs:906-936`) passes the loaded `lost_xp`.
5. **Refund** at res-accept: `award_xp(server, conn, +((corpse.lost_xp as f32 * pct).round() as i32))`.
   `award_xp` (progression.rs:43-66) already fans `XpGained` + `LevelUp` and re-levels via `resolve`,
   so a refund that crosses a band boundary re-levels the player for free — no special handling.

> **DECISION (nominal vs actual loss):** `loss` is `floor(xp_to_next * 0.05)`. The de-level cascade in
> `resolve` (progression.rs:111-129) clamps at the level-5 floor, so a death that bottoms out at level 5
> may remove *less* than `loss`. Storing the nominal `loss` then refunding 75% of it could slightly
> over-refund in that rare floor case. **Recommended v1:** store the nominal `loss` (simple; correct for
> every death above the floor, which is the overwhelming majority); accept the minor floor-edge
> over-refund. If you want exactness, have `apply_death_penalty` return the real delta (sum the bands
> crossed) and store that instead. Confirm with the user if unsure.

---

## 3. The spell system (VERIFIED — this was the failed recon dimension, mapped by hand)

### Client (`f:/Projects/Project_Dawn`)
- **Spell data** is `data/spell_definitions.gd`: `const ALL: Array` of dicts with keys
  `name, desc, mana_cost, cast_time, cooldown, base_damage, damage_type, target_type, heal_amount,
  classes` + optional buff fields + `min_level`. `target_type` is a string; existing values include
  `ENEMY / ALLY / AOE / SELF / PET_SUMMON / PET_CHARM / PET_HEAL / BIND / NONE` — **special target
  types already exist** (`BIND` for Bind Affinity, `PET_HEAL` for Warder's Mend), so adding **`CORPSE`**
  is the established pattern.
- The **inert Resurrection** entry is at `spell_definitions.gd:315`:
  `{"name": "Resurrection", ... "cast_time": 10.0, "cooldown": 300.0, "target_type": "NONE",
  "min_level": 20, "classes": ["Cleric"]}`. The `DISCIPLINE` map at `:122` keys it to **`alteration`**
  — WRONG; it must be **`restoration`**.
- The **cast wire** is sent from `autoloads/spells.gd:227`:
  `Net.broadcast_cast_spell(spell.spell_name, _cast_target_id(spell))`. `_cast_target_id`
  (spells.gd:391-407) maps `Combat.current_target` to an entity id (`RemotePlayer→char_id`,
  `RemoteEnemy→enemy_id`, `RemotePet→pet_id`, else `0` = self). **Add a `Corpse` branch** here so
  targeting a corpse returns its `corpse_id`, and the client `SpellData.TargetType` enum needs a
  `CORPSE` member.
- A corpse node (`scripts/corpse.gd`) is a clickable `Area3D` that currently only opens a loot window on
  an owner left-click. For a Cleric to cast on it, the **targeting system must accept a corpse as
  `Combat.current_target`** (read `autoloads/targeting.gd` + how `Combat.current_target` is set from a
  click; today corpses likely aren't selectable). This is a real client integration point.

### Server (`F:/Projects/server`)
- **Spell table** is `crates/projectdawn-server/data/spells.toml`, embedded at compile time and parsed
  into the `Spell` struct in `crates/projectdawn-server/src/world/spells.rs:25-142`. `spells.toml` is
  **generated from the client `ALL`** by `Project_Dawn/tools/export_spells.gd` — but the two **drift**
  (see `[[project-warders-mend-server-spell-gap]]`), so author the three res tiers in **BOTH** files
  (or run the export tool and verify). The `Spell` struct has `name, target_type, ..., min_level,
  classes` + buff fields but **no res/xp-percent field** → either hard-code the 25/50/75% per spell name
  server-side, or add a `#[serde(default)] res_xp_percent: f32` field (recommended — keep it data-driven).
- The **cast resolution** is a `match spell.target_type.as_str()` at `tick.rs:3253` (`"SELF"`, `"ALLY"`,
  `"ENEMY"`, `"AOE"`, ...). **Add a `"CORPSE"` arm.** It must: look up `intent.target_id` in the
  `corpses` map (the same lookup the Slice 2 loot branch uses at `tick.rs:6812`; corpse ids live in the
  loot-bag partition `>= LOOT_BAG_ID_BASE`), validate, and (on a valid cast) send the `ResurrectOffer`
  to the corpse owner. (Read the cast-intent handler that feeds this loop — grep `CastSpell` /
  `cast_intents` near `tick.rs:3253` — to see how `intent.caster` / `intent.target_id` / mana / cast
  time are already validated, and where a class/Restoration-req gate would go.)

---

## 4. Death / respawn / corpse / buff surfaces (VERIFIED)

- **Respawn does not relocate** (`handlers.rs:669-692`): the `Respawn` handler resets hp/mp/stamina to
  0.25/0.25/0.50 and clears `death_processed`, but **never touches `conn.pos`** (respawn position is
  client-driven to the client bind). So the **summon-to-corpse teleport is net-new**: set `conn.pos =
  corpse.pos` and fan a forced-position/teleport message. There is no existing forced-position message —
  check `autoloads/net.gd` + how `RemotePlayer` positions are applied to confirm the client honors a
  server-pushed authoritative position (movement is largely client-trusted, so a teleport likely needs
  explicit client handling, not just a Position broadcast).
- **`kill_player`** (progression.rs:86-104) calls `apply_death_penalty`, then **clears `active_buffs`
  (:96)** and sets `corpse_pending`. So **apply res-sickness at ACCEPT time, never at death** (death
  wipes buffs).
- **`Corpse`** (corpses.rs:33-61): `id, owner_char, owner_name, zone, pos, items, coins, spawned_at`.
  Add `lost_xp: i32` (and a `resurrected: bool` if you keep the rezzed-flag in memory only; if it must
  survive a restart, add a column too — recommended, so a restart can't enable a re-res). `new()` is
  `#[allow(clippy::too_many_arguments)]` already. `CORPSE_LINGER_SECS = 300.0`.
- **Corpse loot interaction** (Slice 2, `tick.rs:6812-7036`): a res does NOT consume the corpse; the
  player loots it normally afterward. `corpse_emptied_by_loot` (`tick.rs` helper) only despawns a corpse
  that *held* content and was looted clean — a res touches none of that.
- **Buff system** — **NOT needed for v1** (res-sickness was cut, decision 7.2). This is reference for the
  later res-sickness add only: `crates/projectdawn-server/src/world/buffs.rs` —
  `BuffEffect::StatBuff` + `new_stat_buff` (~227); apply via `apply_stat_buff` (`tick.rs:142`) and fan
  with `fan_out_server_buff_snapshot` (`tick.rs:366`) → `ServerWorldMsg::BuffSnapshot` → the client buff
  window renders it for free. Res-sickness = a named `StatBuff` with **negative** deltas + a few-minute
  duration; the buff tick auto-reverses on expiry. NOTE: there is no negative-*regen* effect today
  (regen only adds HoT/MP-regen), so model res-sickness as **reduced primary stats / max pools** in v1
  (a regen-suppression effect would be net-new — confirm with the user if reduced regen is required).

---

## 5. Wire spec (PD_W0021 → PD_W0022)

Append-only (bincode is positional — new enum variants and new struct-variant fields go at the **END**).
Bump `WORLD_PROTOCOL_ID` to `PD_W0022` (`0x5044_5f57_3030_3232`). Mirror every change in `gdext-net`
(the signal/`Incoming`/decode/emit pattern — see how `CorpseContents` was threaded in Slice 2,
`crates/gdext-net/src/lib.rs`), then **rebuild the DLL**.

- **Cast** reuses the existing `ClientWorldMsg::CastSpell { spell_name, target_id }` — the corpse id is a
  valid `target_id`. No new cast message.
- **New `ServerWorldMsg::ResurrectOffer { corpse_id: EntityId, caster_name: String, xp_percent: u32 }`**
  — sent **privately to the corpse owner only** (single-recipient send, like `send_corpse_contents`
  from Slice 2 or `send_camp_update`; see `handlers.rs` for the precedent). `xp_percent` is **for the
  prompt text only** — the server computes the actual refund from `corpse.lost_xp` at accept time (never
  trust a client-echoed amount).
- **New `ClientWorldMsg::ResurrectAccept { corpse_id: EntityId, accept: bool }`** — the owner's response.
- **Teleport:** either a **new `ServerWorldMsg::Teleport { pos: Vec3 }`** (cleanest) to the owner, or
  reuse a forced position broadcast if one is honored by the client. Decide after reading the client
  position-apply path.
- **Cast-fail to caster:** if a `CastFail`/equivalent message already exists, reuse it for the
  invalid-target / owner-offline / already-rezzed rejections; otherwise a log + silent drop is the v1
  floor (confirm there's user feedback).
- gdext: add the `resurrect_offer` signal + `send_resurrect_accept` (+ a `teleport` signal if new),
  mirroring the `corpse_spawn`/`send_camp` patterns. Client `autoloads/net.gd` relays them.

---

## 6. Build order

Recommended sequence (each step compiles + tests before the next):

**A. Lost-XP capture + persist (no behavior change yet).**
1. `PerConnection.death_lost_xp: i32` (`world/connection.rs`); set it in `apply_death_penalty`/`kill_player`.
2. `Corpse.lost_xp` + `Corpse::new` arg (corpses.rs); thread from the corpse-creation pass (tick.rs:7738+).
3. Migration `0008` (add column); `save_corpse` + `load_corpses` + `CorpseRow`/header + boot-load `Corpse::new`.
4. `cargo test` — should still pass; add a db test (mirror `corpse_loot_tests` in db/mod.rs) asserting a
   saved+loaded corpse round-trips `lost_xp`.

**B. The spells.**
5. `spell_definitions.gd`: replace the single inert `Resurrection` with the **three Cleric tiers**
   (Minor/Resurrection/II), `target_type: "CORPSE"`, the cleric.md reqs, classes `["Cleric"]`, all three
   on `restoration` in the `DISCIPLINE` map; **plus the one Paladin tier** (decision 7.3) on the Paladin
   HOLY skill. Add `CORPSE` to the client `TargetType` enum (`scripts/spell_data.gd`) + the
   `_cast_target_id` corpse branch (spells.gd).
6. `spells.toml`: author the three tiers server-side (+ a `res_xp_percent` field if you add one to the
   `Spell` struct). Confirm `tools/export_spells.gd` doesn't clobber them, or run it and re-add.

**C. Cast → offer → accept → resolve (server).**
7. `"CORPSE"` arm in the `tick.rs:3253` target_type match: resolve the corpse, validate (res tier;
   caster is a **Cleric or Paladin** meeting that tier's casting-skill req; owner in-world; in range; not
   already resurrected), send `ResurrectOffer`.
8. `ResurrectAccept` handler: re-validate, teleport (set `conn.pos` + fan), `award_xp` refund, mark the
   corpse resurrected (persisted). *(No res-sickness in v1.)*
9. Wire + gdext + DLL rebuild (PD_W0022).

**D. Client.**
10. Make a corpse selectable as a cast target (targeting.gd / Combat.current_target).
11. `net.gd` relays `resurrect_offer`; a HUD prompt (Accept/Decline + an `/accept` fallback — reuse the
    camp-countdown Label overlay pattern in `hud.gd`, ~455-548, and the `/accept`-style command path);
    on accept send `ResurrectAccept`. Handle the teleport (yank the living player from bind to the
    corpse cleanly).

**E. Verify + hand off.** See section 8.

---

## 7. Decisions — all LOCKED with the user 2026-06-25 (do not re-litigate)

1. **Res model: summon-back (v1).** Keep the shipped immediate-naked-respawn-at-bind model; a res
   teleports the living player back to their corpse + refunds XP. The authentic "stay-a-corpse,
   release-vs-wait" model is explicitly NOT v1 (it would rework the death/respawn flow first; relates to
   `[[project-respawn-at-bind]]`).
2. **Res-sickness: NONE in v1.** Ship the core res (summon + XP refund) without a debuff; add it as a
   later follow-up. → **Skip every buff-system step** in this plan: no `StatBuff`, no extra
   `BuffSnapshot` for the res. (Section 4's buff notes are for the future add only.)
3. **Who can res: Cleric + Paladin.** The three Cleric Restoration tiers (25/50/75%) PLUS a single
   weaker Paladin tier. Necro/others later. → Author the Paladin spell too and let the class gate accept
   Cleric OR Paladin. (Confirm the Paladin caster skill from the `DISCIPLINE` map — Paladin HOLY heals
   like Lay on Hands / Crusader's Mend already exist; the Paladin res should sit on that same skill. A
   sensible shape: one tier, ~20-25% XP, higher `min_level` + longer cast than the Cleric Minor. Numbers
   are tunable.)
4. **Offline owner: reject** the res cast (no one to accept it), with caster feedback.
5. **Zero-loss corpse** (died below level 5 → `lost_xp = 0`): **allow** the res; it still summons + saves
   the run, refunds 0 XP.
6. **Lost-XP accounting: store the nominal computed loss** (`floor(xp_to_next * 0.05)` at death); accept
   the minor over-refund only in the rare level-5-floor case (section 2).
7. **Double-res guard: yes** — mark a corpse resurrected and **persist it** (a `resurrected` column, in
   the same migration `0008`) so a restart can't re-enable a free re-res.
8. **Same-zone only** for v1 (no cross-zone summon).

---

## 8. Verification + hand-off

- `cargo test -p projectdawn-server --lib` green; add db round-trip test for `lost_xp` and a unit test
  for the refund math (% of lost). Rebuild the DLL; client headless boot clean.
- **Two-client playtest** (the acceptance test): A dies (corpse with known gear + a known XP loss); B
  (Cleric) targets A's corpse and casts a Resurrection tier; A gets the offer prompt and accepts; A is
  **teleported to the corpse**, the **XP is refunded** (watch the XP bar / level), and A can **loot the
  corpse** normally for gear. (No res-sickness in v1.) Also test the **Paladin** res tier. Verify: decline does
  nothing; a second res on the same corpse is rejected; a res when A is offline is rejected; a res on a
  level-<5 (zero-loss) corpse still summons.
- Write a `docs/playtest_notes/corpse_slice3_checklist.md` from `TEMPLATE_checklist.md`; a
  `docs/session_notes/session_YYYY_MM_DD.md` entry; move the **Resurrection (Cleric)** item out of the
  CLAUDE.md to-do; add "what exists" to `systems_overview.md`.
- **Do NOT commit until the user playtests.** Then one server commit + one client commit (stage explicit
  files; exclude pre-existing `.claude/settings.local.json` + unrelated playtest checklists). End commit
  messages with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## 9. Recommended working style (matches how Slices 1/2 + the orb→corpse change were built)

A read-only **recon workflow** to map exact integration points (especially the cast-intent handler +
the client targeting/position-apply paths, which this plan did not fully trace), then implement, then an
**adversarial multi-dimension review workflow** over the diff before hand-off. This epic has a money/XP +
persistence + wire surface, so adversarial verification pays: the Slice 2 review caught a real item-loss
window. **Always verify a recon claim against the real source before acting on it** — one recon agent in
this very epic was wrong (it reported the wrong protocol id while writing this plan).
