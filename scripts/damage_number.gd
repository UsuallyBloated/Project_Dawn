extends Label3D

const FLOAT_SPEED  := 1.8
const LIFETIME     := 1.2
const FADE_START   := 0.5   # seconds before death to start fading

var _age: float = 0.0

func setup(amount: int, is_player_damage: bool) -> void:
	text = str(amount)
	font_size = 48
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	modulate = Color(1.0, 0.25, 0.20) if is_player_damage else Color(0.95, 0.78, 0.25)

func _process(delta: float) -> void:
	_age += delta
	position.y += FLOAT_SPEED * delta

	var remaining := LIFETIME - _age
	if remaining < FADE_START:
		modulate.a = remaining / FADE_START

	if _age >= LIFETIME:
		queue_free()
