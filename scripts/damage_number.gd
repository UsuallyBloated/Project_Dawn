class_name DamageNumber
extends Label3D

enum Type { DAMAGE, CRIT, INCOMING, MISS, HEAL, XP }

const FLOAT_SPEED := 1.8
const LIFETIME    := 1.2
const FADE_START  := 0.5

var _age: float = 0.0

func setup(amount: int, type: Type) -> void:
	billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	match type:
		Type.DAMAGE:
			text      = str(amount)
			font_size = 48
			modulate  = Color(1.00, 0.25, 0.20)
		Type.CRIT:
			text      = str(amount)
			font_size = 64
			modulate  = Color(1.00, 0.85, 0.10)
		Type.INCOMING:
			text      = str(amount)
			font_size = 48
			modulate  = Color(0.95, 0.78, 0.25)
		Type.MISS:
			text      = "Miss"
			font_size = 36
			modulate  = Color(0.65, 0.65, 0.65)
		Type.HEAL:
			text      = "+%d" % amount
			font_size = 48
			modulate  = Color(0.30, 1.00, 0.40)
		Type.XP:
			text      = "+%d XP" % amount
			font_size = 36
			modulate  = Color(0.40, 0.80, 1.00)

func _process(delta: float) -> void:
	_age       += delta
	position.y += FLOAT_SPEED * delta
	var remaining := LIFETIME - _age
	if remaining < FADE_START:
		modulate.a = remaining / FADE_START
	if _age >= LIFETIME:
		queue_free()
