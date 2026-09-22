extends Node2D

signal dash_started
signal cell_crossed(old_cell, new_cell)
signal dash_finished()
signal hit_obstacle(cell: Vector2i)
signal aim_changed(path: Array[Vector2i])

@export var move_speed := 1500.0
var is_moving := false
var current_cell: Vector2i
var grid_manager: GridManager

var active_path: Array[Vector2i] = []
var preview_path: Array[Vector2i] = []
var aim_direction: Vector2i = Vector2i.ZERO

var line_2d: Line2D

func setup(start_cell: Vector2i, gm: GridManager):
	current_cell = start_cell
	grid_manager = gm
	get_parent().position = grid_manager.cell_to_world(current_cell)
	
	if not line_2d:
		line_2d = Line2D.new()
		line_2d.default_color = Color(0.5, 0.0, 0.8, 0.6)
		line_2d.width = 16.0
		line_2d.joint_mode = Line2D.LINE_JOINT_ROUND
		line_2d.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line_2d.end_cap_mode = Line2D.LINE_CAP_ROUND
		line_2d.z_index = -1
		get_parent().get_parent().call_deferred("add_child", line_2d)

func set_aim(direction: Vector2i):
	if is_moving: return
	if aim_direction == direction: return
	aim_direction = direction
	if aim_direction == Vector2i.ZERO:
		preview_path.clear()
	else:
		preview_path = grid_manager.trace_path_to_junction(current_cell, direction)
	_update_preview_line()
	emit_signal("aim_changed", preview_path)

func _update_preview_line():
	if not line_2d: return
	line_2d.clear_points()
	if preview_path.is_empty(): return
	line_2d.add_point(grid_manager.cell_to_world(current_cell))
	for p in preview_path:
		line_2d.add_point(grid_manager.cell_to_world(p))

func confirm_dash():
	if is_moving or preview_path.is_empty(): return
	active_path = preview_path.duplicate()
	preview_path.clear()
	aim_direction = Vector2i.ZERO
	_update_preview_line()
	
	is_moving = true
	emit_signal("dash_started")
	_move_next_step()

func _move_next_step():
	if active_path.is_empty():
		is_moving = false
		emit_signal("dash_finished")
		return
		
	var next_cell = active_path.pop_front()
	if not grid_manager.is_walkable(next_cell):
		is_moving = false
		emit_signal("hit_obstacle", next_cell)
		emit_signal("dash_finished")
		return
		
	var target_pos = grid_manager.cell_to_world(next_cell)
	var distance = get_parent().position.distance_to(target_pos)
	var duration = max(0.04, distance / move_speed)

	var tween = create_tween()
	tween.tween_property(get_parent(), "position", target_pos, duration)
	tween.tween_callback(func(): _on_step_complete(next_cell))

func _on_step_complete(next_cell: Vector2i):
	var old_cell = current_cell
	current_cell = next_cell
	emit_signal("cell_crossed", old_cell, current_cell)
	_move_next_step()
