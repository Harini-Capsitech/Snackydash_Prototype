class_name TrainController
extends Node2D

enum State {
	MOVING,
	WAITING_AT_JUNCTION,
	STOPPED
}

var current_state: State = State.STOPPED
var current_grid_pos: Vector2i
var current_dir: Vector2i = Vector2i.RIGHT
var initial_dir: Vector2i
var target_world_pos: Vector2
var move_speed: float = 200.0

var level_data: RailwayLevelData
var track_dict: Dictionary = {}
var cell_size: int = 64

var foods_dict: Dictionary = {}
var stations_dict: Dictionary = {}

var carriages: Array[String] = [] # stores food_ids of collected food
var carriage_sprites: Array[Sprite2D] = []
var carriage_texture: Texture2D

var grid_offset: Vector2 = Vector2.ZERO # visually precise offset
var path_history: Array[Vector2i] = [] # stores visited grid cells for carriages

var level_loader # reference to parent loader for instantiating things
var tile_map: TileMap = null # for exact coordinate mapping

signal on_food_collected(food_id: String)
signal on_food_delivered(station_id: String, food_id: String)
signal level_completed()

func setup(p_level_data: RailwayLevelData, p_track_dict: Dictionary, p_foods: Dictionary, p_stations: Dictionary, loader, p_carriage_tex: Texture2D) -> void:
	level_data = p_level_data
	track_dict = p_track_dict
	foods_dict = p_foods
	stations_dict = p_stations
	level_loader = loader
	carriage_texture = p_carriage_tex
	cell_size = level_data.cell_size
	
	if level_data.train_spawn:
		current_grid_pos = level_data.train_spawn.position
		current_dir = level_data.train_spawn.facing_direction
		initial_dir = current_dir
		
		# Snap perfectly to the center of the tile to prevent rotation popping
		if tile_map:
			position = tile_map.map_to_local(current_grid_pos)
		else:
			position = Vector2(current_grid_pos.x * cell_size + cell_size/2.0, current_grid_pos.y * cell_size + cell_size/2.0)
			
		# Pre-fill path history backwards so carriages have a path to follow immediately
		for i in range(100, 0, -1):
			path_history.append(current_grid_pos - (current_dir * i))
		path_history.append(current_grid_pos)
		
		# Start stopped. Wait for player input!
		current_state = State.STOPPED
	else:
		current_state = State.STOPPED

func _process(delta: float) -> void:
	if current_state == State.MOVING:
		var step = move_speed * delta
		var dist_total = cell_size # movement between two cells is always cell_size
		var dist_current = position.distance_to(target_world_pos)
		var t = clamp(1.0 - (dist_current / float(dist_total)), 0.0, 1.0)
		
		# Update carriages smoothly along the path history
		for i in range(carriages.size()):
			# i=0 is the first carriage. It moves between path_history[-2] and path_history[-1]
			var start_idx = path_history.size() - 2 - i
			var end_idx = path_history.size() - 1 - i
			
			if start_idx >= 0 and end_idx < path_history.size():
				var p_start = Vector2.ZERO
				var p_end = Vector2.ZERO
				if tile_map:
					p_start = tile_map.map_to_local(path_history[start_idx])
					p_end = tile_map.map_to_local(path_history[end_idx])
				else:
					p_start = Vector2(path_history[start_idx].x * cell_size + cell_size/2.0, path_history[start_idx].y * cell_size + cell_size/2.0)
					p_end = Vector2(path_history[end_idx].x * cell_size + cell_size/2.0, path_history[end_idx].y * cell_size + cell_size/2.0)
				
				var c_sprite = carriage_sprites[i]
				c_sprite.position = p_start.lerp(p_end, t)
				
				# Rotate carriage visually
				var dir = path_history[end_idx] - path_history[start_idx]
				if dir == Vector2i(0, -1): c_sprite.rotation_degrees = 0
				elif dir == Vector2i(1, 0): c_sprite.rotation_degrees = 90
				elif dir == Vector2i(0, 1): c_sprite.rotation_degrees = 180
				elif dir == Vector2i(-1, 0): c_sprite.rotation_degrees = -90
		
		if dist_current <= step:
			position = target_world_pos
			current_grid_pos = current_grid_pos + current_dir
			path_history.append(current_grid_pos) # Record our new position for carriages
			
			# Prevent history array from growing infinitely
			if path_history.size() > 200:
				path_history.pop_front()
				
			_handle_grid_arrival()
		else:
			position = position.move_toward(target_world_pos, step)
			
	elif current_state == State.WAITING_AT_JUNCTION:
		# Check for swipe input
		var swipe_dir = Vector2i.ZERO
		if Input.is_action_just_pressed("ui_up"): swipe_dir = Vector2i(0, -1)
		elif Input.is_action_just_pressed("ui_down"): swipe_dir = Vector2i(0, 1)
		elif Input.is_action_just_pressed("ui_left"): swipe_dir = Vector2i(-1, 0)
		elif Input.is_action_just_pressed("ui_right"): swipe_dir = Vector2i(1, 0)
		
		if swipe_dir != Vector2i.ZERO:
			if _is_valid_move(current_grid_pos, swipe_dir) and swipe_dir != -current_dir: # don't allow U-turns at junctions directly
				current_dir = swipe_dir
				_calculate_next_target()
				current_state = State.MOVING

func _unhandled_input(event: InputEvent) -> void:
	if current_state == State.STOPPED:
		var dir = Vector2i.ZERO
		if Input.is_action_just_pressed("ui_up"): dir = Vector2i(0, -1)
		elif Input.is_action_just_pressed("ui_down"): dir = Vector2i(0, 1)
		elif Input.is_action_just_pressed("ui_left"): dir = Vector2i(-1, 0)
		elif Input.is_action_just_pressed("ui_right"): dir = Vector2i(1, 0)
		
		if dir != Vector2i.ZERO:
			if _is_valid_move(current_grid_pos, dir):
				current_dir = dir
				# Do NOT change initial_dir here, so the visual rotation stays relative to the original editor orientation
				_calculate_next_target()
				current_state = State.MOVING

func _handle_grid_arrival() -> void:
	# Check for food
	if foods_dict.has(current_grid_pos):
		var food_data = foods_dict[current_grid_pos]
		var food_id = food_data.food_id
		carriages.append(food_id)
		
		# Visual carriage
		var sprite = Sprite2D.new()
		sprite.texture = carriage_texture
		if carriage_texture:
			var scale_f = float(cell_size) / max(carriage_texture.get_width(), carriage_texture.get_height())
			sprite.scale = Vector2(scale_f, scale_f)
			
		# Add to level loader instead of train, so it moves independently
		level_loader.add_child(sprite)
		
		# Add food sprite inside the carriage
		var food_sprite = Sprite2D.new()
		food_sprite.texture = food_data.node.texture
		food_sprite.scale = food_data.node.scale / sprite.scale # adjust relative scale
		sprite.add_child(food_sprite)
		
		carriage_sprites.append(sprite)
		
		food_data.node.queue_free()
		foods_dict.erase(current_grid_pos)
		on_food_collected.emit(food_id)
		
	# Check for station (including adjacent cells in case origin is off)
	var found_station_info = null
	for offset in [Vector2i.ZERO, Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
		if stations_dict.has(current_grid_pos + offset):
			found_station_info = stations_dict[current_grid_pos + offset]
			break
			
	if found_station_info:
		var station = found_station_info.data
		var station_node = found_station_info.node
		var delivered_something = false
		
		if not found_station_info.has("received_count"): found_station_info["received_count"] = 0
		
		var delivery_idx = 0
		# Deliver all carriages at this station
		while carriages.size() > 0:
			carriages.pop_front()
			var c = carriage_sprites.pop_front()
			
			# Extract the food sprite and animate it into the station
			var food_sprite = null
			for child in c.get_children():
				if child is Sprite2D:
					food_sprite = child
					break
					
			if food_sprite:
				var global_pos = food_sprite.global_position
				var global_scale = food_sprite.global_scale
				
				c.remove_child(food_sprite)
				station_node.add_child(food_sprite)
				
				# Preserve global transform so it doesn't pop instantly when reparented
				food_sprite.global_position = global_pos
				food_sprite.global_scale = global_scale
				
				var count = found_station_info["received_count"]
				var row = count / 3
				var col = count % 3
				
				# The station might be scaled (e.g. 0.5), so local offsets need to be larger to be visible.
				var offset_x = (col - 1) * 60.0
				var offset_y = (row - 1) * 60.0
				
				# Make sure z-index is set so they don't draw under the station
				food_sprite.z_index = 10 + count
				
				var tween = create_tween()
				tween.set_parallel(true)
				var delay = delivery_idx * 0.15
				tween.tween_property(food_sprite, "position", Vector2(offset_x, offset_y), 0.3).set_ease(Tween.EASE_OUT).set_delay(delay)
				
				# Target a specific local scale so they are uniform inside the tray
				tween.tween_property(food_sprite, "scale", Vector2(0.24, 0.24), 0.3).set_delay(delay)
				
				found_station_info["received_count"] += 1
				
			c.queue_free()
			delivery_idx += 1
			delivered_something = true
			
		if delivered_something:
			on_food_delivered.emit(station.required_food_id, station.required_food_id)
			
			if foods_dict.is_empty() and carriages.is_empty():
				level_completed.emit()
				current_state = State.STOPPED
				return
	
	# Determine next move
	var current_track: TrackCellData = track_dict.get(current_grid_pos, null)
	if current_track == null:
		# Train derailed (ran off track)
		current_state = State.STOPPED
		return
		
	var valid_exits = []
	var has_explicit = current_track.connect_up or current_track.connect_down or current_track.connect_left or current_track.connect_right
	
	if has_explicit:
		if current_track.connect_up and current_dir != Vector2i(0, 1): valid_exits.append(Vector2i(0, -1))
		if current_track.connect_down and current_dir != Vector2i(0, -1): valid_exits.append(Vector2i(0, 1))
		if current_track.connect_left and current_dir != Vector2i(1, 0): valid_exits.append(Vector2i(-1, 0))
		if current_track.connect_right and current_dir != Vector2i(-1, 0): valid_exits.append(Vector2i(1, 0))
	else:
		# Fallback: if user didn't configure custom data for plain sprites, assume all adjacent tracks connect!
		if current_dir != Vector2i(0, 1) and track_dict.has(current_grid_pos + Vector2i(0, -1)): valid_exits.append(Vector2i(0, -1))
		if current_dir != Vector2i(0, -1) and track_dict.has(current_grid_pos + Vector2i(0, 1)): valid_exits.append(Vector2i(0, 1))
		if current_dir != Vector2i(1, 0) and track_dict.has(current_grid_pos + Vector2i(-1, 0)): valid_exits.append(Vector2i(-1, 0))
		if current_dir != Vector2i(-1, 0) and track_dict.has(current_grid_pos + Vector2i(1, 0)): valid_exits.append(Vector2i(1, 0))
	
	if valid_exits.size() == 0:
		# Dead end
		current_state = State.STOPPED
	elif valid_exits.size() == 1:
		# Forced path
		current_dir = valid_exits[0]
		_calculate_next_target()
	else:
		# Junction
		current_state = State.WAITING_AT_JUNCTION

func _calculate_next_target() -> void:
	var next_pos = current_grid_pos + current_dir
	if tile_map:
		target_world_pos = tile_map.map_to_local(next_pos)
	else:
		target_world_pos = Vector2(next_pos.x * cell_size + cell_size/2.0, next_pos.y * cell_size + cell_size/2.0)
	
	# Rotate visually based on the difference from the initial direction
	var initial_angle = _get_angle_for_dir(initial_dir)
	var current_angle = _get_angle_for_dir(current_dir)
	rotation_degrees = current_angle - initial_angle

func _get_angle_for_dir(dir: Vector2i) -> float:
	if dir == Vector2i(0, -1): return 0.0
	if dir == Vector2i(1, 0): return 90.0
	if dir == Vector2i(0, 1): return 180.0
	if dir == Vector2i(-1, 0): return -90.0
	return 0.0

func _is_valid_move(pos: Vector2i, dir: Vector2i) -> bool:
	var track: TrackCellData = track_dict.get(pos, null)
	if not track: return false
	
	if dir == Vector2i(0, -1) and track.connect_up: return true
	if dir == Vector2i(0, 1) and track.connect_down: return true
	if dir == Vector2i(-1, 0) and track.connect_left: return true
	if dir == Vector2i(1, 0) and track.connect_right: return true
	return false
