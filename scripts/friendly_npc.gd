class_name FriendlyNPC
extends Area3D

# Shared base for vendor/dialogue NPCs.
# - Tight click-target collision lives on the root Area3D (raycast hit zone).
# - Wider proximity bubble lives on a child Area3D named "ProximitySensor"
#   (collision_layer=0 so raycasts ignore it; mask=1 so it still detects player).
# - set_targeted() flashes the name label cyan-mint to match enemy gold flash convention.

const FLASH_COLOR := Color(0.55, 1.0, 0.85, 1.0)
const FLASH_PERIOD := 0.4

var _name_label: Label3D = null
var _flash_tween: Tween = null

func _ready() -> void:
	_register()
	_name_label = get_node_or_null("NameLabel") as Label3D
	if _name_label:
		_name_label.text = _display_name()
	var sensor := get_node_or_null("ProximitySensor") as Area3D
	if sensor != null:
		sensor.body_entered.connect(_on_body_entered)
		sensor.body_exited.connect(_on_body_exited)
	else:
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_player_nearby(true)

func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_player_nearby(false)

func set_targeted(targeted: bool) -> void:
	if _name_label == null:
		return
	if _flash_tween:
		_flash_tween.kill()
		_flash_tween = null
	if targeted:
		_flash_tween = create_tween().set_loops()
		_flash_tween.tween_property(_name_label, "modulate", FLASH_COLOR, FLASH_PERIOD)
		_flash_tween.tween_property(_name_label, "modulate", Color.WHITE, FLASH_PERIOD)
	else:
		_name_label.modulate = Color.WHITE

# Subclass overrides ────────────────────────────────────────────────────────────

# Add the NPC to its identifying group ("vendor_npcs", "dialogue_npcs", …).
func _register() -> void:
	pass

# Returns the text to display on the floating name label.
func _display_name() -> String:
	return ""

# Called when the player enters or exits the proximity bubble.
func _on_player_nearby(_is_near: bool) -> void:
	pass
