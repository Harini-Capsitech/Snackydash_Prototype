## GameEngine simulates the authentic Snacky Dash mechanics:
## Autonomous node-to-node dashing, purple chevron trajectory previews,
## dynamic tail-length inventory (grows on pickup, shrinks on delivery),
## self-collision failure, stacked 3x3 crate delivery, and dynamic fruit respawning.
class_name GameEngine
extends Node

const GameConfig = preload("res://scripts/game_config.gd")
const LevelData = preload("res://scripts/level_data.gd")
const LevelModel = preload("res://scripts/level_model.gd")
const TrackGraph = preload("res://scripts/track_graph.gd")

signal level_loaded(level_info: Dictionary)
signal state_updated()
signal aim_changed(preview_path: Array[Vector2i], dir: Vector2i)
signal fruit_eaten(fruit_type: String, pos: Vector2i)
signal cargo_delivered(fruit_type: String, crate_index: int)
signal crate_completed(crate_info: Dictionary)
signal fruits_respawned()
signal self_collision_lost()
signal level_won()
signal action_failed(reason: String)

var current_level_info: Dictionary = {}
var rows: int = 0
var cols: int = 0
var grid: Array = []

# Snake state: Head (index 0) + Trailing open wagon trays (index 1..N)
# Array of { "pos": Vector2i, "layer": int, "fruit_type": String }
var snake: Array = []
var snake_dir: Vector2i = Vector2i(0, -1)

var fruits: Array = []
var bridges: Array = []

# Crate Stack system (3x3 crates stacked by color)
var crate_stack: Array = []
var active_crate_idx: int = 0
var crate_dock: Vector2i = Vector2i(-1, -1)

var aim_direction: Vector2i = Vector2i.ZERO
var preview_path: Array[Vector2i] = []

var is_dashing: bool = false
@export var dash_step_delay: float = 0.075 # Seconds per corridor step (smooth arcade travel)
var active_dash_path: Array[Vector2i] = []
var active_dash_idx: int = 0
var dash_step_timer: float = 0.0
var moves_count: int = 0
var history: Array = []
var is_won: bool = false
var is_lost: bool = false

func _process(delta: float) -> void:
	if not is_dashing or active_dash_path.is_empty():
		return
		
	dash_step_timer += delta
	if dash_step_timer >= dash_step_delay:
		dash_step_timer = 0.0
		if active_dash_idx < active_dash_path.size():
			var target_pos = active_dash_path[active_dash_idx]
			active_dash_idx += 1
			var step_ok = execute_single_step(target_pos)
			state_updated.emit()
			
			if not step_ok or is_lost or is_won or active_dash_idx >= active_dash_path.size():
				is_dashing = false
				active_dash_path.clear()
				check_and_respawn_fruits()
				check_win_condition()
				state_updated.emit()

func load_level(level_source) -> void:
	var data: Dictionary = {}
	if level_source is LevelModel:
		data = level_source.create_instance_data()
	elif level_source is Dictionary:
		if level_source.has("grid"):
			data = level_source.duplicate(true)
		else:
			var parsed_model = LevelData.parse_level(level_source)
			data = parsed_model.create_instance_data()
			
	current_level_info = data
	rows = data["rows"]
	cols = data["cols"]
	grid = data["grid"].duplicate(true)
	
	var start_pos: Vector2i = data["snake_start"]
	snake_dir = Vector2i(0, -1)
	snake.clear()
	snake.append({
		"pos": start_pos,
		"layer": GameConfig.Layer.GROUND,
		"fruit_type": ""
	})
	
	fruits = data["fruits"].duplicate(true)
	bridges = data.get("bridges", []).duplicate(true)
	crate_dock = data.get("crate_dock", Vector2i(-1, -1))
	
	crate_stack.clear()
	var raw_crates: Array = data.get("crates", [])
	for c_def in raw_crates:
		crate_stack.append({
			"color": c_def.get("color", Color("#e11d48")),
			"fruit": c_def.get("fruit", "R"),
			"capacity": c_def.get("capacity", 9),
			"filled": 0
		})
	active_crate_idx = 0
	
	aim_direction = Vector2i.ZERO
	preview_path.clear()
	is_dashing = false
	moves_count = 0
	history.clear()
	is_won = false
	is_lost = false
	is_dashing = false
	active_dash_path.clear()
	active_dash_idx = 0
	dash_step_timer = 0.0
	
	check_and_respawn_fruits()
	level_loaded.emit(current_level_info)
	state_updated.emit()

func restart() -> void:
	if not current_level_info.is_empty():
		load_level(current_level_info)

# ==============================================================================
# AIMING & TRAJECTORY PREVIEW (Purple Chevrons)
# ==============================================================================
func set_aim_direction(dir: Vector2i) -> void:
	if is_dashing or is_won or is_lost or snake.is_empty():
		return
	if dir == aim_direction:
		return
		
	aim_direction = dir
	if dir == Vector2i.ZERO:
		preview_path.clear()
	else:
		var head_pos: Vector2i = snake[0]["pos"]
		preview_path = TrackGraph.trace_path_to_next_junction(head_pos, dir, grid, rows, cols)
		
	aim_changed.emit(preview_path, aim_direction)
	state_updated.emit()

func clear_aim() -> void:
	set_aim_direction(Vector2i.ZERO)

# ==============================================================================
# AUTONOMOUS NODE-TO-NODE DASH EXECUTION
# ==============================================================================
func confirm_dash(immediate: bool = false) -> bool:
	if is_dashing or is_won or is_lost or preview_path.is_empty():
		return false
		
	var path_to_run: Array[Vector2i] = preview_path.duplicate()
	clear_aim()
	return execute_dash_path(path_to_run, immediate)

func execute_dash_path(path: Array[Vector2i], immediate: bool = false) -> bool:
	if path.is_empty() or is_dashing or is_won or is_lost:
		return false
		
	save_snapshot()
	moves_count += 1
	
	if immediate:
		# Synchronous execution for automated test suites
		is_dashing = true
		for target_pos in path:
			var ok = execute_single_step(target_pos)
			if not ok or is_lost or is_won:
				break
		is_dashing = false
		check_and_respawn_fruits()
		check_win_condition()
		state_updated.emit()
		return true
	else:
		# Animated step-by-step corridor travel matching mobile gameplay
		active_dash_path = path
		active_dash_idx = 0
		dash_step_timer = 0.0
		is_dashing = true
		state_updated.emit()
		return true

func execute_single_step(target_pos: Vector2i) -> bool:
	var prev_head_pos: Vector2i = snake[0]["pos"]
	var prev_head_layer: int = snake[0]["layer"]
	var step_dir: Vector2i = target_pos - prev_head_pos
	snake_dir = step_dir
	
	var target_tile: String = grid[target_pos.y][target_pos.x]
	var target_layer: int = GameConfig.Layer.GROUND
	if target_tile == GameConfig.TILE_BRIDGE:
		target_layer = GameConfig.Layer.OVERPASS if step_dir.x != 0 else GameConfig.Layer.UNDERPASS
		
	# 1. COLLISION DETECTION (Hit Yourself = Lose!)
	var hit_tail: bool = false
	for i in range(1, snake.size()):
		var seg = snake[i]
		if seg["pos"] == target_pos:
			if target_tile == GameConfig.TILE_BRIDGE and seg["layer"] != target_layer:
				continue
			hit_tail = true
			break
			
	if hit_tail:
		is_lost = true
		is_dashing = false
		self_collision_lost.emit()
		return false
		
	# 2. FRUIT COLLECTION & DYNAMIC TAIL EXPANSION
	var eaten_fruit_idx: int = -1
	for fi in range(fruits.size()):
		if not fruits[fi]["collected"] and fruits[fi]["pos"] == target_pos:
			eaten_fruit_idx = fi
			break
			
	if eaten_fruit_idx != -1:
		# Collect fruit: Snake length physically increases by 1!
		fruits[eaten_fruit_idx]["collected"] = true
		var eaten_type = fruits[eaten_fruit_idx]["type"]
		
		var new_wagon = {
			"pos": prev_head_pos,
			"layer": prev_head_layer,
			"fruit_type": eaten_type
		}
		snake[0]["pos"] = target_pos
		snake[0]["layer"] = target_layer
		snake.insert(1, new_wagon)
		
		fruit_eaten.emit(eaten_type, target_pos)
	else:
		# Normal movement: Head advances, wagons follow previous segment
		for si in range(snake.size() - 1, 0, -1):
			snake[si]["pos"] = snake[si - 1]["pos"]
			snake[si]["layer"] = snake[si - 1]["layer"]
		snake[0]["pos"] = target_pos
		snake[0]["layer"] = target_layer
		
	# 3. CRATE DELIVERY & DYNAMIC TAIL SHRINKING
	process_crate_delivery(target_pos)
	return true

# ==============================================================================
# CRATE DELIVERY & DYNAMIC TAIL SHRINKING
# When matching fruits are deposited into the tray, the snake trail physically
# shortens by the exact count delivered, retaining any un-delivered fruits!
# ==============================================================================
func process_crate_delivery(current_pos: Vector2i) -> void:
	if crate_stack.is_empty() or active_crate_idx >= crate_stack.size():
		return
		
	var is_at_dock = (current_pos == crate_dock)
	if not is_at_dock and crate_dock != Vector2i(-1, -1):
		var diff = (current_pos - crate_dock).abs()
		if (diff.x + diff.y) == 1:
			is_at_dock = true
			
	if not is_at_dock:
		return
		
	var delivered_any = false
	
	while active_crate_idx < crate_stack.size():
		var active_crate = crate_stack[active_crate_idx]
		var needed_fruit: String = active_crate["fruit"]
		var space_left: int = active_crate["capacity"] - active_crate["filled"]
		
		if space_left <= 0:
			crate_completed.emit(active_crate)
			active_crate_idx += 1
			continue
			
		# Find matching fruit in snake wagons (index 1..N)
		var matching_idx = -1
		for i in range(1, snake.size()):
			if snake[i]["fruit_type"] == needed_fruit:
				matching_idx = i
				break
				
		if matching_idx == -1:
			break # No matching fruits carried for this crate tray
			
		# Deliver 1 fruit into active tray
		active_crate["filled"] += 1
		delivered_any = true
		cargo_delivered.emit(needed_fruit, active_crate_idx)
		
		# Shorten the snake trail by exactly 1 segment!
		# Remove delivered fruit from cargo list, pop the last wagon, and reassign
		var carried: Array[String] = []
		for i in range(1, snake.size()):
			carried.append(snake[i]["fruit_type"])
			
		carried.erase(needed_fruit)
		snake.pop_back()
		
		for j in range(carried.size()):
			snake[j + 1]["fruit_type"] = carried[j]
			
		if active_crate["filled"] >= active_crate["capacity"]:
			crate_completed.emit(active_crate)
			active_crate_idx += 1
			
	if delivered_any:
		state_updated.emit()

# ==============================================================================
# DYNAMIC FRUIT RESPAWN
# ==============================================================================
func check_and_respawn_fruits() -> void:
	if is_won or is_lost or crate_stack.is_empty():
		return
		
	var needed_counts: Dictionary = {}
	for c in crate_stack:
		var rem = c["capacity"] - c["filled"]
		if rem > 0:
			needed_counts[c["fruit"]] = needed_counts.get(c["fruit"], 0) + rem
			
	if needed_counts.is_empty():
		return
		
	for seg in snake:
		var f_type = seg["fruit_type"]
		if not f_type.is_empty() and needed_counts.has(f_type):
			needed_counts[f_type] -= 1
			
	var uncollected_on_board = 0
	for f in fruits:
		if not f["collected"]:
			uncollected_on_board += 1
			if needed_counts.has(f["type"]):
				needed_counts[f["type"]] -= 1
				
	if uncollected_on_board == 0:
		var occupied_tiles: Dictionary = {}
		for seg in snake:
			occupied_tiles[seg["pos"]] = true
		for f in fruits:
			if not f["collected"]:
				occupied_tiles[f["pos"]] = true
		if crate_dock != Vector2i(-1, -1):
			occupied_tiles[crate_dock] = true
			
		var candidate_tiles: Array[Vector2i] = []
		for r in range(rows):
			for c in range(cols):
				var pos = Vector2i(c, r)
				if grid[r][c] != GameConfig.TILE_WALL and not occupied_tiles.has(pos):
					candidate_tiles.append(pos)
					
		candidate_tiles.shuffle()
		var did_spawn = false
		
		for fruit_key in needed_counts.keys():
			var count_to_spawn = needed_counts[fruit_key]
			if count_to_spawn <= 0:
				var active_crate = crate_stack[active_crate_idx] if active_crate_idx < crate_stack.size() else null
				if active_crate and active_crate["fruit"] == fruit_key and active_crate["filled"] < active_crate["capacity"]:
					count_to_spawn = active_crate["capacity"] - active_crate["filled"]
					
			var spawned = 0
			while not candidate_tiles.is_empty() and spawned < count_to_spawn:
				var spawn_pos = candidate_tiles.pop_back()
				fruits.append({
					"pos": spawn_pos,
					"type": fruit_key,
					"collected": false
				})
				spawned += 1
				did_spawn = true
				
		if did_spawn:
			fruits_respawned.emit()
			state_updated.emit()

# ==============================================================================
# WIN CONDITION
# ==============================================================================
func check_win_condition() -> void:
	if crate_stack.is_empty():
		var all_fruits_done = true
		for f in fruits:
			if not f["collected"]:
				all_fruits_done = false
				break
		if all_fruits_done:
			is_won = true
			level_won.emit()
		return
		
	var all_crates_full = true
	for c in crate_stack:
		if c["filled"] < c["capacity"]:
			all_crates_full = false
			break
			
	if all_crates_full:
		is_won = true
		level_won.emit()

func save_snapshot() -> void:
	var snap = {
		"snake": snake.duplicate(true),
		"snake_dir": snake_dir,
		"fruits": fruits.duplicate(true),
		"crate_stack": crate_stack.duplicate(true),
		"active_crate_idx": active_crate_idx,
		"moves_count": moves_count,
		"is_won": is_won,
		"is_lost": is_lost
	}
	history.append(snap)
	if history.size() > 60:
		history.pop_front()

func undo() -> bool:
	if is_dashing or history.is_empty() or is_won:
		return false
	var prev = history.pop_back()
	snake = prev["snake"].duplicate(true)
	snake_dir = prev["snake_dir"]
	fruits = prev["fruits"].duplicate(true)
	crate_stack = prev["crate_stack"].duplicate(true)
	active_crate_idx = prev["active_crate_idx"]
	moves_count = prev["moves_count"]
	is_won = prev["is_won"]
	is_lost = prev["is_lost"]
	is_dashing = false
	clear_aim()
	state_updated.emit()
	return true
