class_name LevelLoader
extends Node2D

@export var level_file: String = "res://level_creation_tool/Level_001.tres"
@export var track_config: TrackVisualConfig
@export var train_config: TrainVisualConfig
@export var food_config: FoodVisualConfig
@export var station_config: StationVisualConfig

var track_dict: Dictionary = {}
var foods_dict: Dictionary = {}
var stations_dict: Dictionary = {}
var obstacles_dict: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(level_file):
		var level_data: RailwayLevelData = ResourceLoader.load(level_file) as RailwayLevelData
		if level_data:
			_spawn_level(level_data)
		else:
			printerr("Failed to cast loaded resource to RailwayLevelData.")
	else:
		printerr("Level file does not exist: ", level_file)

func _spawn_level(data: RailwayLevelData) -> void:
	# Use the exact position the user set in the editor!
	self.position = data.level_offset
	
	# 1. Spawn Tracks visually using Godot's TileMap
	var tm: TileMap = null
	if data.tile_set:
		tm = TileMap.new()
		tm.tile_set = data.tile_set
		add_child(tm)
		for track in data.tracks:
			track_dict[track.position] = track
			tm.set_cell(0, track.position, track.source_id, track.atlas_coords)
	else:
		printerr("LevelData is missing a TileSet. Ensure you click Compile And Save in the updated editor.")
		for track in data.tracks:
			track_dict[track.position] = track

	# 2. Spawn Foods
	for f in data.foods:
		var sprite = Sprite2D.new()
		var tex = load(f.texture_path) if f.texture_path != "" else null
		if not tex and food_config: tex = food_config.get_texture_by_id(f.food_id)
		sprite.texture = tex
		sprite.position = f.visual_pos
		sprite.scale = f.visual_scale
		sprite.rotation = f.visual_rot
		add_child(sprite)
		foods_dict[f.position] = {"food_id": f.food_id, "node": sprite}

	# 3. Spawn Stations
	for s in data.stations:
		var stack = TrayStack.new()
		stack.name = "Station_" + str(s.position.x) + "_" + str(s.position.y)
		add_child(stack)
		stack.setup(s, station_config)
		stations_dict[s.position] = {"data": s, "node": stack, "tray_stack": stack}
		
	# 3.5 Spawn Obstacles
	for o in data.obstacles:
		var sprite = Sprite2D.new()
		var tex = load(o.texture_path) if o.texture_path != "" else null
		if tex:
			sprite.texture = tex
		sprite.position = o.visual_pos
		sprite.scale = o.visual_scale
		sprite.rotation = o.visual_rot
		add_child(sprite)
		obstacles_dict[o.position] = {"data": o, "node": sprite}
		
	# 4. Spawn Train
	if data.train_spawn:
		var train = TrainController.new()
		train.tile_map = tm
		var eng_tex = load(data.train_spawn.texture_path) if data.train_spawn.texture_path != "" else null
		if not eng_tex and train_config: eng_tex = train_config.train_engine
		var car_tex = train_config.food_carriage if train_config else null
		
		var sprite = Sprite2D.new()
		sprite.texture = eng_tex
		sprite.scale = data.train_spawn.visual_scale
		sprite.rotation = data.train_spawn.visual_rot
		
		train.position = data.train_spawn.visual_pos
		train.add_child(sprite)
		add_child(train)
		train.setup(data, track_dict, foods_dict, stations_dict, obstacles_dict, self, car_tex)
