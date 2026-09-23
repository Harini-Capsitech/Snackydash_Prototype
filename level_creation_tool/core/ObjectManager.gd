class_name ObjectManager
extends Node

var train_spawn: TrainSpawnData = null
var foods: Dictionary = {} # Key: Vector2i, Value: FoodData
var stations: Dictionary = {} # Key: Vector2i, Value: StationData
var obstacles: Dictionary = {} # Key: Vector2i, Value: ObstacleData

var grid: EditorGrid

func _init(p_grid: EditorGrid) -> void:
	grid = p_grid

func clear_all() -> void:
	train_spawn = null
	foods.clear()
	stations.clear()
	obstacles.clear()

# Train
func set_train_spawn(pos: Vector2i, facing: Vector2i) -> void:
	if not grid.is_within_bounds(pos): return
	if train_spawn == null:
		train_spawn = TrainSpawnData.new()
	train_spawn.position = pos
	train_spawn.facing_direction = facing

func remove_train_spawn() -> void:
	train_spawn = null

# Food
func add_food(pos: Vector2i, food_id: String) -> void:
	if not grid.is_within_bounds(pos): return
	var food = FoodData.new()
	food.position = pos
	food.food_id = food_id
	foods[pos] = food

func remove_food(pos: Vector2i) -> void:
	foods.erase(pos)

# Station
func add_station(pos: Vector2i, required_food_id: String) -> void:
	if not grid.is_within_bounds(pos): return
	var station = StationData.new()
	station.position = pos
	station.required_food_id = required_food_id
	stations[pos] = station

func remove_station(pos: Vector2i) -> void:
	stations.erase(pos)

# Obstacle
func add_obstacle(pos: Vector2i, obstacle_type: String) -> void:
	if not grid.is_within_bounds(pos): return
	var obs = ObstacleData.new()
	obs.position = pos
	obs.obstacle_type = obstacle_type
	obstacles[pos] = obs

func remove_obstacle(pos: Vector2i) -> void:
	obstacles.erase(pos)

func has_object_at(pos: Vector2i) -> bool:
	if train_spawn != null and train_spawn.position == pos: return true
	if foods.has(pos): return true
	if stations.has(pos): return true
	if obstacles.has(pos): return true
	return false
