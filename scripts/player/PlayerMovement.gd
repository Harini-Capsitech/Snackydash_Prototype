extends Node2D

signal move_started
signal move_finished(cells_crossed)

@export var move_speed := 1000.0
var is_moving := false
var current_cell: Vector2i
var grid_manager: GridManager

func setup(start_cell: Vector2i, gm: GridManager):
    current_cell = start_cell
    grid_manager = gm
    get_parent().position = grid_manager.cell_to_world(current_cell)

func try_move(direction: Vector2i):
    if is_moving:
        return
    
    var destination = grid_manager.get_slide_destination(current_cell, direction)
    if destination == current_cell:
        return # Can't move
        
    var path: Array[Vector2i] = grid_manager.get_cells_along_path(current_cell, direction)
    is_moving = true
    emit_signal("move_started")
    
    var target_pos = grid_manager.cell_to_world(destination)
    var distance = get_parent().position.distance_to(target_pos)
    var duration = distance / move_speed
    
    var tween = create_tween()
    tween.tween_property(get_parent(), "position", target_pos, duration)
    tween.tween_callback(func(): _on_move_complete(destination, path))

func _on_move_complete(dest: Vector2i, path: Array[Vector2i]):
    get_parent().update_tail(current_cell)
    current_cell = dest
    is_moving = false
    emit_signal("move_finished", path)
