class_name RoomData
extends Resource

enum RoomType { GENERIC, ENTRANCE, EXIT, BOSS }

@export var id: int = 0
@export var grid_rect: Rect2i = Rect2i()
@export var room_type: RoomType = RoomType.GENERIC
@export var connected_to: Array = []  # Array of room IDs

func center_cell() -> Vector2i:
	return Vector2i(
		grid_rect.position.x + (grid_rect.size.x >> 1),
		grid_rect.position.y + (grid_rect.size.y >> 1)
	)
