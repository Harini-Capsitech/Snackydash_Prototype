class_name TrayStack
extends Node2D

signal tray_completed(food_id: String)
signal all_trays_completed()

var station_data: StationData
var visual_config: StationVisualConfig
var tray_layers: Array[Dictionary] = [] # [{"food_id": "burger", "node": Sprite2D, "received_count": 0, "capacity": 9, "food_nodes": []}]
var layer_y_step: float = 18.0
var is_animating: bool = false
var base_sprite: Sprite2D = null

func setup(data: StationData, config: StationVisualConfig, food_counts: Dictionary = {}) -> void:
	station_data = data
	visual_config = config
	
	position = data.visual_pos
	scale = data.visual_scale
	rotation = data.visual_rot
	
	# Spawn optional platform base underneath stack only if distinct from tray textures
	if visual_config and visual_config.station_base and visual_config.station_base != visual_config.default_tray_texture:
		base_sprite = Sprite2D.new()
		base_sprite.texture = visual_config.station_base
		base_sprite.z_index = -1
		add_child(base_sprite)
		
	var food_ids = data.tray_food_ids if data.tray_food_ids.size() > 0 else [data.required_food_id]
	
	# Filter out tray foods that do not exist at all in this level (e.g. burger in Level 1)
	if not food_counts.is_empty():
		var filtered_ids: Array[String] = []
		for fid in food_ids:
			if food_counts.get(fid, 0) > 0:
				filtered_ids.append(fid)
		if filtered_ids.size() > 0:
			food_ids = filtered_ids
	
	# Build stack from bottom to top
	# Index 0 is the top tray (active). Index 1 is under Index 0, etc.
	for i in range(food_ids.size()):
		var f_id = food_ids[i]
		var tray_sprite = _create_tray_sprite(f_id)
		
		# In 2.5D stacking: lower trays are offset down in Y and have lower z_index
		tray_sprite.position = Vector2(0, i * layer_y_step)
		tray_sprite.z_index = 5 - i
		add_child(tray_sprite)
		
		var cap = 9
		if not food_counts.is_empty() and food_counts.has(f_id) and food_counts[f_id] > 0:
			cap = min(9, food_counts[f_id])
		
		tray_layers.append({
			"food_id": f_id,
			"node": tray_sprite,
			"received_count": 0,
			"capacity": cap,
			"food_nodes": []
		})

func _create_tray_sprite(food_id: String) -> Sprite2D:
	var sprite = Sprite2D.new()
	var tex: Texture2D = null
	var tint: Color = Color.WHITE
	var badge_tex: Texture2D = null
	
	if visual_config:
		var cfg = visual_config.get_tray_config(food_id)
		if cfg:
			if cfg.tray_texture: tex = cfg.tray_texture
			tint = cfg.tray_tint
			badge_tex = cfg.food_badge_icon
		
		if not tex and visual_config.default_tray_texture:
			tex = visual_config.default_tray_texture
			
	if not tex and station_data and station_data.texture_path != "":
		tex = load(station_data.texture_path)
		
	sprite.texture = tex
	sprite.modulate = tint
	
	# Optional badge icon on front lip
	if badge_tex:
		var badge = Sprite2D.new()
		badge.texture = badge_tex
		badge.position = Vector2(0, 35) # Near the front edge
		badge.scale = Vector2(0.2, 0.2)
		badge.z_index = 1
		sprite.add_child(badge)
		
	return sprite

func has_active_tray() -> bool:
	return tray_layers.size() > 0

func get_active_food_id() -> String:
	if tray_layers.size() > 0:
		return tray_layers[0]["food_id"]
	return ""

func get_active_tray_node() -> Sprite2D:
	if tray_layers.size() > 0:
		return tray_layers[0]["node"]
	return null

func get_received_count() -> int:
	if tray_layers.size() > 0:
		return tray_layers[0]["received_count"]
	return 0

func get_capacity() -> int:
	if tray_layers.size() > 0:
		return tray_layers[0]["capacity"]
	return 9

func get_next_slot_position() -> Vector2:
	var count = get_received_count()
	var idx = count % 9
	var row = int(idx / 3)
	var col = idx % 3
	return Vector2((col - 1) * 60.0, (row - 1) * 60.0)

func add_food_to_active_tray(food_sprite: Sprite2D) -> void:
	if tray_layers.size() == 0:
		return
	var active = tray_layers[0]
	active["received_count"] += 1
	active["food_nodes"].append(food_sprite)

func is_active_tray_full() -> bool:
	if tray_layers.size() == 0:
		return false
	return tray_layers[0]["received_count"] >= tray_layers[0]["capacity"]

func pop_active_tray(callback: Callable = Callable()) -> void:
	if tray_layers.size() == 0 or is_animating:
		if callback.is_valid(): callback.call()
		return
		
	is_animating = true
	var completed_tray = tray_layers.pop_front()
	var finished_food_id = completed_tray["food_id"]
	var tray_node: Sprite2D = completed_tray["node"]
	
	# Animate completed tray flying up and fading out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(tray_node, "position:y", tray_node.position.y - 80.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(tray_node, "modulate:a", 0.0, 0.4)
	tween.tween_property(tray_node, "scale", tray_node.scale * 1.15, 0.4)
	
	# Shift remaining trays upward by one layer
	for i in range(tray_layers.size()):
		var layer = tray_layers[i]
		var l_node: Sprite2D = layer["node"]
		var target_y = i * layer_y_step
		l_node.z_index = 5 - i
		tween.tween_property(l_node, "position:y", target_y, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_delay(0.1)
		
	tween.chain().tween_callback(func():
		tray_node.queue_free()
		is_animating = false
		tray_completed.emit(finished_food_id)
		if tray_layers.is_empty():
			if base_sprite and is_instance_valid(base_sprite):
				var b_tween = create_tween()
				b_tween.tween_property(base_sprite, "modulate:a", 0.0, 0.3)
				b_tween.chain().tween_callback(base_sprite.queue_free)
			all_trays_completed.emit()
		if callback.is_valid():
			callback.call()
	)

func is_all_completed() -> bool:
	return tray_layers.is_empty()
