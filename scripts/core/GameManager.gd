extends Node2D

enum GameState { PLAYING, MOVING, LEVEL_COMPLETE }

var state = GameState.PLAYING

@onready var grid_manager = $GridManager
@onready var input_manager = $InputManager
@onready var ui_layer = $UI
@onready var level_complete_label = $UI/LevelCompleteLabel
@onready var debug_label = $UI/DebugLabel

var player: Player
var items_container: Node2D
var trucks_container: Node2D
var walls_container: Node2D

var fruits: Array[Fruit] = []
var trucks: Array[Truck] = []
var level_data: LevelData
var solver_result: Dictionary = {}

func _ready():
	level_complete_label.visible = false
	_load_level()
	input_manager.connect("aim_direction_changed", Callable(self, "_on_aim_direction_changed"))
	input_manager.connect("drag_released", Callable(self, "_on_drag_released"))

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_cancel") and has_node("/root/LevelSession"):
		get_tree().change_scene_to_file(LevelSession.editor_path)

func _load_level():
	level_data = _load_level_data()
	var builder := LevelBuilder.new()
	add_child(builder)
	var built := builder.build(level_data, grid_manager, self)
	
	player = built["player"]
	items_container = built["items_container"]
	trucks_container = built["trucks_container"]
	walls_container = built["walls_container"]
	fruits = built["fruits"]
	trucks = built["trucks"]
	
	player.movement.connect("dash_started", Callable(self, "_on_player_dash_started"))
	player.movement.connect("cell_crossed", Callable(self, "_on_cell_crossed"))
	player.movement.connect("dash_finished", Callable(self, "_on_player_dash_finished"))
	player.movement.connect("hit_obstacle", Callable(self, "_on_player_hit_obstacle"))
	
	solver_result = LevelSolver.solve(level_data)
	_update_debug()

func _load_level_data() -> LevelData:
	var requested_path := "res://levels_scenes/level_example1.tres"
	var session := get_node_or_null("/root/LevelSession")
	if session != null and session.get("level_path") != "":
		requested_path = session.get("level_path")
	var loaded = ResourceLoader.load(requested_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded is LevelData:
		return loaded as LevelData
	return LevelData.new()

func _on_aim_direction_changed(direction: Vector2i):
	if state == GameState.PLAYING:
		player.movement.set_aim(direction)

func _on_drag_released():
	if state == GameState.PLAYING:
		player.movement.confirm_dash()

func _on_player_dash_started():
	state = GameState.MOVING

func _on_cell_crossed(old_cell: Vector2i, new_cell: Vector2i):
	# Process fruits on the new cell
	for f in fruits:
		if not f.collected and f.grid_cell == new_cell:
			f.collect()
			player.add_fruit(f.type)
			
	player.update_tail(old_cell)
			
	# Check for tail collision
	if new_cell in player.get_tail_cells():
		state = GameState.LEVEL_COMPLETE
		level_complete_label.text = "GAME OVER"
		level_complete_label.modulate = Color.RED
		level_complete_label.visible = true
		return
				
	_update_debug()

func _on_player_hit_obstacle(cell: Vector2i):
	# Check trucks at the obstacle cell
	for t in trucks:
		if t.occupies_cell(cell):
			if t.can_deliver(player):
				t.deliver(player)
				_check_win_condition()
				_update_debug()

func _on_player_dash_finished():
	state = GameState.PLAYING
	_update_debug()

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
	var text = "Level %s | Player: %s\n" % [level_data.level_name, player.movement.current_cell]
	text += "Solver: %s (%d nodes)\n" % [solver_result.get("message", "not run"), solver_result.get("node_count", 0)]
	text += "Inventory:\n"
	for k in player.inventory:
		text += k + ": " + str(player.inventory[k]) + "\n"
	text += "\nTrucks:\n"
	for t in trucks:
		if t.crates.is_empty():
			text += "Truck: Done\n"
		else:
			var active = t.crates[0]
			text += "Truck: " + active["type"] + " " + str(active.get("delivered", 0)) + "/" + str(active["amount"]) + "\n"
	debug_label.text = text
