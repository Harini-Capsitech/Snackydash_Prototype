extends Node2D

const LEVEL_DIR := "res://levels/"
const GAME_SCENE := "res://scenes/Game.tscn"
const CELL_MARGIN := 2.0

var data: LevelData
var grid := GridManager.new()
var tool := "ROAD"
var drag_start := Vector2i(-1, -1)
var drag_cell := Vector2i(-1, -1)
var type_option: OptionButton
var required_spin: SpinBox
var width_spin: SpinBox
var height_spin: SpinBox
var cell_spin: SpinBox
var level_spin: SpinBox
var status_label: Label
var results_label: Label
var override_check: CheckBox

func _ready() -> void:
	data = _load_level(1)
	_build_ui()
	_refresh_grid()
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	for y in range(data.height):
		for x in range(data.width):
			var cell := Vector2i(x, y)
			var rect := Rect2(grid.cell_to_world(cell) - Vector2(data.cell_size, data.cell_size) / 2.0 + Vector2.ONE, Vector2(data.cell_size, data.cell_size) - Vector2.ONE * 2.0)
			var color := Color("#20252a")
			if cell in data.road_cells:
				color = Color("#858b91")
			draw_rect(rect, color)
	for footprint in data.blocked_footprints:
		var position: Vector2i = footprint["position"]
		var size: Vector2i = footprint["size"]
		draw_rect(Rect2(grid.cell_to_world(position) - Vector2(data.cell_size, data.cell_size) / 2.0, Vector2(size.x * data.cell_size, size.y * data.cell_size)), Color("#4f7d54"))
	if data.player_start != Vector2i(-1, -1):
		draw_circle(grid.cell_to_world(data.player_start), data.cell_size * 0.32, Color("#3b9cff"))
	for fruit in data.fruits:
		draw_circle(grid.cell_to_world(fruit["position"]), data.cell_size * 0.25, _type_color(fruit["type"]))
	for truck in data.trucks:
		var truck_position: Vector2 = grid.cell_to_world(truck["position"])
		draw_rect(Rect2(truck_position - Vector2(data.cell_size, data.cell_size) * 0.32, Vector2(data.cell_size, data.cell_size) * 0.64), Color("#8a5a3b"))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := grid.world_to_cell(event.position)
		if event.pressed:
			drag_start = cell
			drag_cell = cell
			_paint(cell)
		else:
			if tool == "BLOCKED-FOOTPRINT":
				_paint_footprint(drag_start, cell)
			drag_start = Vector2i(-1, -1)
	elif event is InputEventMouseMotion and drag_start != Vector2i(-1, -1):
		drag_cell = grid.world_to_cell(event.position)
		if tool == "ROAD" or tool == "ERASE":
			_paint(drag_cell)
		queue_redraw()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 18)
	panel.size = Vector2(440, 210)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	_add_button(toolbar, "NEW", _new_level)
	_add_button(toolbar, "LOAD", _load_selected)
	_add_button(toolbar, "SAVE", _save_level)
	_add_button(toolbar, "VALIDATE", _validate)
	_add_button(toolbar, "TEST LEVEL", _test_level)
	var settings := HBoxContainer.new()
	column.add_child(settings)
	width_spin = _add_spin(settings, "W", data.width, 1, 40)
	height_spin = _add_spin(settings, "H", data.height, 1, 40)
	cell_spin = _add_spin(settings, "CELL", data.cell_size, 16, 128)
	level_spin = _add_spin(settings, "ID", data.level_id, 1, 9999)
	var tools := HBoxContainer.new()
	column.add_child(tools)
	var tool_option := OptionButton.new()
	for item in ["ROAD", "WALL/ERASE", "BLOCKED-FOOTPRINT", "PLAYER", "FRUIT", "TRUCK", "ERASE"]:
		tool_option.add_item(item)
	tool_option.item_selected.connect(func(index): tool = tool_option.get_item_text(index))
	tools.add_child(tool_option)
	type_option = OptionButton.new()
	for item in ["APPLE", "BANANA", "BERRY"]:
		type_option.add_item(item)
	tools.add_child(type_option)
	required_spin = _add_spin(tools, "REQ", 1, 1, 99)
	override_check = CheckBox.new()
	override_check.text = "Test unsolved"
	tools.add_child(override_check)
	status_label = Label.new()
	column.add_child(status_label)
	results_label = Label.new()
	results_label.custom_minimum_size = Vector2(420, 80)
	column.add_child(results_label)

func _paint(cell: Vector2i) -> void:
	if not _inside(cell):
		return
	if tool == "ROAD":
		if cell not in data.road_cells:
			data.road_cells.append(cell)
	elif tool == "ERASE" or tool == "WALL/ERASE":
		data.road_cells.erase(cell)
		if data.player_start == cell:
			data.player_start = Vector2i(-1, -1)
		_remove_at(data.fruits, cell)
		_remove_at(data.trucks, cell)
	elif tool == "PLAYER":
		if cell in data.road_cells:
			data.player_start = cell
		else:
			_set_status("Player rejected: target is not a road cell.")
	elif tool == "FRUIT":
		if cell in data.road_cells:
			_remove_at(data.fruits, cell)
			data.fruits.append({"type": type_option.get_item_text(type_option.selected), "position": cell})
		else:
			_set_status("Fruit rejected: target is not a road cell.")
	elif tool == "TRUCK":
		if cell in data.road_cells:
			_remove_at(data.trucks, cell)
			data.trucks.append({"type": type_option.get_item_text(type_option.selected), "position": cell, "required": int(required_spin.value)})
		else:
			_set_status("Truck rejected: target is not a road cell.")
	queue_redraw()

func _paint_footprint(first: Vector2i, last: Vector2i) -> void:
	var position := Vector2i(min(first.x, last.x), min(first.y, last.y))
	var size := Vector2i(abs(last.x - first.x) + 1, abs(last.y - first.y) + 1)
	data.blocked_footprints.append({"position": position, "size": size})
	queue_redraw()

func _new_level() -> void:
	data = LevelData.new()
	data.level_id = int(level_spin.value)
	data.width = int(width_spin.value)
	data.height = int(height_spin.value)
	data.cell_size = int(cell_spin.value)
	_refresh_grid()
	_set_status("New level %d" % data.level_id)

func _load_selected() -> void:
	data = _load_level(int(level_spin.value))
	_refresh_grid()
	_set_status("Loaded level %d" % data.level_id)

func _save_level() -> void:
	var results := LevelValidator.validate(data)
	if not _show_results(results):
		_set_status("Save blocked: fix validation failures first.")
		return
	ResourceSaver.save(data, "%slevel_%03d.tres" % [LEVEL_DIR, data.level_id])
	_set_status("Saved level_%03d.tres" % data.level_id)

func _validate() -> void:
	_show_results(LevelValidator.validate(data))

func _test_level() -> void:
	var results := LevelValidator.validate(data)
	if not _show_results(results):
		_set_status("Test blocked by structural validation failures.")
		return
	var solve_result := LevelSolver.solve(data)
	if not solve_result["solvable"] and not override_check.button_pressed:
		_set_status("Test blocked: %s" % solve_result["message"])
		return
	var path := "%slevel_%03d.tres" % [LEVEL_DIR, data.level_id]
	ResourceSaver.save(data, path)
	LevelSession.level_path = path
	LevelSession.solver_result = solve_result
	get_tree().change_scene_to_file(GAME_SCENE)

func _show_results(results: Array[Dictionary]) -> bool:
	var lines: Array[String] = []
	var valid := true
	for result in results:
		lines.append(("PASS: " if result["pass"] else "FAIL: ") + result["message"])
		if not result["pass"]:
			valid = false
	results_label.text = "\n".join(lines)
	return valid

func _refresh_grid() -> void:
	grid.setup(data.width, data.height, data.cell_size, [])
	queue_redraw()

func _load_level(id: int) -> LevelData:
	var loaded = load("%slevel_%03d.tres" % [LEVEL_DIR, id])
	if loaded is LevelData:
		return loaded
	return LevelData.new()

func _add_button(parent: Container, text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)

func _add_spin(parent: Container, label_text: String, value: int, minimum: int, maximum: int) -> SpinBox:
	var spin := SpinBox.new()
	spin.prefix = label_text + " "
	spin.value = value
	spin.min_value = minimum
	spin.max_value = maximum
	spin.custom_minimum_size.x = 80
	parent.add_child(spin)
	return spin

func _remove_at(values: Array[Dictionary], cell: Vector2i) -> void:
	for index in range(values.size() - 1, -1, -1):
		if values[index].get("position") == cell:
			values.remove_at(index)

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < data.width and cell.y >= 0 and cell.y < data.height

func _set_status(text: String) -> void:
	status_label.text = text

func _type_color(fruit_type: String) -> Color:
	return {"APPLE": Color("#ef5350"), "BANANA": Color("#f5c542"), "BERRY": Color("#b56cff")}.get(fruit_type, Color.WHITE)