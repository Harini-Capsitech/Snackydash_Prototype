extends Node2D

signal move_started
signal cell_crossed(old_cell, new_cell)
signal move_finished()
signal hit_obstacle(cell: Vector2i)

@export var move_speed := 1000.0
var is_moving := false
var current_cell: Vector2i
var grid_manager: GridManager

var current_direction: Vector2i

func setup(start_cell: Vector2i, gm: GridManager):
    current_cell = start_cell
    grid_manager = gm
    get_parent().position = grid_manager.cell_to_world(current_cell)

func try_move(direction: Vector2i):
    if is_moving:
        return

    var next_cell = current_cell + direction
    if not grid_manager.is_walkable(next_cell):
        emit_signal("hit_obstacle", next_cell)
        return

    is_moving = true
    current_direction = direction
    emit_signal("move_started")
    _move_one_step()

func _move_one_step():
    var next_cell = current_cell + current_direction
    if not grid_manager.is_walkable(next_cell):
        is_moving = false
        emit_signal("hit_obstacle", next_cell)
        emit_signal("move_finished")
        return

    var target_pos = grid_manager.cell_to_world(next_cell)
    var distance = get_parent().position.distance_to(target_pos)
    var duration = max(0.05, distance / move_speed)

    var tween = create_tween()
    tween.tween_property(get_parent(), "position", target_pos, duration)
    tween.tween_callback(func(): _on_step_complete(next_cell))

func _on_step_complete(next_cell: Vector2i):
    var old_cell = current_cell
    current_cell = next_cell
    emit_signal("cell_crossed", old_cell, current_cell)
    is_moving = false
    emit_signal("move_finished")
