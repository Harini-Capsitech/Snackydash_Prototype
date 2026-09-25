extends Area2D
class_name AnimatedObstacle

@export var closed_texture: Texture2D
@export var open_texture: Texture2D

# How fast the transition should happen
@export var transition_duration: float = 0.3

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

var is_open: bool = false
signal opened

func _ready():
	# Ensure there's a Sprite2D child
	if not has_node("Sprite2D"):
		var new_sprite = Sprite2D.new()
		new_sprite.name = "Sprite2D"
		add_child(new_sprite)
		sprite = new_sprite
		
	# Ensure there's a CollisionShape2D child
	if not has_node("CollisionShape2D"):
		var new_collision = CollisionShape2D.new()
		new_collision.name = "CollisionShape2D"
		
		# Give it a default rectangle shape based on texture size
		var rect = RectangleShape2D.new()
		if closed_texture:
			rect.size = closed_texture.get_size()
		else:
			rect.size = Vector2(64, 64)
		new_collision.shape = rect
		
		add_child(new_collision)
		collision_shape = new_collision

	# Enable input picking on this Area2D
	input_pickable = true

	# Set the initial state
	if closed_texture:
		sprite.texture = closed_texture

func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if is_open:
			close()
		else:
			open()
	elif event is InputEventScreenTouch and event.pressed:
		if is_open:
			close()
		else:
			open()

func open():
	if is_open:
		return
	is_open = true
	opened.emit()
	
	# Disable collision so player can pass
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
	
	# Tween to animate the transition (Flip effect)
	var tween = create_tween()
	# 1. Squash the sprite horizontally
	tween.tween_property(sprite, "scale:x", 0.0, transition_duration / 2.0).set_trans(Tween.TRANS_SINE)
	# 2. Swap the texture halfway through the animation
	tween.tween_callback(func(): sprite.texture = open_texture)
	# 3. Expand the sprite back to normal with the new texture
	tween.tween_property(sprite, "scale:x", 1.0, transition_duration / 2.0).set_trans(Tween.TRANS_SINE)


func close():
	if not is_open:
		return
	is_open = false
	
	# Re-enable collision so it blocks the player
	if collision_shape:
		collision_shape.set_deferred("disabled", false)
	
	# Tween to animate the transition (Flip effect)
	var tween = create_tween()
	# 1. Squash the sprite horizontally
	tween.tween_property(sprite, "scale:x", 0.0, transition_duration / 2.0).set_trans(Tween.TRANS_SINE)
	# 2. Swap the texture halfway through the animation
	tween.tween_callback(func(): sprite.texture = closed_texture)
	# 3. Expand the sprite back to normal with the new texture
	tween.tween_property(sprite, "scale:x", 1.0, transition_duration / 2.0).set_trans(Tween.TRANS_SINE)
