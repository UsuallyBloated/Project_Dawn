class_name MultiFloorLayout
extends Resource

# Thin solid layer between floors — prevents ceiling of floor N and
# floor of floor N+1 from being coplanar and z-fighting.
const FLOOR_GAP = 0.5

@export var seed_value:  int = 0
@export var floor_count: int = 1
@export var floors: Array = []  # Array[DungeonLayout]
@export var stairs: Array = []  # Array[StairData]

func floor_y_offset(floor_idx: int) -> float:
	if floors.is_empty():
		return 0.0
	return floor_idx * _stride()

# Total vertical distance between the floor surfaces of adjacent levels.
# The stair ramp must span exactly this height.
func floor_separation() -> float:
	return _stride()

func entrance_layout() -> DungeonLayout:
	return floors[0] if not floors.is_empty() else null

func _stride() -> float:
	if floors.is_empty():
		return 5.0
	return (floors[0] as DungeonLayout).room_height + FLOOR_GAP
