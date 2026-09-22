extends Node2D

enum GameState { PLAYING, MOVING, LEVEL_COMPLETE }

var state = GameState.PLAYING

@onready var grid_manager = $GridManager
@onready var input_manager = $InputManager
@onready var player = $Player
@onready var items_container = $Items
@onready var trucks_container = $Trucks
@onready var walls_container = $Walls
@onready var ui_layer = $UI
@onready var level_complete_label = $UI/LevelCompleteLabel
@onready var debug_label = $UI/DebugLabel

var fruits: Array[Fruit] = []
var trucks: Array[Truck] = []
var level_data: LevelData
var solver_result: Dictionary = {}

func _ready():
	level_complete_label.visible = false
	_load_level()
	input_manager.connect("swipe_detected", Callable(self, "_on_swipe_detected"))
	player.movement.connect("move_started", Callable(self, "_on_player_move_started"))
	player.movement.connect("move_finished", Callable(self, "_on_player_move_finished"))

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and has_node("/root/LevelSession"):
		get_tree().change_scene_to_file(LevelSession.editor_path)

func _load_level():
	level_data = _load_level_data()
	var builder := LevelBuilder.new()
	add_child(builder)
	var built := builder.build(level_data, grid_manager, player, items_container, trucks_container, walls_container)
	fruits = built["fruits"]
	trucks = built["trucks"]
	solver_result = LevelSolver.solve(level_data)
	_update_debug()

func _load_level_data() -> LevelData:
	var requested_path := "res://levels/level_001.tres"
	var session := get_node_or_null("/root/LevelSession")
	if session != null and session.get("level_path") != "":
		requested_path = session.get("level_path")
	var loaded = load(requested_path)
	if loaded is LevelData:
		return loaded
	return LevelData.from_dictionary({"level_id": 1, "width": 1, "height": 1, "road_cells": [Vector2i.ZERO], "player_start": Vector2i.ZERO})

func _on_swipe_detected(direction: Vector2i):
	if state == GameState.PLAYING:
		player.movement.try_move(direction)

func _on_player_move_started():
	state = GameState.MOVING

func _on_player_move_finished(path: Array[Vector2i]):
	# Process path for fruits
	for cell in path:
		for f in fruits:
			if not f.collected and f.grid_cell == cell:
				f.collect()
				player.add_fruit(f.type)
				
	# Check for tail collision
	if player.movement.current_cell in player.tail_cells:
		state = GameState.LEVEL_COMPLETE
		level_complete_label.text = "GAME OVER"
		level_complete_label.modulate = Color.RED
		level_complete_label.visible = true
		return
				
	# Check trucks at final cell
	for t in trucks:
		if t.grid_cell == player.movement.current_cell:
			if t.can_deliver(player):
				t.deliver(player)
				
	state = GameState.PLAYING
	_update_debug()
	_check_win_condition()

func _check_win_condition():
	var all_done = true
	for t in trucks:
		if not t.completed:
			all_done = false
			break
			
	if all_done:
		state = GameState.LEVEL_COMPLETE
		level_complete_label.visible = true

func _update_debug():
	var text = "Level %d | Player: %s\n" % [level_data.level_id, player.movement.current_cell]
	text += "Solver: %s (%d nodes)\n" % [solver_result.get("message", "not run"), solver_result.get("node_count", 0)]
	text += "Inventory:\n"
	for k in player.inventory:
		text += k + ": " + str(player.inventory[k]) + "\n"
	text += "\nTrucks:\n"
	for t in trucks:
		text += t.required_type + " " + str(t.delivered_amount) + "/" + str(t.required_amount) + "\n"
	debug_label.text = text
