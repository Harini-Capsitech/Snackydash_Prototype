extends Node

signal swipe_detected(direction)

var touch_start_pos: Vector2
var is_touching := false
var swipe_threshold := 50.0

func _input(event):
    if event.is_action_pressed("ui_up"):
        emit_signal("swipe_detected", Vector2i.UP)
    elif event.is_action_pressed("ui_down"):
        emit_signal("swipe_detected", Vector2i.DOWN)
    elif event.is_action_pressed("ui_left"):
        emit_signal("swipe_detected", Vector2i.LEFT)
    elif event.is_action_pressed("ui_right"):
        emit_signal("swipe_detected", Vector2i.RIGHT)

    if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
        if event.pressed:
            touch_start_pos = event.position
            is_touching = true
        else:
            if is_touching:
                _check_swipe(event.position)
            is_touching = false
            
func _check_swipe(touch_end_pos: Vector2):
    var diff = touch_end_pos - touch_start_pos
    if diff.length() < swipe_threshold:
        return
        
    if abs(diff.x) > abs(diff.y):
        if diff.x > 0:
            emit_signal("swipe_detected", Vector2i.RIGHT)
        else:
            emit_signal("swipe_detected", Vector2i.LEFT)
    else:
        if diff.y > 0:
            emit_signal("swipe_detected", Vector2i.DOWN)
        else:
            emit_signal("swipe_detected", Vector2i.UP)
