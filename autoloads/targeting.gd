extends Node

var _tab_index := 0
var _camera: Camera3D = null
var _player: Node3D = null

func register_camera(cam: Camera3D) -> void:
	_camera = cam

func register_player(node: Node3D) -> void:
	_player = node

func unregister_player() -> void:
	_player = null

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.is_action("target_cycle"):
		_cycle_target()
		return
	# F2–F6 → group members 1–5 (F1/self is handled in the HUD).
	for slot in range(1, 6):
		if event.is_action("target_group_%d" % slot):
			_target_group_slot(slot)
			return

# Target the Nth (1-based) other member of the group, in roster order. Our
# combat targeting is node-based, so a member who isn't loaded in-zone (no
# RemotePlayer node) can't be targeted — we say so rather than silently fail.
func _target_group_slot(slot: int) -> void:
	if not GroupManager.in_group:
		return
	var self_id := Net.get_player_id()
	var others: Array = []
	for m in GroupManager.members:
		var pid: int = int(m.get("peer_id", 0))
		if pid != 0 and pid != self_id:
			others.append(pid)
	if slot < 1 or slot > others.size():
		return
	var node := RemotePlayerManager.get_by_id(others[slot - 1])
	if node == null or not is_instance_valid(node):
		CombatLog.add_line("That group member is not nearby.", CombatLog.MsgType.INFO)
		return
	Combat.set_target(node)

# Select whatever is under `mouse_pos` (viewport coords). Called by the local
# player on a clean left-click — a left *drag* orbits the camera instead, so the
# player script owns the click-vs-drag split and forwards only true clicks here.
func click_target(mouse_pos: Vector2) -> void:
	var camera := _camera
	if camera == null:
		return
	var space := camera.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(mouse_pos)
	var end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = true
	var result := space.intersect_ray(params)
	if result.is_empty():
		Combat.set_target(null)
		return
	var body = result["collider"]
	if body.is_in_group("enemies") and not body.is_dead:
		Combat.set_target(body)
	elif body.is_in_group("remote_players") and not body.is_dead:
		Combat.set_target(body)
	elif body.is_in_group("pets") or body.is_in_group("remote_pets"):
		# Targeting own/remote pets is allowed — useful for inspecting
		# pet HP on the target frame and as a base for buff/heal target
		# resolution. Combat.can_attack still gates whether a pet is a
		# legal hostile target (it isn't, by default).
		Combat.set_target(body)
	elif body.is_in_group("vendor_npcs") or body.is_in_group("dialogue_npcs") or body.is_in_group("banker_npcs"):
		Combat.set_target(body)
	elif body is LootBag:
		# PD_W0027 — the user's grammar: corpses stay right-click to loot,
		# but a lone item sitting on the ground is grabbed by LEFT-click and
		# rides the cursor until placed.
		_try_ground_pickup(body)
	elif body is Area3D:
		pass  # other interactables — let their own input_event handle it
	else:
		Combat.set_target(null)

func _cycle_target() -> void:
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	enemies = enemies.filter(func(e): return is_instance_valid(e) and not e.is_dead)
	if enemies.is_empty():
		Combat.set_target(null)
		return
	enemies.sort_custom(func(a, b):
		if not is_instance_valid(_player):
			return false
		return _player.global_position.distance_to(a.global_position) < _player.global_position.distance_to(b.global_position)
	)
	if Combat.current_target == null or not enemies.has(Combat.current_target):
		_tab_index = 0
	else:
		_tab_index = (enemies.find(Combat.current_target) + 1) % enemies.size()
	Combat.set_target(enemies[_tab_index])


# ── Right-click world interact ────────────────────────────────────────────────
# Interaction ranges. Mirror the old F-key values from hud.gd exactly, so
# moving the verb to the mouse changed no distances.
const INTERACT_RANGE_NPC := 6.0
const INTERACT_RANGE_LOOT := 6.0
const INTERACT_RANGE_GATHER := 3.0

# PD_W0027 — left-click ground pickup. The client pre-gates only what it can
# see honestly (range, its own held state, the obvious multi-stack case) so
# the common refusals answer instantly; the server re-checks everything —
# rights, the round-robin turn, coin, the real cursor state.
func _try_ground_pickup(bag: LootBag) -> void:
	if not Net.is_launcher_mode() or bag.bag_id < 0:
		return  # Test Room bags keep the right-click loot window only
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if bag.global_position.distance_to(player.global_position) > INTERACT_RANGE_LOOT:
		CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
		return
	if Inventory.cursor_slot != null:
		CombatLog.add_line("You're already holding something.", CombatLog.MsgType.INFO)
		return
	if bag.items.size() != 1 or bag.has_coins():
		CombatLog.add_line("There's more than one thing there. Right-click to loot.", CombatLog.MsgType.INFO)
		return
	Net.broadcast_loot_to_cursor(bag.bag_id)

## Resolve a right-click TAP into a world interaction. This is the world half
## of the game's one mouse grammar — right-click = use/interact, left-click =
## target — matching what the inventory has always done. Deliberately requires
## the cursor to be ON the object: the old F-key path interacted with anything
## nearby with no cursor work at all, which made it trivially bottable.
##
## Only a tap lands here; a right-DRAG is the camera and is filtered out by the
## caller (player.gd) before this is reached. Returns true when the click hit
## something interactable, even if the interaction was refused (too far, not
## yours) — a refusal is an answer, not a miss.
func interact_at(mouse_pos: Vector2) -> bool:
	var camera := _camera
	if camera == null:
		return false
	var space := camera.get_world_3d().direct_space_state
	var origin := camera.project_ray_origin(mouse_pos)
	var end := origin + camera.project_ray_normal(mouse_pos) * 100.0
	var params := PhysicsRayQueryParameters3D.create(origin, end)
	params.collide_with_areas = true
	var result := space.intersect_ray(params)
	if result.is_empty():
		return false
	var obj = result["collider"]
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var dist: float = obj.global_position.distance_to(player.global_position)

	if obj is MiningNode:
		if dist > INTERACT_RANGE_GATHER:
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		CombatLog.add_line(obj.try_mine(), CombatLog.MsgType.INFO)
		return true

	if obj is Corpse:
		# Right-click targets AND loots, so a res caster or the owner can do
		# everything with one button. (Left-click still targets without
		# looting — a Cleric needs the corpse as a cast target.)
		Combat.set_target(obj)
		if obj.owner_id != Net.get_player_id():
			return true  # targeting a stranger's corpse is fine; looting isn't
		if dist > INTERACT_RANGE_LOOT:
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		Loot.show_window(obj)
		return true

	if obj is LootBag:
		if dist > INTERACT_RANGE_LOOT:
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		Loot.show_window(obj)
		return true

	if obj.is_in_group("dialogue_npcs") or obj.is_in_group("vendor_npcs") or obj.is_in_group("banker_npcs"):
		Combat.set_target(obj)
		if dist > INTERACT_RANGE_NPC:
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		if obj.is_in_group("dialogue_npcs"):
			DialogueManager.open_for(obj)
		elif obj.is_in_group("banker_npcs"):
			BankerManager.open_for(obj)
		else:
			VendorManager.open_for(obj)
		return true

	if obj.is_in_group("crafting_stations"):
		# The crafting window filters recipes by StationManager's proximity
		# state, so gate on that rather than a second distance constant —
		# identical semantics to the old F path.
		if StationManager.nearby_station == "":
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		StationManager.request_open()
		return true

	if obj is Enemy and obj.is_skinnable and obj.state == Enemy.State.DEAD:
		if dist > INTERACT_RANGE_GATHER:
			CombatLog.add_line("You are too far away.", CombatLog.MsgType.INFO)
			return true
		CombatLog.add_line(obj.try_skin(), CombatLog.MsgType.INFO)
		return true

	return false
