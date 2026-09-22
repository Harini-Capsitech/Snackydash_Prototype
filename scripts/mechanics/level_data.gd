## LevelData stores the authentic levels from Snacky Dash screenshots
## and dynamically parses ASCII maps into strongly-typed LevelModel instances.
class_name LevelData
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")
const LevelModel = preload("res://scripts/level_model.gd")

const BUILTIN_LEVELS: Array[Dictionary] = [
	# LEVEL 1: The Loop & Center Dock (Screenshots 2, 3, 5)
	# Red 3x3 Crate (Capacity: 9). When board fruits are cleared,
	# new fruits dynamically respawn until all 9 slots in the tray are filled!
	{
		"id": 1,
		"title": "Level 1",
		"tip": "Collect apples and deliver them to the crate! New apples appear until the 3x3 crate is full.",
		"crates": [
			{ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 } # Red 3x3 Crate (9 capacity)
		],
		"layout": [
			"#######",
			"###C###",
			"#..R..#",
			"#R###R#",
			"#R.S.R#",
			"#R###R#",
			"#R###R#",
			"#..R..#",
			"#######"
		]
	},
	# LEVEL 2: The Triple Stack & Trident Lanes (Screenshots 1 & 4)
	{
		"id": 2,
		"title": "Level 2",
		"tip": "3 Stacked Crates! Red, Blue, and Yellow fruits respawn to fill each required tray.",
		"crates": [
			{ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 }, # Red top crate
			{ "color": Color("#2563eb"), "fruit": "B", "capacity": 9 }, # Blue middle crate
			{ "color": Color("#eab308"), "fruit": "Y", "capacity": 9 }  # Yellow bottom crate
		],
		"layout": [
			"#########",
			"####C####",
			"#J..J..J#",
			"#B##R##Y#",
			"#B##R##Y#",
			"#B##R##Y#",
			"#B##R##Y#",
			"#B##R##Y#",
			"#J..S..J#",
			"#########"
		]
	},
	# LEVEL 3: S-Curve Junctions & Self-Collision Lesson (Screenshots 2 & 3 in batch 2)
	{
		"id": 3,
		"title": "Level 3",
		"tip": "Careful! When you hit your own tail, you will lose!",
		"crates": [
			{ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 },
			{ "color": Color("#2563eb"), "fruit": "B", "capacity": 9 }
		],
		"layout": [
			"#########",
			"####C####",
			"##..J..##",
			"#B#.R.#.#",
			"#B#RRR#.#",
			"#B#.R.#.#",
			"#G##R##.#",
			"#G##R##.#",
			"#G..S..R#",
			"#########"
		]
	},
	# LEVEL 5: Dual Arched Bridges (Screenshot 2 & 3 in batch 3)
	{
		"id": 5,
		"title": "Level 5: Dual Bridges",
		"tip": "Bridges! Cross horizontally over the road without hitting your own body underneath!",
		"crates": [
			{ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 },
			{ "color": Color("#2563eb"), "fruit": "B", "capacity": 9 }
		],
		"layout": [
			"###########",
			"#####C#####",
			"#J...J...J#",
			"#R#B#.#B#R#",
			"#J.=.=.=.J#",
			"#.#R#.#R#.#",
			"#J.=.=.=.J#",
			"#R#B#.#B#R#",
			"#J...S...J#",
			"###########"
		]
	}
]

static func get_all_levels() -> Array:
	var result: Array = []
	
	# Scan res://levels/ directory for .txt files
	var dir = DirAccess.open("res://levels")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var txt_files: Array[String] = []
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".txt"):
				txt_files.append(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
		txt_files.sort()
		
		for fname in txt_files:
			var lvl = load_level_from_file("res://levels/" + fname)
			if lvl:
				result.append(lvl)
				
	# Fallback to BUILTIN_LEVELS if no external text files exist
	if result.is_empty():
		for def in BUILTIN_LEVELS:
			result.append(parse_level(def))
			
	return result

static func load_level_from_file(file_path: String) -> LevelModel:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return null
		
	var title = "Level"
	var tip = ""
	var id = 1
	var crates: Array = []
	var layout: Array = []
	
	var base_name = file_path.get_file().get_basename()
	var parts = base_name.split("_")
	if parts.size() > 1 and parts[1].is_valid_int():
		id = parts[1].to_int()
		title = "Level %d" % id
		
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line.is_empty():
			continue
		if line.begins_with(";"):
			var meta_line = line.substr(1).strip_edges()
			var colon_pos = meta_line.find(":")
			if colon_pos != -1:
				var key = meta_line.substr(0, colon_pos).strip_edges().to_lower()
				var val = meta_line.substr(colon_pos + 1).strip_edges()
				if key == "title":
					title = val
				elif key == "tip":
					tip = val
				elif key == "id" and val.is_valid_int():
					id = val.to_int()
				elif key == "crates":
					crates.clear()
					for c_spec in val.split(","):
						var pair = c_spec.strip_edges().split(":")
						if pair.size() == 2:
							var f_type = pair[0].strip_edges().to_upper()
							var cap = pair[1].strip_edges().to_int()
							var c_color = GameConfig.FRUIT_DATA.get(f_type, {}).get("color", Color("#e11d48"))
							crates.append({ "color": c_color, "fruit": f_type, "capacity": cap })
		else:
			layout.append(line)
			
	file.close()
	
	if layout.is_empty():
		return null
		
	if crates.is_empty():
		crates.append({ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 })
		
	var def = {
		"id": id,
		"title": title,
		"tip": tip,
		"crates": crates,
		"layout": layout
	}
	return parse_level(def)

static func parse_level(def: Dictionary) -> LevelModel:
	var layout: Array = def.get("layout", [])
	var rows: int = layout.size()
	var cols: int = (layout[0] as String).length() if rows > 0 else 0
	
	var grid: Array = []
	var snake_start: Vector2i = Vector2i(1, 1)
	var fruits: Array = []
	var bridges: Array = []
	var crate_dock: Vector2i = Vector2i(-1, -1)
	
	for r in range(rows):
		var row_arr: Array = []
		var line: String = layout[r]
		for c in range(cols):
			var ch: String = line[c] if c < line.length() else GameConfig.TILE_WALL
			var base_tile: String = GameConfig.TILE_FLOOR
			
			if ch == GameConfig.TILE_WALL:
				base_tile = GameConfig.TILE_WALL
			elif ch == GameConfig.TILE_BRIDGE:
				base_tile = GameConfig.TILE_BRIDGE
				bridges.append(Vector2i(c, r))
			elif ch == GameConfig.TILE_CRATE:
				base_tile = GameConfig.TILE_CRATE
				crate_dock = Vector2i(c, r)
			elif ch == GameConfig.TILE_SNAKE_START:
				snake_start = Vector2i(c, r)
				base_tile = GameConfig.TILE_FLOOR
			elif ch == GameConfig.TILE_JUNCTION:
				base_tile = GameConfig.TILE_JUNCTION
			elif GameConfig.FRUIT_DATA.has(ch):
				fruits.append({ "pos": Vector2i(c, r), "type": ch, "collected": false })
				base_tile = GameConfig.TILE_FLOOR
			else:
				base_tile = GameConfig.TILE_FLOOR
				
			row_arr.append(base_tile)
		grid.append(row_arr)
		
	var model = LevelModel.new(
		def.get("id", 1),
		def.get("title", "Level"),
		def.get("tip", ""),
		rows,
		cols,
		grid,
		snake_start,
		fruits,
		[],
		bridges,
		[],
		layout
	)
	
	model.crates = def.get("crates", [{ "color": Color("#e11d48"), "fruit": "R", "capacity": 9 }])
	model.crate_dock = crate_dock
	return model
