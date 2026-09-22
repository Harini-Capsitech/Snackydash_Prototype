class_name LevelData extends Resource

@export var level_name: String = ""
@export var grid_columns: int = 9
@export var grid_rows: int = 17
@export var cell_size: Vector2 = Vector2(64, 64)

# Array of Dictionary storing rect bounds: x, y, width, height, and whether it contains a slot
@export var islands: Array[Dictionary] = []

# Array of Dictionary storing rect bounds: x, y, width, height
@export var slots: Array[Dictionary] = []

# Array of Dictionary storing rect bounds: x, y, width, height
@export var roads: Array[Dictionary] = []

# Array of Dictionary storing cell_x, cell_y, type
@export var entities: Array[Dictionary] = []
