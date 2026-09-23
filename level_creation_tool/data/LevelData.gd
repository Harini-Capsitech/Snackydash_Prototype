class_name RailwayLevelData
extends Resource

@export var level_id: String = "Level_001"
@export var level_name: String = "New Level"
@export var grid_width: int = 12
@export var grid_height: int = 18
@export var cell_size: int = 64
@export var level_offset: Vector2 = Vector2.ZERO
@export var tile_set: TileSet

# Arrays of Resources
@export var tracks: Array[TrackCellData] = []
@export var train_spawn: TrainSpawnData = null
@export var foods: Array[FoodData] = []
@export var stations: Array[StationData] = []
@export var obstacles: Array[ObstacleData] = []

func to_dict() -> Dictionary:
	var track_dicts = []
	for t in tracks:
		track_dicts.append(t.to_dict())
		
	var food_dicts = []
	for f in foods:
		food_dicts.append(f.to_dict())
		
	var station_dicts = []
	for s in stations:
		station_dicts.append(s.to_dict())
		
	var obstacle_dicts = []
	for o in obstacles:
		obstacle_dicts.append(o.to_dict())

	return {
		"level_id": level_id,
		"level_name": level_name,
		"grid_width": grid_width,
		"grid_height": grid_height,
		"cell_size": cell_size,
		"tracks": track_dicts,
		"train_spawn": train_spawn.to_dict() if train_spawn else null,
		"foods": food_dicts,
		"stations": station_dicts,
		"obstacles": obstacle_dicts
	}

func from_dict(data: Dictionary) -> void:
	level_id = data.get("level_id", "Level_001")
	level_name = data.get("level_name", "New Level")
	grid_width = data.get("grid_width", 12)
	grid_height = data.get("grid_height", 18)
	cell_size = data.get("cell_size", 64)
	
	tracks.clear()
	for t_data in data.get("tracks", []):
		var t = TrackCellData.new()
		t.from_dict(t_data)
		tracks.append(t)
		
	if data.has("train_spawn") and data["train_spawn"] != null:
		train_spawn = TrainSpawnData.new()
		train_spawn.from_dict(data["train_spawn"])
	else:
		train_spawn = null
		
	foods.clear()
	for f_data in data.get("foods", []):
		var f = FoodData.new()
		f.from_dict(f_data)
		foods.append(f)
		
	stations.clear()
	for s_data in data.get("stations", []):
		var s = StationData.new()
		s.from_dict(s_data)
		stations.append(s)
		
	obstacles.clear()
	for o_data in data.get("obstacles", []):
		var o = ObstacleData.new()
		o.from_dict(o_data)
		obstacles.append(o)
