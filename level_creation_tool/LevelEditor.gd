@tool
class_name RailwayLevelEditor
extends Node2D

@export_category("Level Output")
@export var level_id: String = "Level_001"
@export var level_name: String = "New Level"
@export var grid_width: int = 12
@export var grid_height: int = 18
@export var cell_size: int = 64
@export var save_path: String = "res://level_creation_tool/"

@export_category("Actions")
@export var compile_and_save: bool = false:
	set(value):
		if not Engine.is_editor_hint(): return
		if value == true:
			_extract_and_save()
			compile_and_save = false
		else:
			compile_and_save = value

func _extract_and_save() -> void:
	var level_data = RailwayLevelData.new()
	level_data.level_id = level_id
	level_data.level_name = level_name
	level_data.grid_width = grid_width
	level_data.grid_height = grid_height
	level_data.level_offset = self.position
	var tm: TileMap = null
	for child in get_children():
		if child is TileMap:
			tm = child
			break
	if tm:
		level_data.tile_set = tm.tile_set
		
	_extract_tracks(level_data, tm)
	_extract_objects(level_data, tm)
	
	var errors = LevelValidator.validate_level(level_data)
	if errors.size() > 0:
		printerr("LEVEL INVALID:")
		for e in errors: printerr("- ", e)
	else:
		print("LEVEL VALID: All checks passed!")
	
	var full_path = save_path.path_join(level_id + ".tres")
	var err = ResourceSaver.save(level_data, full_path)
	if err == OK:
		print("Level saved successfully to: ", full_path)
	else:
		printerr("Failed to save level! Error code: ", err)

func _extract_tracks(data: RailwayLevelData, tm: TileMap) -> void:
	if not tm:
		printerr("No TileMap found as a child of RailwayLevelEditor!")
		return
		
	var used_cells = tm.get_used_cells(0)
	var cell_dict = {}
	for cell in used_cells:
		cell_dict[cell] = true
		
	for cell in used_cells:
		var track = TrackCellData.new(cell)
		track.atlas_coords = tm.get_cell_atlas_coords(0, cell)
		track.source_id = tm.get_cell_source_id(0, cell)
		
		# Auto-infer connections based on adjacent placed tiles
		if cell_dict.has(cell + Vector2i(0, -1)): track.connect_up = true
		if cell_dict.has(cell + Vector2i(0, 1)): track.connect_down = true
		if cell_dict.has(cell + Vector2i(-1, 0)): track.connect_left = true
		if cell_dict.has(cell + Vector2i(1, 0)): track.connect_right = true
		
		# Determine shape ID for basic reference if needed later
		var conns = 0
		if track.connect_up: conns += 1
		if track.connect_down: conns += 1
		if track.connect_left: conns += 1
		if track.connect_right: conns += 1
		track.track_type_id = "connections_" + str(conns)
		
		data.tracks.append(track)

func _extract_objects(data: RailwayLevelData, tm: TileMap) -> void:
	for child in get_children():
		if child is LevelObject:
			# Calculate grid position using TileMap exactly!
			var pos = tm.local_to_map(child.position) if tm else Vector2i(floor(child.position.x / cell_size), floor(child.position.y / cell_size))
			
			match child.type:
				LevelObject.ObjectType.TRAIN:
					var spawn = TrainSpawnData.new()
					spawn.position = pos
					spawn.facing_direction = child.train_facing
					spawn.visual_pos = child.position
					spawn.visual_scale = child.scale
					spawn.visual_rot = child.rotation
					if child is Sprite2D and child.texture: spawn.texture_path = child.texture.resource_path
					data.train_spawn = spawn
				LevelObject.ObjectType.FOOD:
					var food = FoodData.new()
					food.position = pos
					food.food_id = child.subtype_id
					food.visual_pos = child.position
					food.visual_scale = child.scale
					food.visual_rot = child.rotation
					if child is Sprite2D and child.texture: food.texture_path = child.texture.resource_path
					data.foods.append(food)
				LevelObject.ObjectType.STATION:
					var station = StationData.new()
					station.position = pos
					station.required_food_id = child.subtype_id
					station.visual_pos = child.position
					station.visual_scale = child.scale
					station.visual_rot = child.rotation
					if child is Sprite2D and child.texture: station.texture_path = child.texture.resource_path
					data.stations.append(station)
				LevelObject.ObjectType.OBSTACLE:
					var obs = ObstacleData.new()
					obs.position = pos
					obs.obstacle_type = child.subtype_id
					obs.visual_pos = child.position
					obs.visual_scale = child.scale
					obs.visual_rot = child.rotation
					if child is Sprite2D and child.texture: obs.texture_path = child.texture.resource_path
					data.obstacles.append(obs)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings = PackedStringArray()
	var has_tm = false
	for c in get_children():
		if c is TileMap:
			has_tm = true
	if not has_tm:
		warnings.append("RailwayLevelEditor requires a TileMap child node to parse tracks from.")
	return warnings
