extends Node

signal alignment_changed(tier: String, score: int)

var alignment_score: int = 0
var alignment_tier: String = "Neutral"

func set_alignment(score: int) -> void:
	alignment_score = clamp(score, -2000, 2000)
	alignment_tier = _calc_tier()
	alignment_changed.emit(alignment_tier, alignment_score)

func modify_alignment(delta: int) -> void:
	alignment_score = clamp(alignment_score + delta, -2000, 2000)
	var new_tier := _calc_tier()
	if new_tier != alignment_tier:
		alignment_tier = new_tier
		alignment_changed.emit(alignment_tier, alignment_score)

func _calc_tier() -> String:
	if alignment_score >= 1500:
		return "Exalted"
	elif alignment_score >= 300:
		return "Good"
	elif alignment_score >= -300:
		return "Neutral"
	elif alignment_score >= -1500:
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
	return {"alignment_score": alignment_score}

func load_state(d: Dictionary) -> void:
	set_alignment(int(d.get("alignment_score", 0)))
