class_name CooldownTracker
extends RefCounted

signal cooldown_updated(name: String, remaining: float, total: float)

var _remaining: Dictionary = {}
var _totals: Dictionary = {}
var _finished: Array[String] = []

func start(name: String, duration: float) -> void:
	_remaining[name] = duration
	_totals[name] = duration
	cooldown_updated.emit(name, duration, duration)

func tick(delta: float) -> void:
	_finished.clear()
	for name in _remaining:
		_remaining[name] -= delta
		cooldown_updated.emit(name, maxf(_remaining[name], 0.0), _totals.get(name, 1.0))
		if _remaining[name] <= 0.0:
			_finished.append(name)
	for name in _finished:
		_remaining.erase(name)
		_totals.erase(name)

func is_active(name: String) -> bool:
	return _remaining.has(name)

func get_remaining(name: String) -> float:
	return _remaining.get(name, 0.0)
