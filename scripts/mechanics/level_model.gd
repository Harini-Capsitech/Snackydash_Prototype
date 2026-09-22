## LevelModel represents an immutable, strongly-typed domain model for a puzzle level.
class_name LevelModel
extends RefCounted

var id: int = 1
var title: String = "Untitled Level"
var tip: String = ""
var rows: int = 0
var cols: int = 0
var grid: Array = []  # 2D Array
var snake_start: Vector2i = Vector2i(1, 1)

var fruits: Array = []
var trucks: Array = []
var bridges: Array = []
var one_ways: Array = []
var raw_layout: Array = []

# Crate Stack specification (from screenshots: 3x3 crates stacked by color)
var crates: Array = []
var crate_dock: Vector2i = Vector2i(-1, -1)

func _init(
	p_id: int = 1,
	p_title: String = "",
	p_tip: String = "",
	p_rows: int = 0,
	p_cols: int = 0,
	p_grid: Array = [],
	p_snake_start: Vector2i = Vector2i(1, 1),
	p_fruits: Array = [],
	p_trucks: Array = [],
	p_bridges: Array = [],
	p_one_ways: Array = [],
	p_raw_layout: Array = []
) -> void:
	id = p_id
	title = p_title
	tip = p_tip
	rows = p_rows
	cols = p_cols
	grid = p_grid
	snake_start = p_snake_start
	fruits = p_fruits
	trucks = p_trucks
	bridges = p_bridges
	one_ways = p_one_ways
	raw_layout = p_raw_layout

func create_instance_data() -> Dictionary:
	return {
		"id": id,
		"title": title,
		"tip": tip,
		"rows": rows,
		"cols": cols,
		"grid": grid.duplicate(true),
		"snake_start": snake_start,
		"fruits": fruits.duplicate(true),
		"trucks": trucks.duplicate(true),
		"bridges": bridges.duplicate(true),
		"crates": crates.duplicate(true),
		"crate_dock": crate_dock
	}
