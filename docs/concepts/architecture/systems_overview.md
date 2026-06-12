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

- **PlayerStats** owns HP/MP/stamina, STR/AGI/INT/WIS/CON(/CHA), level, XP, race/class,
  bind point.
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
  worn equipment (`ItemData.weight`, default 0; most items untagged pending a content
  pass). Over capacity: movement slows linearly to a 0.25 floor (applied after the
  mount mult in `player.gd`) and stamina regen halves (stops at 2× capacity, in
  `regen.gd`); "You are encumbered!" CombatLog line on threshold crossings.
  Client-side v1 — the server's movement clamp picks up the slowdown via the scaled
  direction vector; no server-side weight model yet. No weight readout UI yet
  (character-window line is the natural follow-up).

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
- **Quests:** `QuestManager` (ACTIVE/COMPLETED/FAILED, objectives, signals) +
  `data/quest_definitions.gd`. Kill tracking is automatic via `notify_kill()` in
  `enemy._die()`. `complete_quest()` delivers XP + item rewards through `Inventory`.
  Journal: `scripts/quest_journal.gd` (J key; Active/Completed tabs).
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

> The world simulation server is not built yet; the client runs **local-save** until it
> lands. Read `server/docs/server_design.md` before touching anything here.

- `Network` / `Net` — connection + wire message routing.
- `SaveManager` — local persistence today; server-authoritative once the world server is
  online. (Watch the Godot-4 `_notification`-on-close save pitfall noted in past audits.)
- `RemotePlayerManager`, `RemoteEnemyManager`, `RemoteLootBagManager`, `RemotePetManager` —
  spawn and update peer-owned entities from server broadcasts; each exposes a `get_by_id()`
  accessor used by the target-of-target resolver.
- `NetCombatBroadcaster` — relays local combat events onto the wire.
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
