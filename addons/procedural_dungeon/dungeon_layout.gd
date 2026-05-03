class_name DungeonLayout
extends Resource

const CELL_EMPTY          = 0
const CELL_FLOOR          = 1
const CELL_STAIR_BOTTOM   = 2  # lower-floor shaft cell: floor rendered, ceiling omitted
const CELL_STAIR_TOP      = 3  # upper-floor shaft cell: floor omitted, ceiling rendered
const CELL_INTERIOR_WALL  = 4  # room perimeter wall — tagged at generation, never by corridors

@export var seed_value: int = 0
@export var grid_width: int = 0
@export var grid_height: int = 0
@export var cell_size: float = 6.0   # world units per grid cell
@export var room_height: float = 5.0  # world units tall
@export var rooms: Array = []         # Array[RoomData]

var _grid: PackedByteArray

func setup_grid(width: int, height: int) -> void:
	grid_width = width
	grid_height = height
	_grid = PackedByteArray()
	_grid.resize(width * height)
	_grid.fill(CELL_EMPTY)

func set_cell(x: int, y: int, value: int) -> void:
	if x >= 0 and x < grid_width and y >= 0 and y < grid_height:
		_grid[y * grid_width + x] = value

func get_cell(x: int, y: int) -> int:
	if x < 0 or x >= grid_width or y < 0 or y >= grid_height:
		return CELL_EMPTY
	return _grid[y * grid_width + x]

func is_passable(x: int, y: int) -> bool:
	return get_cell(x, y) != CELL_EMPTY

func cell_to_world(cx: int, cy: int) -> Vector3:
	return Vector3(cx * cell_size, 0.0, cy * cell_size)

func entrance_room() -> RoomData:
	for r in rooms:
		if r.room_type == RoomData.RoomType.ENTRANCE:
			return r
	return rooms[0] if not rooms.is_empty() else null
