# Handoff: factions and alignment, slice 1 (written 2026-10-23, for the next session)

The server half is BUILT and committed. The client half, the checklist and the records are
not. This document is the whole plan for finishing it at the standard the work so far was
held to. Read it top to bottom before touching anything; every step names its file, its
anchor and what "done" means. The design it implements is `docs/design/factions_and_alignment.md`
(all nine decisions in its section 6, the user's own words quoted there).

## 0. The rules this work runs under (not optional)

These are the user's standing rules, from `CLAUDE.md` and memory. They decide quality more
than any technique does.

1. **Say before doing.** State the plan and wait for the go before editing, always after a
   clarification. The exception is unattended work the user already asked for: finishing
   this build is that work (the user said "Lets rock and roll!" to slice 1), so proceed
   through section 4 without asking; stop and ask only at the decisions in section 3 if the
   user has not answered them by then.
2. **Research, never fabricate.** Every EQ or P99 claim in a comment, a doc or a chat line
   comes from a source read this session or named in the design doc's section 7. If a fact
   is not in a source, say "not sourced" rather than guess. The con phrases in
   `factions.rs::Con::phrase` are from the P99 wiki's Consider page (read 2026-10-23); do
   not add others from memory.
3. **Exploit vigilance, always.** Every change gets the question "what could a modified
   client do with this?" answered in its comment or its test. Dev tools stay dev-gated and
   audited; nothing the client sends decides an outcome.
4. **Writing:** no em-dashes, no left or right arrows, in code comments, docs, chat lines
   and replies. Plain words ("to", "then"). Terse replies to the user; no recaps of what you
   did unless asked.
5. **Verify in source before claiming.** Read the real function before saying what it does.
   A sub-agent's report is a lead, not a fact.
6. **The standard itself:** `docs/design/handoff_oct_15_next_builds.md` section 7 ("What
   Fable standard meant in practice"), section 5 (the recipe for one build) and section 6
   (the records pass, exact steps). This document follows that recipe; read those three
   sections first.

## 1. Where everything is

| Thing | Path | Branch | State |
|---|---|---|---|
| Server worktree | `F:\Projects\server-speed` | `feat/server-speed` | commit `5efd45d`, clean |
| Client worktree | `F:\Projects\Project_Dawn-speed` | `feat/server-speed` | untouched by this build |
| Docs, CLAUDE.md, planner | `F:\Projects\Project_Dawn` | `fix/xp-leveling-overflow` | this file is the only change |
| The rebuilt DLL | `F:\Projects\server-speed\target\release\gdext_net.dll` | | built 2026-10-23 11:18, 4,512,256 bytes, carries the new signals and sends; NOT yet copied into the client |
| Godot | `"F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe"` | | |
| The planner page | `https://claude.ai/artifact/8V2D15TKBpYd88miTmTfhM` | | version 52; regenerate with `python tools/schedule_detail.py` from `docs/schedule_detail.toml`, then republish to that URL |
| Next planner ids | `b30` (build), `v33` (verify), `d11` (decide) | | |

The Oct 22 bump (PD_W0028) has not shipped: `feat/server-speed` is unmerged into the deploy
branches, so the wire appends made here are free and the migration (0016) ships with the
merge. Nothing here reaches the R720 until that merge.

## 2. What is built on the server (commit `5efd45d`), so you do not rebuild it

Data: `data/factions.toml` (six factions, links, empty start tables); `data/zone_camps.toml`
(every `mob = {...}` carries `faction` and `alignment`); `data/npcs.toml` (`faction` per NPC;
the soul binder has one but is never gated); `data/quests.toml` (`faction_hits` and
`alignment_delta` on all nine); `data/spells.toml` (seven prestige spells appended at the
end, the client's numbers, `min_level = 1`).

Migration `migrations/0016_factions_and_alignment.sql`: `character_factions` and
`characters.alignment_seeded`. The `alignment_score` column has existed since 0001 as
`INTEGER NOT NULL DEFAULT 0`, never written; it is reused (SQLite keeps a fractional value in
it as a REAL) and read with `CAST(alignment_score AS REAL)` because sqlx refuses to decode an
INTEGER storage class as `f32`. `alignment_seeded` is what says "the server has seeded this
character" since 0 is a real score.

Modules: `src/world/factions.rs` (table, `Level`, `level_for`, `kill_hit`, `kill_hits`,
`start_modifier`, `shown_standing`, `apply_hit`, `change_line`, `con_line`, the level con:
`Con`, `blue_floor`, `con_for`, `mob_con_line`); `src/world/alignment.rs` (`Tier`,
`tier_for`, `starting_score`, `apply` with the momentum rule, `kill_delta`, `spell_sign`,
`spell_delta`, `effective_class`, `off_side_multiplier`, `penalise`).

Plumbing: `PerConnection` gained `factions`, `factions_dirty`, `alignment`,
`last_persisted_alignment`, `alignment_sent` and the helpers `faction_rows`,
`faction_standing` (personal), `faction_shown` (personal plus the start modifier),
`faction_level`, `npc_faction_level`, `npc_serves`, `npc_service`, `effective_class`.
`db/mod.rs`: `CharacterSpawn.alignment` / `.factions`, `load_factions`, `save_factions`,
`checkpoint_resources` takes the alignment, `create_character` seeds it. Saves ride the
checkpoint pass (`persistence.rs`) and the reap (`tick.rs`), the skills pattern.

Rules in `tick.rs`: `FactionKill::of(entity)` read at each of the three kill sites and passed
to `award_kill`, which pays the hits to every player on the mob's hate list (the union of the
`aggro` and `threat` maps) and the alignment delta to the kill creditor; quest accept and
turn-in refuse when the turn-in NPC's faction is Apprehensive or below ("X has nothing to say
to you."), the turn-in pays `faction_hits` (sorted) and `alignment_delta`; the two vendor
gates and five bank gates go through `conn.npc_service(kind)` and refuse at Dubious or below
("X will not deal with you.", naming the first refusing NPC in range); the cast site applies
`alignment::penalise` when `off_side_multiplier < 1.0`; the cast class gate, the memorize
gate (`spell_gems.rs`) and the skill class gate (`handlers.rs`) use `effective_class()`; a
cast moves alignment by `spell_delta` right after the mana comes off; entering the world
sends every moved standing (`send_factions_snapshot`) and the score
(`send_alignment_if_due(force)`). `handlers.rs`: `Consider` (an NPC answered in the handler by
id or display name via `npcs::lookup_by_id_or_name`; a mob goes to the tick as
`Outcome::ConsiderIntent`; anything else gets "You cannot consider that."), `DevSetFaction`
(gated and audited like `DevDespawnEnemies`, sets the sender's own standing, the slider
value is the SHOWN standing), `send_faction_update`, `apply_faction_hits`,
`send_factions_snapshot`, `send_alignment_if_due` (sends on a 0.01 move or a tier crossing,
so a cast alone fans nothing), `move_alignment`. Dev spawns of a camp-named mob inherit the
camp's faction and alignment (`zones::faction_of_camp_mob`) so the Test Panel can test hits.

Wire (`crates/protocol/src/world.rs`, PD_W0028 note extended): `ClientWorldMsg::Consider
{ npc_id: Option<String>, target_id: Option<EntityId> }` and `DevSetFaction { faction_id,
standing }` after `StopSong`; `ServerWorldMsg::FactionUpdate { faction_id, name, standing,
level: u8 }` and `AlignmentUpdate { score }` after `SkillFail`. DLL
(`crates/gdext-net/src/lib.rs`): signals `faction_update(faction_id, name, standing: f64,
level: i64)` and `alignment_update(score: f64)`; `#[func] send_consider(npc_id: GString,
target_id: i64)` ("" and 0 for none) and `send_dev_set_faction(faction_id, standing: f64)`.

Tests: unit tests in both modules (13 pass under `cargo test --lib -- factions alignment`);
five integration tests at the end of `tests/world_two_clients.rs`
(`a_kill_pays_faction_hits_to_the_hate_list_and_moves_alignment`,
`a_quest_turn_in_pays_its_hits_and_a_shunned_npc_refuses`,
`a_plain_account_cannot_set_faction_and_a_consider_names_no_standing`,
`a_paladin_at_evil_casts_the_fallen_kit_and_not_the_paladins`,
`a_neutral_paladin_casts_at_seventy_percent`), with harness sends `send_consider`,
`send_dev_set_faction`, `send_accept_quest`, `send_complete_quest`. Suite at the commit: 323
unit, 133 of 134 integration. **The one failure, `pet_pulls_aggro_via_threat_reaggro`, fails on
the branch WITHOUT this commit too** (checked by stashing the work and running it on the clean
tree: it fails at the same assertion, "enemy re-targets onto the pet"). It is a pre-existing
break on `feat/server-speed`, most likely from the parity pass (a level 6 Necromancer now has
far fewer hit points and a Decrepit Skeleton 16, so the fight may end before the retarget).
The project's rule is that any failure is real: root-cause it as its own small task, not as
part of this build, and record it in the parity entry of the To-Do.

## 3. Calls made while building, to put in front of the user in the records

Each is in the code with its reason; the user has not seen them. List them in the session
note and the To-Do entry so the user can overrule any.

1. The hate list is the union of the mob's `aggro` (damage) and `threat` maps: a swing that
   missed (one point of threat) counts, as EQ's did. The design said "hate list" without
   naming the maps.
2. The kill's alignment delta goes to the kill creditor (top damager) only, not the group.
   The design did not say; EQ has no alignment.
3. The con line is two sentences ("Brom regards you indifferently. Looks like an even
   fight."), not EQ's " -- " join, by the writing rule. The level phrases are one per colour
   from the P99 page's lowest band (levels 1 to 6); the colour bands follow the page's table
   (blue reaches 3 below at levels 1 to 12, 4 at 13 to 17, then one more every four levels).
   The page's higher bands vary the wording; not built.
4. A Consider names an NPC by display name: the client's NPC nodes carry no server id
   (`npc_name` / `vendor_name` / `banker_name` exports in `world.tscn`), so the server
   resolves by id or by name, case-insensitive. Note the vendor nodes' `vendor_name` is
   "Elara — General Merchant" style; the `/con` command must prefer `npc_name` (see 4.4).
5. `AlignmentUpdate` fans on a move of 0.01 or a tier crossing, never per cast.
6. The vendor refusal names the first refusing NPC in range (Brom at the spawn).
7. The quest ACCEPT gate uses the quest's `turn_in_npc` as its giver (every quest's giver is
   its turn-in NPC today).
8. Stored standing is the personal number; what NPCs see is personal plus the start
   modifier (empty tables, so equal in v1); `DevSetFaction` sets the shown value.
9. Not built, flagged: a one-per-tick budget on `Consider` (the hosting branch's intent
   budgets should list `Consider` and `DevSetFaction` when `feat/public-hosting` merges);
   coloured con lines; conning players; a Consider keybind; the "Breastplate of Indifference".
10. The user asked (2026-10-23, mid-build) for the consider command as a tracked To-Do item:
    "This is 1000% a mechanic we need in Project Dawn. Please add it to the list." The
    `/con` command below is the first piece; the To-Do entry (section 5) carries the rest
    (the full P99 band table, coloured lines, the XP tiers light blue and green carried).

## 4. The remaining steps, in order

### 4.1 The DLL into the client

```
cp "F:\Projects\server-speed\target\release\gdext_net.dll" "F:\Projects\Project_Dawn-speed\addons\gdext_net\gdext_net.dll"
```

If any protocol or DLL source changes after this, rebuild first:
`RUSTFLAGS="-C target-feature=+crt-static" cargo build -p gdext-net --release` in
`F:\Projects\server-speed`. The build stamp fingerprints the DLL, so a stale copy presents as a
server bug; `tools/check_wire_layer.gd` (4.5) is the check.

### 4.2 `autoloads/net.gd` (client worktree)

Three edits, each mirroring the `skill_fail` / `stop_song` pattern already in the file.

(a) After `signal world_skill_fail(skill_name: String, reason: String)`:

```gdscript
# Factions and alignment (2026-10-23): one of our standings as the server
# holds it (the number the faction's NPCs see and its con level, 0 Scowls to
# 8 Ally), on entering the world, after every change and after a GM set; and
# our alignment score, on entering and whenever it has moved a hundredth of a
# point or crossed a tier. Alignment and factions FOLLOW these; nothing on
# the client moves either.
signal world_faction_update(faction_id: String, name: String, standing: float, level: int)
signal world_alignment_update(score: float)
```

(b) In `_ready`, after the `skill_fail` connect block (before
`loot_granted.connect(_on_loot_granted)`):

```gdscript
	# By name as well: an older DLL costs factions and the server's alignment
	# on screen (the standings and the score then never arrive), not the client.
	if has_signal("faction_update"):
		connect("faction_update", _on_faction_update)
	else:
		DebugLog.error("Net: gdext_net.dll predates factions (no faction_update "
			+ "signal); rebuild the DLL with addons/gdext_net/build.ps1.")
	if has_signal("alignment_update"):
		connect("alignment_update", _on_alignment_update)
	else:
		DebugLog.error("Net: gdext_net.dll predates server alignment (no alignment_update "
			+ "signal); rebuild the DLL with addons/gdext_net/build.ps1.")
```

(c) After `func stop_song()`:

```gdscript
func _on_faction_update(faction_id: String, name: String, standing: float, level: int) -> void:
	world_faction_update.emit(faction_id, name, standing, level)

func _on_alignment_update(score: float) -> void:
	world_alignment_update.emit(score)

# Consider an NPC (by its display name; "" for none) or a mob (by entity id;
# 0 for none): the server answers with EQ's con line on the System channel.
# By name: an older DLL costs the command, not the client.
func consider(npc_name: String, target_id: int) -> bool:
	return _state == State.CONNECTED_APP and has_method("send_consider") \
			and bool(call("send_consider", npc_name, target_id))

# The GM faction panel's slider: our OWN standing with one faction, set to an
# absolute value. GM-only and audited on the server; a plain account's
# request is ignored there, so the client never pretends it worked.
func dev_set_faction(faction_id: String, standing: float) -> bool:
	return _state == State.CONNECTED_APP and has_method("send_dev_set_faction") \
			and bool(call("send_dev_set_faction", faction_id, standing))
```

### 4.3 `tools/check_wire_layer.gd`

Add `"faction_update", "alignment_update"` to `SIGNALS` and `"send_consider",
"send_dev_set_faction"` to `METHODS`.

### 4.4 `autoloads/alignment.gd`, rewritten as the follower

Replace the file with this (keeps every public name the rest of the client uses:
`alignment_changed`, `alignment_score`, `alignment_tier`, `set_alignment`,
`modify_alignment`, `get_effective_class`, `save_state`, `load_state`; `spells.gd`,
`skills.gd` and `crafting_window.gd` listen to `alignment_changed` and re-setup the kit, which
is how the prestige swap reaches the hotbar):

```gdscript
extends Node
# Alignment and faction standings, the server's since the factions build
# (docs/design/factions_and_alignment.md, 2026-10-23). Online this autoload
# FOLLOWS the server: the score arrives as AlignmentUpdate and every moved
# standing as FactionUpdate; nothing here moves either by itself. The tiers
# and the class starts mirror the server's alignment.rs (kept in lockstep by
# hand); the offline Test Room still seeds from the class start.

signal alignment_changed(tier: String, score: int)
# One faction standing as the server holds it: the number the faction's NPCs
# see and its con level (0 Scowls to 8 Ally).
signal faction_changed(faction_id: String, name: String, standing: float, level: int)

const LEVEL_NAMES := ["Scowls", "Threatening", "Dubious", "Apprehensive",
	"Indifferent", "Amiable", "Kindly", "Warmly", "Ally"]

var alignment_score: int = 0
var alignment_tier: String = "Neutral"
# The server's exact score; the tier reads it, so a boundary falls as the
# server's does and not as a rounded integer would.
var exact_score: float = 0.0
# faction_id to {"name": String, "standing": float, "level": int}, only the
# factions the server has told us about (the rest sit at Indifferent).
var factions: Dictionary = {}

func _ready() -> void:
	Net.world_alignment_update.connect(_on_server_alignment)
	Net.world_faction_update.connect(_on_server_faction)
	Net.app_connected.connect(_on_app_connected)

# Entering the world, possibly as a different character, which must not
# inherit the last one's standings; the server sends every moved standing
# right after this.
func _on_app_connected(_player_id: int) -> void:
	factions.clear()

func set_alignment(score: float) -> void:
	exact_score = clampf(score, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	alignment_tier = _calc_tier()
	alignment_changed.emit(alignment_tier, alignment_score)

func modify_alignment(delta: float) -> void:
	exact_score = clampf(exact_score + delta, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	var new_tier := _calc_tier()
	if new_tier != alignment_tier:
		alignment_tier = new_tier
		alignment_changed.emit(alignment_tier, alignment_score)

func _on_server_alignment(score: float) -> void:
	var old_tier := alignment_tier
	exact_score = clampf(score, -2000.0, 2000.0)
	alignment_score = roundi(exact_score)
	alignment_tier = _calc_tier()
	DebugLog.info("Alignment: server score %.4f (%s)" % [exact_score, alignment_tier])
	if alignment_tier != old_tier:
		alignment_changed.emit(alignment_tier, alignment_score)

func _on_server_faction(faction_id: String, name: String, standing: float, level: int) -> void:
	factions[faction_id] = {"name": name, "standing": standing, "level": level}
	DebugLog.info("Faction: %s %d (%s)" % [name, roundi(standing), faction_level_name(level)])
	faction_changed.emit(faction_id, name, standing, level)

func faction_level_name(level: int) -> String:
	return LEVEL_NAMES[clampi(level, 0, LEVEL_NAMES.size() - 1)]

func _calc_tier() -> String:
	if exact_score >= 1500.0:
		return "Exalted"
	elif exact_score >= 300.0:
		return "Good"
	elif exact_score >= -300.0:
		return "Neutral"
	elif exact_score >= -1500.0:
		return "Bad"
	else:
		return "Evil"

func get_effective_class() -> String:
	match PlayerStats.player_class:
		"Paladin":
			if alignment_tier == "Evil":
				return "Paladin_Fallen"
		"Shadow Knight":
			if alignment_tier == "Exalted":
				return "Shadow Knight_Redeemed"
	return PlayerStats.player_class

func save_state() -> Dictionary:
	return {"alignment_score": exact_score}

func load_state(d: Dictionary) -> void:
	set_alignment(float(d.get("alignment_score", 0)))
```

Check: `player_stats.gd:170` calls `Alignment.set_alignment(CharacterData.CLASS_STARTING_ALIGNMENT.get(cls, 0))`
(an int; fine). `spells.gd:48` and `skills.gd:18` connect `alignment_changed` and re-run
`setup_for_class` on it: read both handlers once to confirm nothing else is assumed.

### 4.5 `data/faction_definitions.gd` (new) and `tools/check_faction_lockstep.gd` (new)

The six ids and names, for the Test Panel's sliders before the server has said anything.
Header style: `class_name FactionDefinitions` then a comment, as `named_mob_definitions.gd`.

```gdscript
class_name FactionDefinitions

# The world's factions, mirrored from the server's data/factions.toml: ids
# and display names only (the links and the hits live on the server; the
# client learns its standings from FactionUpdate). Kept in lockstep by
# tools/check_faction_lockstep.gd. The Test Panel's GM faction sliders are
# built from this list before the server has said anything.
const ALL := [
	{"id": "greyveil_town",  "name": "The Folk of Greyveil"},
	{"id": "greyveil_watch", "name": "The Greyveil Watch"},
	{"id": "gnoll_raiders",  "name": "The Gnoll Raiders"},
	{"id": "bandits",        "name": "The Road Bandits"},
	{"id": "restless_dead",  "name": "The Restless Dead"},
	{"id": "wildlife",       "name": "Wildlife"},
]
```

The check, the `check_item_lockstep.gd` shape (`extends SceneTree`, `_initialize`, `quit(2)`
when the file is unreadable, `quit(1)` on drift, `quit(0)` clean), parsing only `[[faction]]`
blocks' `id = "..."` and `name = "..."` lines, default path
`F:/Projects/server/crates/projectdawn-server/data/factions.toml` with the worktree's path
accepted as `-- <path>`. Compare both ways (server-only, client-only, name drift). Run:

```
"F:\GODOT Engine\Godot_v4.4.1-stable_win64.exe\Godot_v4.4.1-stable_win64.exe" --headless --path F:\Projects\Project_Dawn-speed -s tools/check_faction_lockstep.gd -- F:/Projects/server-speed/crates/projectdawn-server/data/factions.toml
```

Add it to `docs/reference/commands.md` beside the other lockstep checks.

### 4.6 `scripts/hud.gd`: `/con` and `/factions`

Insert before `if lower == "/stopsong":` (inside the same command function):

```gdscript
	if lower == "/con" or lower == "/consider":
		# EQ's consider (factions, 2026-10-23): the server answers with how the
		# target's faction regards you and, for a mob, how its level reads
		# against yours. An NPC is named by its display name (the client holds
		# no server ids for NPCs; the server resolves the name), a mob by its
		# entity id. The server decides everything; this only asks.
		if not Net.is_launcher_mode() or not Net.is_app_ready():
			CombatLog.add_line("There is nothing to consider offline.", CombatLog.MsgType.INFO)
			return
		var target = Combat.current_target
		if not is_instance_valid(target):
			CombatLog.add_line("You must target something to consider it.", CombatLog.MsgType.INFO)
			return
		var npc_name := _npc_display_name(target)
		var entity_id := 0 if npc_name != "" else Combat.target_server_id(target)
		if npc_name == "" and entity_id == 0:
			CombatLog.add_line("You cannot consider that.", CombatLog.MsgType.INFO)
			return
		if not Net.consider(npc_name, entity_id):
			CombatLog.add_line(
				"This build's gdext_net.dll predates /con (rebuild it with addons/gdext_net/build.ps1).",
				CombatLog.MsgType.INFO)
		return

	if lower == "/factions":
		# Every standing the server has told us: only the factions a kill, a
		# quest or the GM panel has moved; the rest sit at Indifferent.
		if Alignment.factions.is_empty():
			CombatLog.add_line("You have moved no faction's standing yet.", CombatLog.MsgType.INFO)
			return
		var ids: Array = Alignment.factions.keys()
		ids.sort()
		for id in ids:
			var f: Dictionary = Alignment.factions[id]
			CombatLog.add_line("%s: %d (%s)" % [f["name"], roundi(f["standing"]),
				Alignment.faction_level_name(int(f["level"]))], CombatLog.MsgType.INFO)
		return
```

And a helper at the end of the file. `npc_name` first: the vendor and banker nodes' other
exports are "Elara — General Merchant" style, which the server would not match.

```gdscript
# The display name an NPC node carries, for /con (the client holds no server
# ids for NPCs). `npc_name` first: the vendor and banker labels carry a role
# after a dash that npcs.toml does not.
func _npc_display_name(node) -> String:
	if not is_instance_valid(node):
		return ""
	for key in ["npc_name", "vendor_name", "banker_name"]:
		if key in node and String(node.get(key)) != "":
			var n := String(node.get(key))
			var dash := n.find(" — ")
			return n.substr(0, dash) if dash >= 0 else n
	return ""
```

Verify the `world.tscn` names against `npcs.toml` before trusting this: `npc_name` is set for
Elara, Brom, Aldric the Guard and Sister Maelis; Thalia only has `banker_name = "Thalia Mourne —
Banker"` and Hadrik only `vendor_name = "Hadrik — Blacksmith"`, so the dash trim is what
makes those two resolve. The server's names: Brom, Aldric the Guard, Sister Maelis, Thalia
Mourne, Elara, Hadrik.

### 4.7 `scripts/test_panel.gd`: the GM faction panel

Add `var _sec_factions: VBoxContainer` beside the other `_sec_*` vars, `_sec_factions =
_make_section("FACTIONS (GM)")` after `_sec_combat = ...` in `_build_ui`, and
`_build_factions_section()` after `_build_combat_section()` there. Then:

```gdscript
# The GM faction panel (user, 2026-10-23): one slider per faction, setting
# the GM's OWN standing with it to an absolute value through DevSetFaction,
# which is GM-only and audited on the server (a plain account's request is
# ignored there). The labels follow the server's FactionUpdate, so the panel
# shows the true standing after every kill and quest too. Online only: the
# offline Test Room has no factions.
var _faction_labels: Dictionary = {}
var _faction_sliders: Dictionary = {}

func _build_factions_section() -> void:
	_sec_factions.add_child(_make_label("Your standing (GM only, online)"))
	for f in FactionDefinitions.ALL:
		var id: String = f["id"]
		var lbl := _make_label("%s: ?" % f["name"])
		_sec_factions.add_child(lbl)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		var slider := HSlider.new()
		slider.min_value = -2000
		slider.max_value = 2000
		slider.step = 10
		slider.value = 0
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(slider)
		var set_btn := _make_btn("Set", C_BORDER)
		set_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
		set_btn.custom_minimum_size.x = 40
		set_btn.pressed.connect(_set_faction.bind(id, slider))
		row.add_child(set_btn)
		_sec_factions.add_child(row)
		_faction_labels[id] = lbl
		_faction_sliders[id] = slider
	Alignment.faction_changed.connect(_on_faction_changed)

func _set_faction(id: String, slider: HSlider) -> void:
	if not (Net.is_launcher_mode() and Net.is_app_ready()):
		CombatLog.add_line("TestPanel: factions exist online only.", CombatLog.MsgType.INFO)
		return
	if not Net.dev_set_faction(id, slider.value):
		CombatLog.add_line("TestPanel: this build's wire layer cannot set factions.",
			CombatLog.MsgType.INFO)

func _on_faction_changed(id: String, name: String, standing: float, level: int) -> void:
	if _faction_labels.has(id):
		_faction_labels[id].text = "%s: %d (%s)" % [name, roundi(standing),
			Alignment.faction_level_name(level)]
	if _faction_sliders.has(id):
		_faction_sliders[id].set_value_no_signal(standing)
```

The Test Panel's `NORMAL_MOBS` names "Rat", "Bandit", "Grey Wolf", "Skeleton", "Gnoll": only
"Grey Wolf" matches a camp template, so only it carries a faction on a dev spawn. Either
rename the others to camp names ("Plague Rat", "Bandit Scout", "Decrepit Skeleton", "Gnoll
Raider") or note in the checklist that the GM tests hits on a Grey Wolf; renaming is better
and is a one-line data edit per row (keep the numbers).

### 4.8 The headless checks and probe

Run from the client worktree, all must exit 0:

- `tools/check_wire_layer.gd` (every signal and method OK against the copied DLL).
- `tools/check_faction_lockstep.gd` (6 and 6, no drift).
- `tools/check_spell_lockstep.gd -- F:/Projects/server-speed/crates/projectdawn-server/data/spells.toml`:
  the seven prestige spells were client-only and are now shared, so the count moves from
  "142 shared, 16 client-only" to 149 shared and 9 client-only, with ZERO drift. Any drift
  on them means a number was copied wrong into `spells.toml`; fix the TOML, not the client.
- A headless probe for the client half, the pattern the earlier builds used (look at how the
  2026-10-20 session note describes its probe and where that script lives; if none is
  committed, write `tools/probe_factions.gd` as a `SceneTree` script that instantiates the
  autoloads it needs, feeds `Alignment._on_server_alignment(-1600.0)` and checks the tier
  and `get_effective_class()` for a Paladin, feeds a `FactionUpdate` and checks
  `faction_level_name`, and exits 1 on any miss).

### 4.9 The checklist: `docs/playtest_notes/factions_checklist.md`

From `docs/playtest_notes/TEMPLATE_checklist.md` (numbered sections of
`- [ ] **action** -> expected result. notes:` rows; keep the per-row `notes:` hooks). Prerequisite
line: the merged Oct 22 build on both sides (migration 0016 runs at boot; an older binary
will not boot afterwards). Sections and rows:

1. Entering the world: `/factions` says none moved; the debug console shows
   "Alignment: server score 400.0000 (Good)" for a Cleric and -1600 for a Necromancer; the
   character sheet's tier matches.
2. A kill: Grey Wolf (wildlife): "Your faction standing with Wildlife has gotten worse."
   and nothing else; a Gnoll Raider: gnolls worse, the town AND the Watch better; a group
   mate who only healed during the kill gets the same three lines; a named mob's hit is
   three times a plain one's (`/factions` before and after).
3. Quests: turning in wolf_threat prints the Watch and the town lines; `/factions` shows
   +25 and +10; a second account that watched the turn-in gets nothing.
4. `/con`: Brom "regards you indifferently."; a Grey Wolf at level 1 "looks like an even
   fight."; a Gnoll Brute at level 1 "What would you like your tombstone to say?"; a wolf at
   level 10 "Looks like a reasonably safe opponent."; with no target the local refusal; a
   player target "You cannot consider that."
5. The GM panel: the slider sets the town to -50: "Your standing with The Folk of Greyveil is
   now -50 (Apprehensive)."; Brom's dialogue offers no quest (the accept is refused with
   "Brom has nothing to say to you." and the journal rolls back) while his shop still sells;
   at -200 the shop refuses "Brom will not deal with you." and so does the banker; at 600
   Brom "kindly considers you."; a relog keeps the number; a plain (non-GM) account's panel
   does nothing and prints nothing from the server (`server.log` shows no
   `GM set own faction standing` line for it).
6. Alignment and the prestige kit: a Paladin set to Evil (needs a direct DB write today,
   `UPDATE characters SET alignment_score = -1600, alignment_seeded = 1 WHERE id = ?`, there
   is no GM tool; say so in the row) relogs with the Fallen kit on the book and the hotbar,
   casts Death's Embrace, cannot memorize or cast Righteous Fire; a Paladin at 0 heals and
   nukes at 70% of the listed number (Crusader's Mend 7, Righteous Fire 4).
7. Persistence and the log: `/factions` after a relog matches before; `server.log` carries
   `faction standing changed` with delta, applied and level for every hit, and
   `alignment tier changed` when a tier flips.

Diagnostics to name in the header: the in-game console lines above; `server.log` anchors
`faction standing changed`, `quest turn-in rejected — faction`, `BuyItem rejected — faction`,
`bank op rejected — faction`, `GM set own faction standing`, `alignment tier changed`.

### 4.10 The records pass (all in `F:\Projects\Project_Dawn`, deploy branch)

Follow `handoff_oct_15_next_builds.md` section 6 exactly. The specifics:

1. **CLAUDE.md, the "Faction system" entry** (World systems): append a `**BUILT 2026-10-23,
   pending the Oct 22 bump and the playtest**` block in the house style (server sha `5efd45d`
   plus the client sha once committed; `factions_checklist.md`, row count; what exists, in
   the words of section 2 above; the calls of section 3; tests; the hosting-branch note; the
   pre-existing pet test failure named as not this build's). Also the "Client-decided
   outcomes" entry (Security): item 6's alignment is BUILT (point at the Faction entry);
   fall damage is the last open part.
2. **CLAUDE.md, a new entry under UI polish or Combat** for the consider command, in the
   user's words ("This is 1000% a mechanic we need in Project Dawn. Please add it to the
   list.", 2026-10-23): what exists (`/con`, the faction phrase plus one level phrase per
   colour, the colour bands from the P99 page) and what is open (the full per-band phrase
   table, coloured chat lines, a keybind, conning players, whether the con tiers decide XP
   as EQ's light blue and green did, which is a design call).
3. **Session note** `docs/session_notes/session_2026_10_23.md`: a section 2 "Factions and
   alignment slice 1 built", in the style of section 1 there (what was built, the calls, the
   traps of section 6 below, the suite numbers, the pet test finding). Add the row to
   `docs/session_notes/README.md`.
4. **Planner**: `docs/schedule_detail.toml` gains a build row `b30` (lane "build", week by
   the date, "Claude unattended", days 2, `todo = "Faction system"`, done_when "both halves
   pushed and factions_checklist.md filled") and a verify row `v33` (lane "verify", "user
   at a desk, GM account", hours 1, `needs = ["the Oct 22 export"]`, `checklist =
   "factions_checklist.md"`, `waits_on = ["b30", "o4"]`); the `[[after]]` entry that begins
   "Factions and alignment, slice 1" loses slice 1 (keep "Then guards that fight and
   attackable NPCs" as the after-strip text). Then `python tools/schedule_detail.py`, commit
   the toml with both generated outputs, republish `docs/schedule_detail.html` to the
   planner URL in section 1 (the Artifact tool, `url` = that link, after an
   `action: "read"` of it).
5. **Handoff doc** `docs/design/handoff_oct_15_next_builds.md`: the progress lines near
   "Next planner ids" (now `b31`, `v34`, `d11`) and a line that factions slice 1 is built.
6. **`docs/reference/commands.md`**: `/con` (or `/consider`), `/factions`, the faction
   lockstep check, and `DevSetFaction` under the dev tools.
7. **The design doc** `docs/design/factions_and_alignment.md`: a short "Built" note at the
   top of section 4.7 pointing at the shas and this handoff.
8. **`server/docs/server_design.md`** (in the server worktree): the PD_W0028 message list
   gains the four messages; migration 0016 in the migrations list.
9. Memory: nothing new unless the user gives a rule.

### 4.11 Commits and pushes

- Client worktree: one commit, "Factions and alignment, slice 1, the client half: ..." with
  the DLL copy included (it is gitignored? check `git status`; the DLL is hand-copied and
  gitignored by the note in CLAUDE.md, so it travels only in the export), then
  `git push origin feat/server-speed`.
- Server worktree: `git push origin feat/server-speed` (commit `5efd45d` is local only).
- Docs: one commit on `fix/xp-leveling-overflow`, then `git push origin fix/xp-leveling-overflow`
  (pushing the branch BY NAME; the client's `master` is a stale default).
- Every commit message ends with the attribution line the session reminder gives.

## 5. The quality bar, applied to this build

- A test for every rule, written to fail on the previous code (the five integration tests
  do; say so in each doc comment, as they do).
- Every refusal line and every log line is quoted exactly in the checklist, so a tester's
  "didn't work" can be split client versus server from `server.log`.
- The records never say "done": built and pending playtest until a filled checklist row says
  otherwise (CLAUDE.md, Session workflow step 6).
- Numbers in docs come from the code or the log, never from memory: the hit sizes (4 +
  level, x3 named), the thresholds, the 0.7 and 0.4, the 400 and -1600 seeds, the 0.01 send
  rule, 323 and 133 of 134.
- Flag, never hide: every call in section 3 goes in the To-Do entry under "flagged, not
  decided".

## 6. Traps met this session, so they cost you nothing

- **A dev spawn's `EnemySpawn` is not the first `EnemySpawn` of that name.** The enter-world
  seed carries the camps' mobs (a Grey Wolf camp sits 38 m from the spawn), so a test
  matching on `mob_name` alone caught a camp mob and then cast at it from too far. Match on
  `pos.x.abs() < 6.0 && pos.z.abs() < 6.0` as the factions tests do.
- **The server drops a client silent for 10 s.** A second client that sits unpumped while the
  first runs a chain of casts with cooldown waits gets reaped; interleave
  `pump_alive_for` on both (`a_breath_for_two`).
- **Smite's own cooldown is 3 s, longer than the 2 s global one**; wait 4.2 s between casts
  (`a_breath`). A level 1 caster has about 17 mana, one Smite; `set_char_level(db, id, 20)`
  before the first connect for more.
- **A GM token must be minted after `set_account_gm`**; the token from `provision_client`
  predates the flag.
- **`cargo test --lib factions alignment` fails to parse; it is `cargo test --lib -- factions
  alignment`.** A heredoc with Python inside the Bash tool tripped on quotes once; write edit
  scripts to the scratchpad and run them by path.
- **`characters.alignment_score` is INTEGER affinity from 0001**; read it with `CAST(... AS
  REAL)` or sqlx refuses the `f32`.
- **`pet_pulls_aggro_via_threat_reaggro` fails on the branch before this work** (section 2).
  Do not spend the build chasing it; file it under the parity entry.
- The client's NPC nodes have no server id; vendor and banker labels carry a role after a
  dash (section 4.6).
