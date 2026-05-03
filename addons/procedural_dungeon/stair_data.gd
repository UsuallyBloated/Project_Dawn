class_name StairData
extends Resource

@export var from_floor: int = 0
@export var to_floor:   int = 1
@export var shaft_gx:   int = 0   # grid X of shaft top-left corner
@export var shaft_gy:   int = 0   # grid Y (= world Z / cell_size) of shaft top-left
@export var shaft_w:    int = 2   # width in cells (X axis)
@export var shaft_d:    int = 2   # depth in cells (Z axis, direction of travel up stairs)
@export var cell_size:  float = 6.0
