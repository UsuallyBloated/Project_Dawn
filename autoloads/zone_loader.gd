extends Node

signal zone_changed(zone_name: String)
signal zone_ready

const FADE_DURATION := 0.5

var current_zone_name: String = ""
var current_zone_path: String = ""
var _pending_entry_id: String = "default"
var _transitioning: bool = false

var _overlay: ColorRect = null
var _tween: Tween = null

func _ready() -> void:
	_build_overlay()

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	layer.add_child(_overlay)

# Called by ZoneLine nodes when the player crosses a zone border.
func travel_to(zone_path: String, entry_id: String, zone_name: String = "") -> void:
	if _transitioning:
		return
	_transitioning = true
	_pending_entry_id = entry_id
	_fade_to(1.0, func():
		current_zone_name = zone_name
		current_zone_path = zone_path
		zone_changed.emit(zone_name)
		get_tree().change_scene_to_file(zone_path)
	)

# Called by each zone's world script once the scene is ready and the player is
# spawned. Fades the black overlay back out.
func on_zone_ready() -> void:
	zone_ready.emit()
	_fade_to(0.0, func(): _transitioning = false)

# Returns the position of the matching ZoneEntry in the current scene, falling
# back to the world origin if none is found. Consumes the pending entry id.
func get_spawn_position() -> Vector3:
	var id := _pending_entry_id
	_pending_entry_id = "default"
	for entry in get_tree().get_nodes_in_group("zone_entries"):
		if entry.entry_id == id:
			return entry.global_position
	return Vector3.ZERO

func _fade_to(target_alpha: float, on_done: Callable) -> void:
	if _tween and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_overlay, "modulate:a", target_alpha, FADE_DURATION)
	_tween.tween_callback(on_done)
