extends Node

# Opens loot windows: a LootBag (a slain mob's body or a dropped sack) or our
# own Corpse. The server owns every roll and every item; the window shows what
# the server sent and sends Loot intents back.

var _ui_layer: CanvasLayer

func _ready() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 5
	add_child(_ui_layer)

func show_window(bag) -> void:  # bag: LootBag or Corpse (Slice 2 corpse loot)
	for child in _ui_layer.get_children():
		if child is LootWindow and child.bag == bag:
			child.visible = true
			return
	var window := LootWindow.new(bag)
	_ui_layer.add_child(window)
