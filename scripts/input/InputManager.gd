extends Node

signal aim_direction_changed(direction)
signal drag_released()

var is_dragging := false
var drag_start_pos := Vector2.ZERO
var drag_threshold := 20.0

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.pressed:
                is_dragging = true
                drag_start_pos = event.position
            else:
                if is_dragging:
                    is_dragging = false
                    emit_signal("drag_released")
    elif event is InputEventMouseMotion and is_dragging:
        var delta = event.position - drag_start_pos
        if delta.length() > drag_threshold:
            var dir = _calculate_cardinal_dir(delta)
            emit_signal("aim_direction_changed", dir)
            
    elif event is InputEventScreenTouch:
        if event.pressed:
            is_dragging = true
            drag_start_pos = event.position
        else:
            is_dragging = false
            emit_signal("drag_released")
    elif event is InputEventScreenDrag and is_dragging:
        var delta = event.position - drag_start_pos
        if delta.length() > drag_threshold:
            var dir = _calculate_cardinal_dir(delta)
            emit_signal("aim_direction_changed", dir)

    if event is InputEventKey and event.is_pressed():
        var dir = Vector2i.ZERO
        if event.keycode in [KEY_UP, KEY_W]: dir = Vector2i(0, -1)
        elif event.keycode in [KEY_DOWN, KEY_S]: dir = Vector2i(0, 1)
        elif event.keycode in [KEY_LEFT, KEY_A]: dir = Vector2i(-1, 0)
        elif event.keycode in [KEY_RIGHT, KEY_D]: dir = Vector2i(1, 0)
        
        if dir != Vector2i.ZERO:
            emit_signal("aim_direction_changed", dir)
            emit_signal("drag_released")

func _calculate_cardinal_dir(delta: Vector2) -> Vector2i:
    if abs(delta.x) > abs(delta.y):
        return Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
    else:
        return Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
