# Systems Overview

What's built and how it hangs together — a per-system map of the client. This absorbs the
"what exists" knowledge that used to live in the completed (`[x]`) section of the root
`CLAUDE.md` to-do list. Dated history (what changed when, and why) lives in
`docs/session_notes/`; anything that crosses the wire is contracted in
`server/docs/server_design.md`.

This is a reference, not an exhaustive API. When in doubt, the code is truth.

---

## Combat

- **Auto-attack:** `Combat._on_auto_attack()` fires on a timer. `MELEE_RANGE = 3.0` m;
  `RANGED_RANGE = 25.0` m when `ItemData.is_ranged`. Ranged damage uses the DEX bonus,
  melee uses STR. Each landing hit calls `WeaponSkills.try_advance()`. Magic numbers
  (ranges, evasion, crit constants) are named consts at the top of `autoloads/combat.gd`.
- **Dual wield:** an off-hand timer fires when the off-hand weapon slot is occupied; +20%
  miss penalty on off-hand swings, which also call `try_advance("dual_wield")`.
- **Critical hits:** auto/skill crits scale with DEX (0–30%); spell crits scale with INT
  (0–20%). Both roll a 1.5–2.0× multiplier and log with the bright-gold `MsgType.CRIT`.
- **Procs:** `ItemData.proc_chance/proc_damage/proc_damage_type/proc_name`;
  `Combat._try_fire_proc()` rolls on every main- and off-hand hit, with elemental FX + a
  combat-log line.
- **AOE:** `SpellData.TargetType.AOE` → `Combat.deal_aoe_spell_damage()` hits all enemies
  within a radius.
- **Elemental resistances:** enemies carry per-element resist values that reduce incoming
  spell damage; undead carry shadow resist, etc.
- **Damage shield (thorns):** attacker takes X damage when hitting the shielded target
  (Druid / Enchanter).
- **Enemy state machine:** IDLE → CHASE → ATTACK → FLEE/LEASH. Caster enemies kite at
  `caster_range`; healer enemies flee to spawn below `healer_flee_hp`. Relevant exports:
  `spell_damage`, `caster_range`, `flee_range`.
- **Hit reactions / VFX:** physical hits flash the mesh white; spell hits flash an
  elemental color + spawn an `OmniLight3D` burst at the impact point, via
  `enemy.flash_spell_hit(color)` from `Combat.deal_spell_damage()`. Color per type: fire
  orange, ice blue, lightning yellow, arcane purple, holy gold, nature green, spirit
  lavender, shadow dark-purple.
- **Death:** enemies and the player fall over rather than vanishing.

---

## Spells & casting

- **Cast flow:** `Spells.cast_spell(spell)` → optional cast bar → `_apply_spell()` →
  damage / heal / buff routed to the right system. Casting skills advance on cast;
  Channeling advances when a hit survives interruption.
- **Availability:** `SpellData.min_level` gates a spell; `setup_for_class()` filters
  `available[]` by class + level on every level-up.
- **Ranks:** `SpellData.rank` (1/2/3) + `SpellData.base_name`. `setup_for_class()` keeps
  only the highest accessible rank per base spell. Rank II ≈ lvl 6–12 (+40% power), Rank
  III ≈ lvl 14–16 (+90%). Discipline inherits from `base_name`, so rank variants need no
  separate `DISCIPLINE` entry.
- **Buffs route to `BuffManager`:** primary-stat buffs, HoT, DoT, absorb, haste, speed,
  clarity (MP regen), damage shield, stealth, lich form. Stat buffs apply directly to
  `PlayerStats` and undo on expire / death / zone change.
- **ALLY-target buffs cast on a peer** route through the server like heals. The 10 curated
  ally-castable buffs (`TargetType.ALLY` — Bless, Valor, Brilliance, Clarity, Strength,
  Gift of Insight, Spirit of the Bear, Spirit of Wolf, Haste, Thorns) skip the caster's
  local `BuffManager.add_*` when a `RemotePlayer` is targeted (`Spells._ally_target_is_remote`);
  the server applies them to the target conn (`tick.rs::apply_player_spell_buffs`, shared by
  the SELF and ALLY arms) and fans a `BuffSnapshot`. The recipient's
  `BuffManager.reconcile_with_server_snapshot()` is now **additive** — a snapshot buff it
  doesn't track locally is reconstructed from the spell definition by name
  (`Spells.get_spell_by_name`), so the buffed player's own `PlayerStats` + bar reflect it
  and the subtractive pass still undoes it on expiry/dispel. Self-cast (no target) keeps the
  local-apply path. Pet targets fall back to self for pure buffs (server pets have no
  replicated buff state yet); heals/HoTs still route to pets. Damage shields (Thorns,
  Spellshield, Rune/Primal Bond absorb) are self-only by design except Thorns, which is
  ally-castable.
- **Ports:** `TargetType.PORT` with `port_zone_path` / `port_entry_id`; Gate uses empty
  strings to resolve to the bind point.
- **Notable resolved spells:** Complete Heal (Cleric, self-heal for now), Torpor (Shaman),
  Clarity/Breeze (Enchanter), Haste (Enchanter), Spirit of Wolf (Druid/Shaman), Lich Form
  (Necromancer — skips HP regen, extreme MP regen), Gate (Wizard), Exsanguinate (Blood
  Mage — damage = min(drain, target.hp), converted to caster MP). Ranger (Ensnaring Roots,
  Camouflage, Hunter's Eye) and Witch Hunter (Spellbreak silence, Antimagic Ward dispel,
  Expose dispel) lines are in `data/spell_definitions.gd`.

---

## Status effects & control

- **Stun:** `SkillData.EffectType.STUN` → `enemy.stun()`; stunned enemies skip the whole
  physics state machine (no move, no attack). Shield Bash (Warrior/Paladin/Shadow Knight).
- **Slow:** `enemy.apply_attack_slow()`; attack cooldown scaled by `(1.0 + slow_amount)`.
  Shaman/Enchanter "Slow"; Torpor and some Bard songs also slow.
- **Root:** `enemy.root()`; blocks movement in `_tick_chase()` while still allowing attack.
  Ensnare (Druid), Immobilize (Enchanter).
- **Silence:** Witch Hunter Spellbreak (`silence_duration`).

---

## Active skills

- `Skills.use_skill(skill)` resolves via the `SkillData.EffectType` enum
  (STUN, FEIGN_DEATH, STEALTH, …). Defined in `scripts/skill_definitions.gd`.
- **Feign Death (Monk):** 80% success; all grouped enemies de-aggro via
  `feign_death_deaggro()`.
- **Sneak & Hide (Rogue):** `BuffManager.add_stealth()`; enemy aggro range vs. stealthed
  players is reduced; breaks on attacking.
- **Track (Ranger):** `scripts/track_window.gd` lists enemies within 60 m (name / level /
  distance), refreshing every 2 s.

---

## Passive skills

- `WeaponSkills`, `ArmorSkills`, `CastingSkills` all extend
  `autoloads/passive_skill_tracker.gd` (shared `try_advance()`).
- Weapon skills (1H Slashing, Piercing, 2H Blunt, Defense, Dodge, Archery, Dual Wield,
  Hand to Hand…) train through use; per-class caps at lvl 60 in
  `data/weapon_skill_definitions.gd`; higher skill = better hit/damage. Shown live in the
  character window's Combat Skills section.
- Casting disciplines (evocation, alteration, channeling, …) advance on cast / surviving
  interruption.

---

## Progression & sustain

- **PlayerStats** owns HP/MP/stamina, STR/AGI/INT/WIS/CON(/CHA), race/class, bind point.
  **Level and XP are server-authoritative** as of the corpse epic's Slice 0 (see "Death,
  corpses & resurrection" below); the client mirrors what the server sends.
- **Meditation:** sitting applies 5× HP/MP and 3× stamina regen multipliers in `regen.gd`;
  movement or acquiring a target auto-stands (`player.gd`, `Regen._on_target_changed`).
- **Food & drink:** `ItemData.is_food/is_drink/food_hp_regen/food_mp_regen/food_duration`;
  right-click in inventory calls `add_food_buff` / `add_drink_buff`; regen stacks
  additively on top of meditation. (Planned rework: gate base regen instead of stacking —
  see the to-do.)
- **Bind points:** Bind Affinity stores `bind_zone_path/entry_id/zone_name` on PlayerStats;
  `player_death._respawn()` routes through `ZoneLoader.travel_to()` when set (falls back to
  `_respawn_position`). XP loss is logged to the combat log.
- **Group XP:** `GroupManager.distribute_kill_xp(base_xp)` splits XP with a 20% group bonus;
  `enemy._die()` routes through it; `_rpc_receive_xp` delivers each remote member's share.

---

## Death, corpses & resurrection

The EverQuest corpse-run epic (design + as-built deviations:
`docs/design/corpse_and_resurrection_plan.md`). Shipped in four slices, wire PD_W0018 to
PD_W0022. The locked model: gear stays on your corpse, you respawn naked, XP loss can de-level
you, unretrieved gear is lost for good, and a Cleric/Paladin res refunds part of the loss.

- **Server-authoritative XP + leveling (Slice 0, PD_W0018).** `world/progression.rs` owns xp and
  level. `award_xp` is the single choke point that mutates `conn.xp`, resolves a level up *or
  down*, and fans `XpGained` (private, with authoritative current/to-next) plus `LevelUp`. The
  client mirrors and applies the same per-level intrinsic stat deltas from a lockstep table
  (`char_data::level_gains` vs the client's `CLASS_LEVEL_GAINS`, anchor-tested); only the delta is
  added, never an overwrite, so gear/buff bonuses survive. This closed the old "client leveling is
  provisional / a HealthUpdate rolls back a level-up" drift.
- **The XP curve.** Cubic level cost (`char_data::xp_to_next_for`) plus EQ's *quadratic* per-kill
  award (`kill_xp = mob_level^2 * ZEM * 3.5`, `ZEM_NORMAL = 75`), which keeps kills-per-level
  roughly constant (~11 on an even con). Replaced the old geometric x1.5 curve that saturated i32
  around level 43. Per-zone ZEM is a later content pass. See
  `docs/design/everquest_xp_curve_reference.md`.
- **Death penalty.** `DEATH_XP_LOSS_FRACTION = 0.05` (5% of the *current level's XP band*), and the
  loss **cascades past the level boundary with no per-death cap**, so repeated deaths keep
  de-leveling you. Levels 1 to 4 are exempt and no cascade can drop you below
  `DEATH_PENALTY_FLOOR_LEVEL = 5` (the grace line and the floor are the same line).
- **The corpse (Slice 1, PD_W0019).** `world/corpses.rs`: a corpse is a **persisted, owner-only
  `LootBag`**. On death your gear (equipped + bags) and **carried coin** move onto a corpse at the
  death spot and you respawn naked (banked items/coin are never touched). It survives a server
  restart (`db::{save_corpse, load_corpses, delete_corpse}`, migrations `0007_corpses.sql` /
  `0008_corpse_resurrection.sql`). Ids are minted from the loot-bag partition so despawn/AOI route
  exactly like a bag; a corpse is told apart on spawn by the dedicated `CorpseSpawn` message. The
  boot loader advances the shared `NEXT_BAG_ID` past the max loaded corpse id
  (`loot::reserve_bag_ids_through`) so a fresh bag can't reuse a corpse id.
- **Harsh decay.** `corpses::CORPSE_LINGER_SECS` (**7 days / 604800 s** as of 2026-07-17, off a
  300 s test value; Phase 4 sets the considered production value). On decay the corpse despawns and
  its row + items are deleted: unretrieved gear is gone for good. Distinct from
  `mod.rs::ENEMY_DESPAWN_LINGER_SECS` (5 s), the unrelated hold-at-death-pos for slain *mobs*
  (renamed off the once-shared `CORPSE_LINGER_SECS` name 2026-07-17).
- **Respawn (client-driven, gated).** On death you respawn immediately to ~25% HP / 25% MP / 50%
  stamina, in place (no server-side bind yet; see the To-Do). The client sends `Respawn`, but the
  server honors it **only when `conn.death_processed` is set** — the death path sets that flag
  alongside `hp = 0`, and `Respawn` clears it. So a *living* player's `Respawn` is a silent no-op,
  closing exploit-audit finding 3 (spamming `Respawn` to floor HP at 25% for near-invulnerability).
  Integration-tested (`respawn_requires_being_dead`); playtested 2026-07-20.
- **CastSpell class/level gate.** The cast resolver (`world/tick.rs`) rejects a `CastSpell` unless
  the caster's class is in the spell's `classes` AND their level meets `min_level` — checked right
  after the `spells::lookup` and before any mana / cooldown / skill side effect, so a forged cast
  costs nothing and leaves no state. Closes the audit's "any class can cast any spell it can name";
  the resurrection (`CORPSE`) arm keeps its own copy as defense-in-depth. Every `spells.toml` entry
  is class- and `min_level`-tagged (invariant-tested), and `conn.class` matches the toml class
  strings (same field `skills::cap_for` keys on). Playtested 2026-07-22
  (`cast_class_level_gate_checklist.md`): the regression sweep passed with zero gate rejections in
  `server.log`. *(Note: a client-only spell is dropped earlier as "unknown spell" by `lookup`,
  before this gate — see the "client-only spell backlog" To-Do.)*
- **Attack weapon_path derived server-side.** The `Attack` message carries the weapon the client
  claims to swing, but the resolver ignores it and reads the equipped weapon from the server's
  equipment map — `PerConnection::equipped_weapon_path(is_offhand)`, main hand = slot 0, off hand =
  slot 1 (protocol `EquipSlot` order). All five consumers (the `calc_swing` damage roll, PvP +
  enemy range checks, out-of-range log, weapon-skill advance) use it. Empty slot = unarmed 1-4 fist
  / `hand_to_hand` swing. Closes audit finding 5 (a modified client claiming a heavier / ranged /
  wrong-skill weapon). Equipping only routes through the server `EquipItem` intent, so the map is
  authoritative; new characters start bare (`create_character` seeds no gear). Playtested 2026-07-23
  (`attack_weapon_path_checklist.md`).
- **Melee swing-rate limit (per-hand).** A per-connection, per-hand minimum interval between swings
  (`conn.last_swing_at[2]`, 0 main / 1 off) closes the attack-speed hack (no swing timer existed).
  For each `Attack` the resolver takes the equipped weapon's `weapon_delay`, computes the fastest a
  fully-hasted client could swing that hand (`min_swing_interval_secs` = `weapon_delay x handMult x
  (1 - MAX_HASTE) - grace`, floored 0.4s), and silently drops (`continue`, no Miss) a same-hand swing
  that arrives faster; the timer advances only on an accepted swing. Per-hand so dual-wield's two
  independent streams don't throttle each other; assumes max haste so hasted players never trip; only
  rejects "too fast" (the client sends an `Attack` only on a landed hit, no burst). Also rejects an
  off-hand `Attack` with an empty off-hand slot (a forged free fist-damage stream). Mirrors the
  client pacing in `combat.gd`. Playtested 2026-07-29 (`swing_rate_limit_checklist.md`); the only
  rejections observed were a proc weapon's client-driven second Attack (see server-authoritative
  procs below).
- **Server-authoritative weapon procs (PD_W0025).** On each accepted, landed melee swing the server
  rolls the equipped weapon's `proc_chance` (read from the server equipment map, so unspoofable) and
  folds `proc_damage` into that swing's own HP/aggro/death resolution — a proc killing blow runs the
  single death cascade once (credit + loot). Gated on the target still alive (no proc-on-corpse);
  flat 5% proc crit; no elemental resist (the server has no enemy-resist model). A private
  `ProcTriggered` wire message drives the client's named "<proc> for N (Critical!)" hit + elemental
  flash (`remote_player_manager._on_proc_triggered`); the mob HP drop is fanned to all via the
  combined HealthUpdate. Replaces the old client-driven proc (a second Attack that double-hit as a
  full weapon roll). `proc_damage_type` is authored in the client's SpellData enum space
  (`proc_damage_type_to_wire` bridges it; Flamebrand corrected ICE->FIRE). Built 2026-07-30;
  playtest `server_procs_checklist.md`. Deferred: proc resist model, PvP-player procs.
- **Corpse retrieval (Slice 2, PD_W0020).** Loot your own corpse via the existing `LootItem` /
  `LootAll` intents keyed by corpse id, plus a private `CorpseContents` snapshot to the owner.
  Owner-only. The persist is **atomic** (the corpse delete folds into the inventory-write
  transaction, with an in-memory revert on failure) — a pre-commit review caught a real loss window
  here. This is the only atomic cross-store transfer in the codebase (the audit flags the others).
- **Monster orb to corpse (PD_W0021).** Slain creatures leave a body with a "<creature>'s corpse"
  nameplate instead of a golden orb (`creature_name` appended to `LootBagSpawn`; shared
  `scripts/corpse_body.gd` builds the capsule + white nameplate for both player corpses and mob
  bodies). Player-dropped bags keep the golden-sack look.
- **Resurrection (Slice 3, PD_W0022).** Res spells are `target_type == "CORPSE"` with a
  `res_xp_percent`: Cleric **Resurrection (Minor) 25%**, **Resurrection 50%**, **Resurrection II
  75%**; Paladin **Reclaim Soul 20%**. Casting on a corpse sends a private `ResurrectOffer` to the
  owner (must be online; held as `pending_res_offer`); on `ResurrectAccept` the owner is
  `Teleport`ed to the corpse and refunded that percentage of **that death's actual lost xp**
  (captured on `Corpse.lost_xp` — the ACTUAL amount removed, not nominal, which closes a
  level-5-floor over-refund exploit). One res per corpse (persisted `resurrected` flag).
- **Not built:** **res-sickness** (specced for Slice 3, dropped from v1), respawn-at-bind /
  Soul Binder NPC (respawn still honors the *client* bind; `BindAtCurrentLocation` is an inert wire
  variant with no server handler), corpse auto-re-equip on loot, and per-creature corpse
  models/scale.

---

## Items, inventory, equipment

- **Inventory:** bag slots + item stacks; `add_item()` / `remove_item()` / `stack_all()`
  (the "Stack All" button per bag window calls the latter). Base layout is flat slots with
  bags-as-items.
- **Equipment:** paperdoll slots, equip/unequip; `can_dual_wield()` gates the off-hand
  weapon slot; `_resolve_slot()` routes a second weapon to "offhand" when the dual_wield
  skill > 0.
- **Augmentation/socketing:** `ItemData.gem_slots`, `socketed_augments`, `Type.AUGMENT`
  (data shape only; combine UI deferred).
- **Item registry:** `ItemRegistry` autoload; the canonical item table is exported to the
  server's `items.toml` via `tools/export_items.gd`.
- **Currency (2026-05-21):** four-tier coin — copper/silver/gold/platinum at 100:1 per
  tier — held as **four independent stacks** on `PlayerStats` (`platinum/gold/silver/
  copper`), never silently consolidated. Tier math (totals, reduction, make-change
  `spend`) lives in the `Currency` autoload, mirroring the server's
  `protocol::world::Coins` (Rust) — keep the two in sync. Server-authoritative in
  launcher mode: `CoinsUpdate` carries the four-int wallet (wire bump PD_W0013, DB
  migration `0004_currency.sql` carries legacy `coins`→`copper`); legacy client saves
  load their single `coins` value into copper. Prices stay single-int copper
  (`ItemData.vendor_price`); the vendor window shows prices reduced ("2s 50c") but the
  wallet footer shows actual stacks (a 350-copper hoard reads "350c"). Design:
  `docs/concepts/world/currency.md`. Smoke: `tools/currency_smoke.gd` (headless).
- **Encumbrance (2026-05-21):** carry weight vs STR-driven capacity
  (`10 + STR`, in the `Encumbrance` autoload). Weight = coins (flat 0.02/coin **per
  coin regardless of tier** — the designed pressure to convert hoards) + inventory +
  worn equipment (`ItemData.weight`; **all 169 items tagged 2026-06-12** per the
  approved `docs/design/item_weight_proposal.md` — weapons 2–8, chain armor rescaled
  ~45% from the starter anchors, ore 0.25 / ingot 0.1 with mithril/adamantite lore
  exceptions, universal 0.1 floor so nothing weighs 0; coverage check:
  `tools/item_weight_audit.gd`, run headless with `--script`). Over capacity:
  movement slows linearly to a 0.25 floor (applied after the mount mult in
  `player.gd`) and stamina regen halves (stops at 2× capacity, in `regen.gd`);
  "You are encumbered!" CombatLog line on threshold crossings. Client-side v1 — the
  server's movement clamp picks up the slowdown via the scaled direction vector; no
  server-side weight model yet.
- **Currency & encumbrance visibility UI (2026-06-12):** the wallet renders in the
  inventory window (gold line above the trash slot — raw per-tier stacks via
  `Currency.format_coins`, live on `PlayerStats.coins_changed`) as well as the vendor
  footer; both use `UITheme.C_COINS`. The character window's attribute grid gained a
  `WT` row showing `Encumbrance.total_weight / capacity` ("12.4 / 60.0"), colored
  `UITheme.C_ENCUMBERED` (yellow) past capacity and `UITheme.C_OVERLOADED` (red) at
  ≥ 2×, tooltip explaining both thresholds. The HUD shows an encumbered/overloaded
  warning label under the stat panel only while over capacity
  (`hud.gd::_build_encumbrance_indicator`), so the slowdown is explained without
  opening any window.
- **Group loot rights & coin drops (2026-06-15, server-authoritative, wire PD_W0014):**
  the faucet + the rules the economy was missing. Design:
  `docs/design/group_loot_and_coin.md`.
  - **Coin drops** — mobs roll coin on death by tier (`loot::roll_coin_for_mob`, scaled
    by mob level per `currency.md`: wildlife 0, low humanoid 5–50c, mid 50–300c, named
    1–20s, boss 1–10g/rare plat; beasts identified by a name list). The coin rides on the
    `LootBag` (`coins: Coins`) and shows as a gold "Coins:" row in the loot window.
  - **Ownership** — a corpse belongs to the kill-creditor (top damager) and, resolved
    live at loot time, their group (`LootBag.owner_killer` + `can_loot`). Strangers are
    refused (`LootRejected` → "That isn't your loot."). Player-dropped bags stay public.
  - **Drop to ground (client UI, 2026-06-16)** — `inventory_window.gd` invokes the
    long-existing `Net.broadcast_drop_item` two ways: a ⬇ **Drop cell** beside the Trash
    cell, and **releasing a drag out onto the 3D world** (detected via
    `gui_get_hovered_control() == null` — releasing over *any* Control, including this
    window's chrome or another panel, snaps the item back). Both confirm first and let the
    server's `InventoryDelta` empty
    the slot (no optimistic clear). Server `DropItem` spawns a public single-stack `LootBag`
    at the player's feet and now removes from **base or bag slots** via the shared bag-aware
    `inventory.destroy_at` (the same primitive behind DestroyItem; `drop_base` was retired).
  - **Loot mode** (per `Group`, leader-set, default Round Robin; `groups::LootMode`)
    governs **item turns only**: **Round Robin** rotates per corpse (lazy first-loot claim
    via `next_loot_turn`, "Not your turn to loot." otherwise); **FFA** lets any member loot
    anything, any time.
  - **Coin distribution follows the looter's `/autosplit`, independent of mode**
    (`PerConnection.autosplit`, default on; revised in the 2026-06-15 playtest): **on** →
    split evenly among group members within `GROUP_COIN_SHARE_RANGE` (30 m) of the corpse
    (remainder→looter); **off** → looter keeps it (master-looter = FFA + autosplit off).
    Solo/ungrouped never splits. Credit reuses the vendor-payout path (`Coins::add_payout`
    + `CoinsUpdate`). Toggling `/autosplit` to a new value fans a `GroupNotice` ("X set
    auto-split on/off.") to the player's **other** online group-mates (2026-06-16) so the
    group sees who's splitting; the toggler gets only their local `hud.gd` echo (no
    double-log), and a solo/no-op toggle fans nothing.
  - **Group leadership** is server-authoritative end to end: invite/accept/leave/kick
    **and `PassLeadership`** all resolve in the tick loop and re-fan `GroupRoster` (the
    leadership handoff was added 2026-06-15 — it had been local-only, a latent bug now
    load-bearing since leadership gates `/loot`).
  - **Client**: `/autosplit on|off` and leader `/loot rr|ffa` chat commands (`hud.gd`);
    `GroupManager.loot_mode` mirrors the roster; group-panel header shows `[RR]`/`[FFA]`;
    coin + reject feedback flow through `RemoteLootBagManager`. XP split is unchanged
    (still distance-agnostic — a deliberate asymmetry vs coin's proximity gate).

- **Banker NPC — slice 1 / coins (2026-06-17, server-authoritative, wire PD_W0015):** a town
  NPC (**Thalia Mourne**) giving **zero-weight coin storage** + **tier exchange** — the relief
  valve for the four-tier coin-weight system. Design: `docs/concepts/world/currency.md`.
  - **Bank balance** is a per-character four-tier wallet persisted in `bank_*` columns
    (`0005_bank.sql`), held on `PerConnection.bank_coins` (dirty-flag persisted via the
    checkpoint sweep + disconnect flush; seeded to the client by a `BankSnapshot` on
    enter-world). Zero weight on the player — banked coin doesn't count toward encumbrance.
  - **Deposit / withdraw** move per-tier amounts between the carried wallet and the bank;
    **exchange** converts coin between tiers on the carried wallet (value-preserving,
    **0% fee** for the MVP; up-conversions convert the whole-multiple part and leave any
    remainder, e.g. 150c → 1s + 50c). All math
    lives on `protocol::Coins` (`exchange` / `has_at_least` / `add_each` / `sub_each`,
    saturating) and is server-validated against minting (non-negative, affordable). Wire:
    `Bank{Deposit,Withdraw}Coins` / `BankExchange` → fan `CoinsUpdate` (wallet) +
    `BankSnapshot` (bank), or `BankRejected`.
  - **Client**: `BankerManager` autoload (proximity + open, caches the bank balance);
    `BankerNPC` in the `banker_npcs` group (targeted via `targeting.gd`, opened via
    `hud.gd`'s NPC-interact path); a `BankWindow` (`bank_window.gd`) with wallet + bank rows,
    per-tier deposit/withdraw, and tier-exchange controls — server-authoritative, refreshing
    off the fans (no optimistic mutation; entry fields clear only on the confirming snapshot).
  - **Slice 2 — item storage (2026-06-19, wire PD_W0016):** a 10-slot per-character item vault
    (`bank_items`, char-keyed) + a 2-slot **account-shared** vault (`account_bank_items`,
    account-keyed, EQ shared bank). One reusable `ItemVault` struct backs both (deposit
    stack-merge + capacity sizing, take/restore). **One character per account is now enforced**
    in-world (a duplicate login is **refused** — the session already playing is never
    force-disconnected, avoiding the Lineage II re-login boot exploit), which keeps the shared
    vault single-owner, persisted by `account_id`. Deposit
    is the right-click quick-transfer (right-click an inventory/bag item while the bank is open;
    `docs/design/inventory_interaction_grammar.md` §4); withdraw is right-click a vault slot; both
    move whole stacks. Server store sizes by vault room then debits inventory by the actual
    removed count (no dup); withdraw refunds overflow back to the source slot (no loss); bag-typed
    items rejected. Wire `BankStoreItem`/`BankWithdrawItem` (string location + `shared`, not the
    SlotRef tagged enum — gdext can't encode those from GDScript) + `BankItemSnapshot` (full vault
    per op). Client: `BankWindow` Coins/Items tabs; coins also gained per-tier clickable chips for
    right-click quick-transfer (slice-1 buttons kept). The full cursor grammar (partial grabs,
    split, drag-and-drop, a server-tracked cursor) is a separate deferred track.
  - **Still open:** exchange fee bands; a Banker-NPC proximity gate on bank actions (gates only on
    `in_world` today, matching the vendor pattern — value-preserving); bag storage.

---

## Pets, warders, transforms, mounts

- **PetManager:** generic pet lifecycle (summon / unsummon / charm).
- **WarderAI:** Beast Master warder behavior (retreat / fury / `setup_for_class`),
  extracted from PetManager. Warder idle state faces the player's look direction.
- **Pet stats & buffs (server-authoritative):** the server `Entity` carries `PrimaryStats`
  (`stats` + `base_stats`) and `active_buffs`. Pets get a level-derived stat base on summon;
  melee damage adds the STR *buff delta* `(stats.strength − base_stats.strength)/5` on top of
  `mob.dmg`, so unbuffed pets are unchanged and a Strength buff raises pet DPS like it does a
  player's. ALLY buffs cast on a pet route through `tick.rs::apply_pet_spell_buffs`: stat
  (str→damage, max_hp→Valor), Haste (→ `attack_interval`), Spirit of Wolf (→ `move_speed`),
  and HoT all apply; the pet's `tick_buffs` heals/expires them and a `BuffSnapshot` fans under
  the pet id (`RemotePet` renders it in the target frame). Thorns on a pet **reflects** onto
  the attacking enemy (enemy→pet hit path, mirroring the enemy→player reflect; a reflect-kill
  drops the enemy with no XP/loot, same as the player path; the owner sees a combat-log line +
  floating number). **Deferred:** AGI/INT/WIS combat effect (stored/buffable but display-only
  — no pet dodge / spell-power model). MP-regen / accuracy buffs aren't routed to pets (no pet
  mana / crit).
- **Transformations:** e.g. Revenant — grants ultravision; tradeskill scores carry over
  automatically (they live outside PlayerStats).
- **MountManager:** client-side v1 — item whistles summon, per-zone `NO_MOUNT_ZONES`
  blacklist, any incoming damage dismounts, mount speed multiplier overrides other speed
  sources. Not fully wired (see to-do).

---

## World & environment

- **Zones:** `ZoneLoader` owns transitions and the current zone path/name.
- **Day/night:** `TimeOfDay` emits `hour_changed`. EnemySpawner `night_only` mobs spawn at
  hour 20, despawn at hour 6. (Per-client today; server broadcast planned.)
- **Vision:** `VisionSystem` adjusts brightness + infravision green tint at night by race —
  ultravision (Dark Elf, Ogre, Troll, Kel\`varath), infravision (Elf, Wood Elf, Half-Elf,
  Dwarf, Gnome, Halfling, Fae, Felhari, Kobold), normal (Human, Minotaur, Half-Ogre).
- **Spawns:** spawn points with respawn timers keep the world populated.
- **Named/boss mobs:** `data/named_mob_definitions.gd` (Rotfang, Greth Bonecrusher, Ancient
  Crawler, Sable, The Undying). `EnemySpawner.named_mob_id` + `named_respawn_time`;
  `enemy.apply_named()` sets a gold nameplate, scales HP/XP/damage, arms `_named_drops`
  (guaranteed + chance-based rare loot), and enrages below a configurable HP% (speed +
  damage boost, red name). `Loot._on_enemy_died()` appends `_named_drops` after the normal
  table roll.
- **Fall damage:** `_on_land()` in `player.gd`; threshold 9 m/s; `(speed - threshold) × 5`
  HP via `Combat.receive_player_damage()`. (TODO: skip under Levitate / Feather Fall.)

---

## NPCs, dialogue, quests, vendors

- **Dialogue:** `DialogueNPC` (Area3D proximity register) + `DialogueManager` autoload;
  trees in `data/dialogue_definitions.gd` (node ids → text + numbered responses with
  goto/close/open_vendor/give_quest/complete_quest actions; `quest_condition` filters
  responses by quest state). `scripts/dialogue_window.gd` renders it. Interact priority:
  DialogueManager > VendorManager > crafting station > skinning/mining.
- **Quests:** server-authoritative as of quest phase 2 (PD_W0024, shipped 2026-07-10 to 07-15;
  phase 1 kill credit landed 2026-07-08, PD_W0023). The server owns objective state: it counts
  quest kills itself (`active_quests` table + per-kill `QuestProgress`, killer-private with the
  group split), seeds the client journal from a `QuestSnapshot` on every login (survives relog
  AND server restart), rejects a turn-in until every objective is met (a forged `CompleteQuest`
  pays nothing), and grants XP + the authored item reward on turn-in via the same
  `InventoryDelta` path as loot, gated once-per-character by the `completed_quests` record. Kill
  quests go "Ready" in the field and pay only at the NPC turn-in (classic EQ), not on the last
  kill. Client side, `QuestManager` mirrors this state and `scripts/quest_journal.gd` (J key;
  Active/Completed tabs, Abandon button) renders it; quest data in `data/quest_definitions.gd`
  (client) / `quests.toml` (server). Dialogue NPCs give/turn-in quests (Aldric: wolf_threat,
  rotfang_hunt; Brom: rat_infestation, gnoll_raiders, wired 2026-07-15). Open follow-ups live in
  the `CLAUDE.md` To-Do (a ring-reward stat bug, a Hunter's Medal re-test, the deliberately-cut
  low-level dialogue-refusal polish).
- **Vendors:** `VendorManager` + `scenes/vendor_npc.tscn` / `scripts/vendor_npc.gd`
  (proximity register, F to open); types in `data/vendor_definitions.gd`; buy/sell window
  functional.

---

## Tradeskills & crafting

- `Crafting` autoload (XP, success formula, racial multipliers, access gates) +
  `crafting_window.gd` (K to open) + `data/recipe_definitions.gd` (15 tradeskills:
  Smelting, Tanning, Leatherworking, Tailoring, Blacksmithing, Weaponsmithing, Woodworking,
  Fletching, Alchemy, Poison Making, Baking, Brewing, Jewelry Crafting, Pottery, Tinkering).
- Mob crafting-material drops via `data/loot_tables.gd` archetypes (`.tres`-backed).
  Skinning: `skinning_knife.tres` + `enemy.try_skin()` (F key; pelt quality by skill).
- `StationManager` tracks station proximity (display; not yet enforced). Phase detail in
  `docs/concepts/tradeskills/todo_list.md`.

---

## UI / HUD

- **HUD core** (`scripts/hud.gd`) split into a `hud_*.gd` family: DeathScreen, CastBar,
  BuffBar, PetPanel, GroupPanel. Includes the always-visible XP bar, target frame with
  actual HP numbers, and a target-of-target frame.
- **Buff/debuff bar:** icons with countdown timers (absorb, HoT, evade, etc.).
- **Floating numbers:** `DamageNumbers` — damage (with crit), incoming damage, heals,
  misses, XP gains; billboard `Label3D` that faces the camera; per-category toggles in
  Options → Interface.
- **Spell book** (view known spells, memorize workflow) and **Hotbar** (signal-driven from
  `spell_cooldown_updated` / `skill_cooldown_updated`). Memorize is gated through `SpellBar`.
- **Multi-window chat:** `CombatLog` is a pure broker emitting `line_added(text, type)`;
  `ChatWindowManager` owns N `ChatWindow` instances (each a `DraggablePanel`). Per-window
  filters (by `MsgType`), display settings (bg/font alpha, font size, default channel), and
  tab docking (`group_id` groups windows; drag to dock/undock). Layout persists through
  `GameSettings.chat_windows`.
- **Settings:** keybinds, UI panel positions, and chat prefs persist to disk via
  `GameSettings`.

---

## Networking (client)

> The world simulation server is authoritative (renet UDP, 20 Hz); a `--local-save` dev path
> still exists for solo iteration. Read `server/docs/server_design.md` before touching anything
> here.

- `Network` / `Net` — connection + wire message routing.
- `SaveManager` — owns window-close. Two distinct exits (see the disconnect-lifecycle entry
  below): **Quit Game** is a clean save + app-layer `Disconnect`; the **window X button** is a
  hard self-kill that drives the server's linkdead path. (Watch the Godot-4 `_notification`-on-
  close save pitfall noted in past audits — close is handled via the root window's
  `close_requested` signal, not `_notification`.)
- **Disconnect lifecycle (clean vs linkdead):** how you leave the world decides whether the body
  reaps now or lingers. **Quit Game** (Options menu) sends an app-layer `Disconnect`, so the
  server reaps immediately and frees the account. The **window X button** is wired as a hard
  self-kill (`SaveManager._on_close_requested` → `OS.kill(OS.get_process_id())`, killing only
  that instance's PID) — it sends nothing, so the server treats it as an unclean drop and the
  character goes **linkdead**: the body lingers in-world ~30 s (`LINKDEAD_SECS`), still
  targetable and **killable** by mobs and PvP, frozen in place; a same-account relogin is refused
  ("You already have a character in this world.", with a `reconnect_after_secs` countdown) until
  it reaps. This is the EverQuest model and closes the log-off-to-escape / pull-the-plug exploits.
  Server side lives in `world/tick.rs` (`reap_connection` + the linkdead reaper sweep) and
  `world/connection.rs` (`linkdead_since` / `clean_disconnect`); detection costs up to the 10 s
  app-heartbeat or 15 s netcode timeout, so a hard crash is ~40-45 s end to end. See
  `docs/design/camp_and_linkdead.md`.
- **`/camp` (voluntary sit-gated logout, PD_W0017):** the deliberate mirror of linkdead. `/camp`
  (in `hud.gd::_handle_chat_input`) requires the player to be seated (`Combat.is_player_seated()`,
  else "You must be sitting to camp."); it sends `ClientWorldMsg::Camp`, the server gates on
  `is_sitting` and starts a `CAMP_SECS` (30 s) countdown (`camp_since`), confirming with
  `ServerWorldMsg::CampUpdate{remaining_secs, active}`. An amber "Making camp... N" HUD label counts
  down. The camp **cancels** if the player stands/moves or takes damage (the server's per-tick camp
  sweep checks `!is_sitting` or `last_damaged_at >= camp_since`, the latter set at the 5 player-damage
  sites; death also clears it) — on cancel it fans `CampUpdate{active:false}` and the label hides.
  **Completion is client-driven:** at 0 the client runs the same clean logout as Quit Game (a clean
  `Disconnect`; exits to desktop), and the server just stops tracking — there's no in-game
  return-to-lobby flow yet, so a server kick would strand the player. `/camp cancel` aborts it. The
  client also cancels its countdown locally on stand for responsiveness and resets the overlay on any
  disconnect. Server: `world/tick.rs` "5c camp sweep", `world/handlers.rs` (`Camp`/`CancelCamp`,
  `send_camp_update`), `world/connection.rs` (`camp_since`/`last_damaged_at`).
- `RemotePlayerManager`, `RemoteEnemyManager`, `RemoteLootBagManager`, `RemotePetManager` —
  spawn and update peer-owned entities from server broadcasts; each exposes a `get_by_id()`
  accessor used by the target-of-target resolver.
- `NetCombatBroadcaster` — relays local combat events onto the wire.
- **Incoming-attack combat-log feedback:** `RemotePlayerManager._on_hit` logs "X hits you
  for N." and `_on_miss` logs "X misses you." (added 2026-06-16) on the local player's
  combat log, for both enemy and PvP attackers (the server already fans `Hit`/`Miss` to the
  defender). Attacker naming (`_attacker_display_name`) reads the mob name for enemy ids and
  the peer name otherwise.
- **Pet PvP inheritance:** a player-owned pet inherits its owner's `/pvp` flag — it's only
  damageable when the attacker could attack the owner directly (`combat::can_attack(attacker,
  pet.owner)`; you can never damage your own pet). Gated on all three player→pet damage paths
  in `tick.rs`: melee, single-target spell, and AOE (the AOE arm now *includes* pets in its
  radius scan — they were previously excluded by the loot-bag id bound, so AOE hit no pets at
  all — and gates each by the same rule). World mobs (`entity.owner == None`) are always
  attackable.
- **Known gaps** (also in the root to-do): incoming `/tell`, the broader PvP-flagging design
  (when/how PvP is triggered + consequences), `RemotePet` friend/foe visual distinction.
  (ALLY-target buff routing and pet buffs both landed — see Spells & casting + Pets.)

## GM access + dev tooling

Dev/GM commands (`/give`, and the Test Panel's Full Heal / Level Up / Grant XP / Spawn / give-coins)
are gated **server-side** on `PerConnection::can_use_dev_cmds()` = `is_dev || is_gm`, so an untrusted
player can never use them (exploit-audit finding #1). Two independent grants:
- **`is_dev`** is process-wide, from the `PD_DEV_CMDS=1` env var (`connection.rs`
  `dev_cmds_enabled()`, cached in a `OnceLock`). Turns the WHOLE server into a dev box — for local
  solo iteration. Logged at boot as `dev_cmds=true/false`.
- **`is_gm`** is per-account (`accounts.is_gm`). Read at world-token mint (`db::account_is_gm`),
  packed into the signed connect token's `user_data[8]` (`mint_connect_token`), unpacked into
  `PerConnection.is_gm` at connect (`tick.rs::parse_is_gm_from_user_data`; logs `GM account
  connected`). A modified client can't forge it — the token is signed with the netcode key. This is
  what lets a HOSTED friends server run with `PD_DEV_CMDS` off while the host keeps their tools.
  Server-only (no client/DLL/wire change); built 2026-07-17, playtested + integration-tested
  2026-07-19 (`world_two_clients.rs::is_gm_gates_dev_commands`).
- Set the flag offline with the **`grant_gm`** bin (`cargo run -p projectdawn-server --bin grant_gm
  -- <username> on|off`; no args lists every account's GM status). Takes effect on that account's
  next login (the flag is read at token mint, so a live session must re-log).
- **Caveat — the Test Panel is a CLIENT tool** and mixes server-gated dev commands (above) with
  client-side helpers and legitimate actions. `_full_heal` fills the bars optimistically client-side
  even when the server refuses `HealSelf` for a non-GM (self-corrects on the next `HealthUpdate` — a
  display lie, not an actual heal). `_trigger_death` just sets local HP to 0 (dying is legitimate and
  never gated). So "Full Heal / Trigger Death work for a non-GM" is expected, not a gate leak.
- **`admin_report`** bin: read-only `world.db` viewer (accounts + characters incl. soft-deletes,
  per-char four-tier coins + bank + inventory) → console + a local `world_report.html`. WAL-aware
  (`?mode=ro`), safe to run while the server is live.
