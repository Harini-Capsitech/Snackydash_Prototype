class_name EditorGrid
extends Node2D

@export var cell_size: int = 64
@export var grid_width: int = 12
@export var grid_height: int = 18

@export var grid_color: Color = Color(1, 1, 1, 0.2)
@export var border_color: Color = Color(1, 0, 0, 0.8)

func _draw() -> void:
	var width_px = grid_width * cell_size
	var height_px = grid_height * cell_size

	# Draw grid lines
	for x in range(grid_width + 1):
		var start = Vector2(x * cell_size, 0)
		var end = Vector2(x * cell_size, height_px)
		draw_line(start, end, grid_color, 1.0)
		
	for y in range(grid_height + 1):
		var start = Vector2(0, y * cell_size)
		var end = Vector2(width_px, y * cell_size)
		draw_line(start, end, grid_color, 1.0)
		
	# Draw border
	draw_rect(Rect2(0, 0, width_px, height_px), border_color, false, 3.0)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	return Vector2i(floor(world_pos.x / cell_size), floor(world_pos.y / cell_size))

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)

func is_within_bounds(grid_pos: Vector2i) -> bool:
	return grid_pos.x >= 0 and grid_pos.x < grid_width and grid_pos.y >= 0 and grid_pos.y < grid_height
