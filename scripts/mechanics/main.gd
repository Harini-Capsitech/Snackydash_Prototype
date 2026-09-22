## MainController manages the top progress bar, drag-aim input gestures,
## fail/win modals, and audio feedback matching the Snacky Dash screenshots.
class_name MainController
extends Node

const GameConfig = preload("res://scripts/game_config.gd")
const LevelData = preload("res://scripts/level_data.gd")
const LevelModel = preload("res://scripts/level_model.gd")
const GameEngine = preload("res://scripts/game_engine.gd")

@onready var grid_renderer = $GridRenderer
@onready var camera: Camera2D = $Camera2D

# UI References
@onready var level_option: OptionButton = $UI/HUD/HBoxTop/LevelOption
@onready var label_level_title: Label = $UI/HUD/ProgressBarContainer/LabelLevel
@onready var progress_slider: ProgressBar = $UI/HUD/ProgressBarContainer/ProgressBar
@onready var label_tip: Label = $UI/HUD/LabelTip

# Bottom Action Buttons
@onready var btn_undo: Button = $UI/HUD/HBoxBottom/BtnUndo
@onready var btn_restart: Button = $UI/HUD/HBoxBottom/BtnRestart
@onready var btn_next: Button = $UI/HUD/HBoxBottom/BtnNext

# Modals
@onready var lose_dialog: PanelContainer = $UI/LoseDialog
@onready var btn_lose_replay: Button = $UI/LoseDialog/VBox/BtnReplay
@onready var win_dialog: PanelContainer = $UI/WinDialog
@onready var btn_win_replay: Button = $UI/WinDialog/VBox/HBox/BtnReplay
@onready var btn_win_next: Button = $UI/WinDialog/VBox/HBox/BtnNextLevel

var engine: GameEngine = null
var all_levels: Array = []
var current_level_idx: int = 0

# Drag / Swipe Aiming State
var is_dragging: bool = false
var drag_start_pos: Vector2 = Vector2.ZERO
var drag_threshold: float = 20.0

func _ready() -> void:
	engine = GameEngine.new()
	add_child(engine)
	
	engine.level_loaded.connect(_on_level_loaded)
	engine.state_updated.connect(_on_state_updated)
	engine.self_collision_lost.connect(_on_self_collision_lost)
	engine.level_won.connect(_on_level_won)
	
	grid_renderer.set_engine(engine)
	
	all_levels = LevelData.get_all_levels()
	level_option.clear()
	for i in range(all_levels.size()):
		var lvl = all_levels[i]
		var title_text: String = lvl.title if lvl is LevelModel else lvl.get("title", "Level")
		level_option.add_item(title_text, i)
		
	level_option.item_selected.connect(_on_level_selected)
	btn_undo.pressed.connect(_on_undo_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_next.pressed.connect(_on_next_pressed)
	
	btn_lose_replay.pressed.connect(_on_restart_pressed)
	btn_win_replay.pressed.connect(_on_restart_pressed)
	btn_win_next.pressed.connect(_on_next_pressed)
	
	lose_dialog.visible = false
	win_dialog.visible = false
	
	load_level(0)

func load_level(idx: int) -> void:
	if idx < 0 or idx >= all_levels.size():
		return
	current_level_idx = idx
	level_option.selected = idx
	lose_dialog.visible = false
	win_dialog.visible = false
	
	var lvl = all_levels[idx]
	engine.load_level(lvl)
	label_level_title.text = lvl.title if lvl is LevelModel else lvl.get("title", "Level")
	center_board()

func center_board() -> void:
	var total_w: float = float(engine.cols * grid_renderer.tile_size)
	var total_h: float = float(engine.rows * grid_renderer.tile_size)
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	
	grid_renderer.position = Vector2(
		(vp_size.x - total_w) * 0.5,
		140.0 + (vp_size.y - 140.0 - 180.0 - total_h) * 0.5
	)

func _on_level_selected(idx: int) -> void:
	load_level(idx)

func _on_level_loaded(info: Dictionary) -> void:
	label_tip.text = "💡 " + info.get("tip", "")
	_update_hud()

func _on_state_updated() -> void:
	_update_hud()

func _update_hud() -> void:
	# Calculate total crate fill progress for the top progress bar
	var total_capacity = 0
	var total_filled = 0
	for c in engine.crate_stack:
		total_capacity += c["capacity"]
		total_filled += c["filled"]
		
	if total_capacity > 0:
		progress_slider.value = (float(total_filled) / float(total_capacity)) * 100.0
	else:
		progress_slider.value = 0.0
		
	btn_undo.disabled = engine.history.is_empty() or engine.is_won or engine.is_dashing
	btn_restart.disabled = engine.is_dashing

func _on_self_collision_lost() -> void:
	lose_dialog.visible = true

func _on_level_won() -> void:
	win_dialog.visible = true

func _on_undo_pressed() -> void:
	if engine.undo():
		grid_renderer.snap_visuals()
	lose_dialog.visible = false

func _on_restart_pressed() -> void:
	lose_dialog.visible = false
	win_dialog.visible = false
	engine.restart()
	grid_renderer.snap_visuals()

func _on_next_pressed() -> void:
	var next_idx: int = (current_level_idx + 1) % all_levels.size()
	load_level(next_idx)

# ==============================================================================
# DRAG-AIM CONTROLS (Screenshots: Drag to show trajectory chevrons, release to dash)
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	if engine == null or engine.is_dashing or engine.is_won or engine.is_lost:
		return
	# 1. Mouse / Touch Drag Input
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_dragging = true
				drag_start_pos = event.position
			else:
				if is_dragging:
					is_dragging = false
					engine.confirm_dash()
	elif event is InputEventMouseMotion and is_dragging:
		var delta = event.position - drag_start_pos
		if delta.length() > drag_threshold:
			var dir = calculate_cardinal_dir(delta)
			engine.set_aim_direction(dir)
			
	elif event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			drag_start_pos = event.position
		else:
			is_dragging = false
			engine.confirm_dash()
	elif event is InputEventScreenDrag and is_dragging:
		var delta = event.position - drag_start_pos
		if delta.length() > drag_threshold:
			var dir = calculate_cardinal_dir(delta)
			engine.set_aim_direction(dir)

	# 2. Keyboard fallback controls (Arrow keys or WASD)
	if event is InputEventKey and event.is_pressed():
		var dir = Vector2i.ZERO
		if event.keycode in [KEY_UP, KEY_W]: dir = Vector2i(0, -1)
		elif event.keycode in [KEY_DOWN, KEY_S]: dir = Vector2i(0, 1)
		elif event.keycode in [KEY_LEFT, KEY_A]: dir = Vector2i(-1, 0)
		elif event.keycode in [KEY_RIGHT, KEY_D]: dir = Vector2i(1, 0)
		
		if dir != Vector2i.ZERO:
			engine.set_aim_direction(dir)
			engine.confirm_dash()
		elif event.keycode == KEY_Z:
			engine.undo()
		elif event.keycode == KEY_R:
			_on_restart_pressed()

func calculate_cardinal_dir(delta: Vector2) -> Vector2i:
	if abs(delta.x) > abs(delta.y):
		return Vector2i(1, 0) if delta.x > 0 else Vector2i(-1, 0)
	else:
		return Vector2i(0, 1) if delta.y > 0 else Vector2i(0, -1)
