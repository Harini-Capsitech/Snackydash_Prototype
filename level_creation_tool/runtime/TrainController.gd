class_name TrainController
extends Node2D

enum State {
	MOVING,
	WAITING_AT_JUNCTION,
	STOPPED,
	DELIVERING
}

var current_state: State = State.STOPPED
var current_grid_pos: Vector2i
var current_dir: Vector2i = Vector2i.RIGHT
var initial_dir: Vector2i
var target_world_pos: Vector2
var move_speed: float = 200.0

func _get_cell_world_pos(cell: Vector2i) -> Vector2:
	if tile_map:
		return tile_map.map_to_local(cell)
	else:
		return Vector2(cell.x * cell_size + cell_size / 2.0, cell.y * cell_size + cell_size / 2.0)

var level_data: RailwayLevelData
var track_dict: Dictionary = {}
var cell_size: int = 64

var foods_dict: Dictionary = {}
var stations_dict: Dictionary = {}
var obstacles_dict: Dictionary = {}

var carriages: Array[String] = [] # stores food_ids of collected food
var carriage_sprites: Array[Sprite2D] = []
var carriage_texture: Texture2D

var grid_offset: Vector2 = Vector2.ZERO # visually precise offset
var path_history: Array[Vector2i] = [] # stores visited grid cells for carriages

var level_loader # reference to parent loader for instantiating things
var tile_map: TileMap = null # for exact coordinate mapping

signal on_food_collected(food_id: String)
signal on_food_delivered(station_id: String, food_id: String)
signal on_crashed()
signal level_completed()

func setup(p_level_data: RailwayLevelData, p_track_dict: Dictionary, p_foods: Dictionary, p_stations: Dictionary, p_obstacles: Dictionary, loader, p_carriage_tex: Texture2D) -> void:
	level_data = p_level_data
	track_dict = p_track_dict
	foods_dict = p_foods
	stations_dict = p_stations
	obstacles_dict = p_obstacles
	level_loader = loader
	carriage_texture = p_carriage_tex
	cell_size = level_data.cell_size
	
	# Make sure the train engine always draws ON TOP of the carriages!
	self.z_index = 10
	
	if level_data.train_spawn:
		current_grid_pos = level_data.train_spawn.position
		current_dir = level_data.train_spawn.facing_direction
		initial_dir = current_dir
		
		# Snap perfectly to the center of the tile to prevent rotation popping
		position = _get_cell_world_pos(current_grid_pos)
			
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
		var carriage_count = min(carriages.size(), carriage_sprites.size())
		for i in range(carriage_count):
			# i=0 is the first carriage. It moves between path_history[-2] and path_history[-1]
			var start_idx = path_history.size() - 2 - i
			var end_idx = path_history.size() - 1 - i
			
			if start_idx >= 0 and end_idx < path_history.size():
				var p_start = _get_cell_world_pos(path_history[start_idx])
				var p_end = _get_cell_world_pos(path_history[end_idx])
				
				var c_sprite = carriage_sprites[i]
				if is_instance_valid(c_sprite):
					c_sprite.position = p_start.lerp(p_end, t)
					
					# Rotate carriage visually
					var dir = path_history[end_idx] - path_history[start_idx]
					c_sprite.rotation_degrees = _get_angle_for_dir(dir)
		
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
				if carriages.size() > 0 and dir == -current_dir:
					# Cannot U-turn if you have carriages!
					print("Cannot reverse with carriages attached!")
					pass
				else:
					current_dir = dir
					# Do NOT change initial_dir here, so the visual rotation stays relative to the original editor orientation
					_calculate_next_target()
					current_state = State.MOVING

func _handle_grid_arrival() -> void:
	# Check for obstacle collision
	if obstacles_dict.has(current_grid_pos):
		var obs_node = obstacles_dict[current_grid_pos].get("node")
		
		# If it's an AnimatedObstacle, wait for it to open instead of crashing
		if obs_node and obs_node.has_method("open"):
			if not obs_node.is_open:
				current_state = State.STOPPED
				print("Train waiting for obstacle to open...")
				if not obs_node.opened.is_connected(_resume_from_obstacle):
					obs_node.opened.connect(_resume_from_obstacle)
				return
			else:
				# It is already open, just pass through!
				pass
		else:
			# Regular static obstacle -> Crash
			current_state = State.STOPPED
			on_crashed.emit()
			print("CRASHED into an obstacle!")
			
			# Optional: add visual shake or explosion here
			var tween = create_tween()
			tween.tween_property(self, "position", position + Vector2(10, 0), 0.05)
			tween.tween_property(self, "position", position - Vector2(10, 0), 0.05)
			tween.tween_property(self, "position", position + Vector2(5, 0), 0.05)
			tween.tween_property(self, "position", position, 0.05)
			return
		
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
		
		# Make the food slightly smaller than the carriage so you can see the carriage underneath!
		# Also raise it up a bit so it sits "inside" the cart.
		food_sprite.scale = Vector2(0.6, 0.6) 
		food_sprite.position = Vector2(0, -80)
		sprite.add_child(food_sprite)
		
		# Set initial position so it doesn't flash at (0,0)
		if tile_map:
			sprite.position = tile_map.map_to_local(current_grid_pos)
		
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
		await _deliver_at_station(found_station_info)
		return
		
	_resume_after_delivery()

func _can_deliver_to_station(tray_stack: TrayStack) -> bool:
	if not tray_stack or not tray_stack.has_active_tray():
		return false
	var active_food = tray_stack.get_active_food_id()
	var target = active_food.to_lower().replace(" ", "_")
	for c in carriages:
		if c.to_lower().replace(" ", "_") == target:
			return true
	return false

func _are_all_stations_completed() -> bool:
	for s_info in stations_dict.values():
		var stack: TrayStack = s_info.get("tray_stack", null)
		if stack and not stack.is_all_completed():
			return false
	return true

func _deliver_at_station(found_station_info: Dictionary) -> void:
	var station = found_station_info.data
	var station_node = found_station_info.node
	var tray_stack: TrayStack = found_station_info.get("tray_stack", null)
	
	if tray_stack == null:
		_fallback_station_delivery(found_station_info)
		return
		
	if not _can_deliver_to_station(tray_stack):
		_resume_after_delivery()
		return
		
	current_state = State.DELIVERING
	
	# Multi-tray cascade loop:
	# Keep delivering as long as the train has matching items and the station has active trays
	while carriages.size() > 0 and tray_stack.has_active_tray():
		var active_food = tray_stack.get_active_food_id()
		var target_food_norm = active_food.to_lower().replace(" ", "_")
		
		# Find all carriages in the train matching this active tray
		var matching_indices: Array[int] = []
		for i in range(carriages.size()):
			if carriages[i].to_lower().replace(" ", "_") == target_food_norm:
				matching_indices.append(i)
				
		if matching_indices.is_empty():
			# No matching carriages for the current active tray
			break
			
		# Limit matching items to active tray remaining capacity (max 9 items)
		var capacity_left = tray_stack.get_capacity() - tray_stack.get_received_count()
		if capacity_left <= 0:
			break
		if matching_indices.size() > capacity_left:
			matching_indices = matching_indices.slice(0, capacity_left)
			
		var active_tray_node = tray_stack.get_active_tray_node()
		
		# 1. Animate food sprites from matching carriages into the active tray
		for delivery_idx in range(matching_indices.size()):
			var c_idx = matching_indices[delivery_idx]
			var c_node = carriage_sprites[c_idx]
			
			var food_sprite: Sprite2D = null
			for child in c_node.get_children():
				if child is Sprite2D:
					food_sprite = child
					break
					
			if food_sprite and active_tray_node:
				var global_pos = food_sprite.global_position
				var global_scale = food_sprite.global_scale
				
				c_node.remove_child(food_sprite)
				active_tray_node.add_child(food_sprite)
				food_sprite.global_position = global_pos
				food_sprite.global_scale = global_scale
				
				var slot_pos = tray_stack.get_next_slot_position()
				var count = tray_stack.get_received_count()
				food_sprite.z_index = 10 + count
				
				var tween = create_tween()
				tween.set_parallel(true)
				var delay = delivery_idx * 0.1
				tween.tween_property(food_sprite, "position", slot_pos, 0.3).set_ease(Tween.EASE_OUT).set_delay(delay)
				tween.tween_property(food_sprite, "scale", Vector2(0.24, 0.24), 0.3).set_delay(delay)
				
				tray_stack.add_food_to_active_tray(food_sprite)
				
			# Fade out and shrink empty carriage
			var c_tween = create_tween()
			c_tween.set_parallel(true)
			var c_delay = delivery_idx * 0.1 + 0.05
			c_tween.tween_property(c_node, "modulate:a", 0.0, 0.2).set_delay(c_delay)
			c_tween.tween_property(c_node, "scale", c_node.scale * 0.5, 0.2).set_delay(c_delay)
			c_tween.chain().tween_callback(c_node.queue_free)
			
			on_food_delivered.emit(station.required_food_id, active_food)
			
		var anim_wait = matching_indices.size() * 0.1 + 0.35
		await get_tree().create_timer(anim_wait).timeout
		
		# 2. Recompact arrays and slide remaining carriages forward along path_history to fill gaps
		var new_carriages: Array[String] = []
		var new_sprites: Array[Sprite2D] = []
		var max_shift_steps: int = 0
		
		var new_idx = 0
		for old_idx in range(carriages.size()):
			if old_idx in matching_indices:
				continue
				
			var f_id = carriages[old_idx]
			var sprite = carriage_sprites[old_idx]
			new_carriages.append(f_id)
			new_sprites.append(sprite)
			
			var orig_path_idx = path_history.size() - 2 - old_idx
			var target_path_idx = path_history.size() - 2 - new_idx
			var shift_steps = target_path_idx - orig_path_idx
			
			if shift_steps > 0:
				max_shift_steps = max(max_shift_steps, shift_steps)
				var shift_tween = create_tween()
				var step_duration = 0.12
				for s in range(orig_path_idx + 1, target_path_idx + 1):
					if s >= 0 and s < path_history.size():
						var curr_cell = path_history[s]
						var prev_cell = path_history[s - 1]
						var target_pos = _get_cell_world_pos(curr_cell)
						var step_rot = _get_angle_for_dir(curr_cell - prev_cell)
						shift_tween.tween_property(sprite, "position", target_pos, step_duration).set_ease(Tween.EASE_IN_OUT)
						shift_tween.parallel().tween_property(sprite, "rotation_degrees", step_rot, step_duration)
						
			new_idx += 1
			
		carriages = new_carriages
		carriage_sprites = new_sprites
		
		if max_shift_steps > 0:
			await get_tree().create_timer(max_shift_steps * 0.12 + 0.05).timeout
			
		# 3. ONLY pop if the active tray is filled to its maximum capacity of 9 items!
		if tray_stack.is_active_tray_full():
			tray_stack.pop_active_tray()
			await get_tree().create_timer(0.45).timeout
			# The loop now cascades to the NEXT tray in the stack with the remaining carriages!
		else:
			# Not full yet (less than 9 items): do NOT pop!
			break
			
	# All deliveries at this station finished.
	# Level completes ONLY if all foods on track collected, all carriages empty, AND all station trays filled with 9 items!
	if foods_dict.is_empty() and carriages.is_empty() and _are_all_stations_completed():
		level_completed.emit()
		current_state = State.STOPPED
		return
		
	_resume_after_delivery()

func _fallback_station_delivery(found_station_info: Dictionary) -> void:
	var station = found_station_info.data
	var station_node = found_station_info.node
	if not found_station_info.has("received_count"):
		found_station_info["received_count"] = 0
		
	var delivery_idx = 0
	while carriages.size() > 0:
		carriages.pop_front()
		var c = carriage_sprites.pop_front()
		var food_sprite: Sprite2D = null
		for child in c.get_children():
			if child is Sprite2D:
				food_sprite = child
				break
		if food_sprite:
			var global_pos = food_sprite.global_position
			var global_scale = food_sprite.global_scale
			c.remove_child(food_sprite)
			station_node.add_child(food_sprite)
			food_sprite.global_position = global_pos
			food_sprite.global_scale = global_scale
			var count = found_station_info["received_count"]
			var row = count / 3
			var col = count % 3
			var offset_x = (col - 1) * 60.0
			var offset_y = (row - 1) * 60.0
			food_sprite.z_index = 10 + count
			var tween = create_tween()
			tween.set_parallel(true)
			var delay = delivery_idx * 0.15
			tween.tween_property(food_sprite, "position", Vector2(offset_x, offset_y), 0.3).set_ease(Tween.EASE_OUT).set_delay(delay)
			tween.tween_property(food_sprite, "scale", Vector2(0.24, 0.24), 0.3).set_delay(delay)
			found_station_info["received_count"] += 1
		c.queue_free()
		delivery_idx += 1
		
	on_food_delivered.emit(station.required_food_id, station.required_food_id)
	if foods_dict.is_empty() and carriages.is_empty() and _are_all_stations_completed():
		level_completed.emit()
		current_state = State.STOPPED
		return
	_resume_after_delivery()

func _resume_after_delivery() -> void:
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
	
	# Filter out any static obstacles (allow animated ones so we can wait at them)
	var safe_exits = []
	for ex in valid_exits:
		var target_cell = current_grid_pos + ex
		var is_safe = true
		if obstacles_dict.has(target_cell):
			var obs = obstacles_dict[target_cell].get("node")
			if not obs or not obs.has_method("open"):
				is_safe = false
		if is_safe:
			safe_exits.append(ex)
			
	valid_exits = safe_exits
	
	if valid_exits.size() == 0:
		# Dead end
		current_state = State.STOPPED
		if carriages.size() > 0:
			on_crashed.emit()
			print("GAME OVER! Stuck at dead end with carriages!")
	elif valid_exits.size() == 1:
		# Forced path
		current_dir = valid_exits[0]
		_calculate_next_target()
		current_state = State.MOVING
	else:
		# Junction
		current_state = State.WAITING_AT_JUNCTION

func _calculate_next_target() -> void:
	var next_pos = current_grid_pos + current_dir
	target_world_pos = _get_cell_world_pos(next_pos)
	
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
	var target_cell = pos + dir
	# Reject if the target cell has a static obstacle
	if obstacles_dict.has(target_cell):
		var obs = obstacles_dict[target_cell].get("node")
		if not obs or not obs.has_method("open"):
			return false
	
	var track: TrackCellData = track_dict.get(pos, null)
	if not track: return false
	
	if dir == Vector2i(0, -1) and track.connect_up: return true
	if dir == Vector2i(0, 1) and track.connect_down: return true
	if dir == Vector2i(-1, 0) and track.connect_left: return true
	if dir == Vector2i(1, 0) and track.connect_right: return true
	return false

func _resume_from_obstacle() -> void:
	if current_state == State.STOPPED:
		print("Obstacle opened! Train resuming...")
		_calculate_next_target()
		current_state = State.MOVING
