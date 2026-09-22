## GridRenderer renders the authentic visual presentation of Snacky Dash:
## Soft clover terrain, charcoal asphalt roads with rounded corners,
## stacked 3x3 delivery crates, purple cargo wagon train, arched bridges,
## and glowing purple trajectory chevrons during drag-aim.
class_name GridRenderer
extends Node2D

const GameConfig = preload("res://scripts/game_config.gd")

@export var tile_size: int = 60

var engine = null
var anim_time: float = 0.0
var visual_positions: Array[Vector2] = []
var head_visual_angle: float = -PI * 0.5

func _process(delta: float) -> void:
	anim_time += delta
	update_visuals(delta)
	queue_redraw()

func set_engine(p_engine) -> void:
	engine = p_engine
	if engine:
		if engine.has_signal("state_updated"):
			engine.state_updated.connect(queue_redraw)
		if engine.has_signal("level_loaded"):
			engine.level_loaded.connect(_on_level_loaded)
	snap_visuals()
	queue_redraw()

func _on_level_loaded(_info: Dictionary) -> void:
	snap_visuals()

func update_visuals(delta: float) -> void:
	if not engine or engine.snake.is_empty():
		visual_positions.clear()
		return
		
	var ts = float(tile_size)
	var count = engine.snake.size()
	
	while visual_positions.size() < count:
		var idx = visual_positions.size()
		var seg = engine.snake[idx]
		var init_px = Vector2(seg["pos"].x * ts + ts * 0.5, seg["pos"].y * ts + ts * 0.5)
		if idx > 0 and visual_positions.size() > 0:
			init_px = visual_positions[idx - 1]
		visual_positions.append(init_px)
		
	while visual_positions.size() > count:
		visual_positions.pop_back()
		
	var lerp_rate = 22.0
	for i in range(count):
		var target_px = Vector2(engine.snake[i]["pos"].x * ts + ts * 0.5, engine.snake[i]["pos"].y * ts + ts * 0.5)
		visual_positions[i] = visual_positions[i].lerp(target_px, clampf(delta * lerp_rate, 0.0, 1.0))
		
	var target_angle = Vector2(engine.snake_dir.x, engine.snake_dir.y).angle()
	head_visual_angle = lerp_angle(head_visual_angle, target_angle, clampf(delta * 20.0, 0.0, 1.0))

func snap_visuals() -> void:
	if not engine or engine.snake.is_empty():
		return
	var ts = float(tile_size)
	visual_positions.clear()
	for seg in engine.snake:
		visual_positions.append(Vector2(seg["pos"].x * ts + ts * 0.5, seg["pos"].y * ts + ts * 0.5))
	head_visual_angle = Vector2(engine.snake_dir.x, engine.snake_dir.y).angle()

func _draw() -> void:
	if not engine or engine.grid.is_empty():
		return
		
	var rows: int = engine.rows
	var cols: int = engine.cols
	var ts: float = float(tile_size)
	
	# 1. Clover Grass Field Background
	draw_rect(Rect2(-40, -40, cols * ts + 80, rows * ts + 80), GameConfig.COLOR_GRASS_BG, true)
	
	# Draw subtle clover accents
	draw_clover_field(cols * ts, rows * ts)
	
	# 2. Road Network (Dark Charcoal Asphalt with rounded borders)
	for r in range(rows):
		for c in range(cols):
			var x: float = c * ts
			var y: float = r * ts
			var tile: String = engine.grid[r][c]
			
			if tile != GameConfig.TILE_WALL:
				# Asphalt road tile
				draw_road_tile(x, y, ts, r, c)
				
			if tile == GameConfig.TILE_BRIDGE:
				draw_underpass_tunnel(x, y, ts)
				
	# 3. Junction Checkpoint Reticles [ ]
	for r in range(rows):
		for c in range(cols):
			var tile: String = engine.grid[r][c]
			if tile == GameConfig.TILE_JUNCTION:
				draw_junction_reticle(c * ts, r * ts, ts)
				
	# 4. Trajectory Preview Chevrons (Purple Aim Arrows)
	if not engine.preview_path.is_empty():
		draw_preview_chevrons(ts)
		
	# 5. Snake Segments on UNDERPASS (Beneath Bridge Deck)
	draw_snake_layer(GameConfig.Layer.UNDERPASS, ts)
	
	# 6. Arched Bridge Overpass Structure
	for r in range(rows):
		for c in range(cols):
			if engine.grid[r][c] == GameConfig.TILE_BRIDGE:
				draw_arched_bridge(c * ts, r * ts, ts)
				
	# 7. Snake Segments on GROUND and OVERPASS
	draw_snake_layer(GameConfig.Layer.GROUND, ts)
	draw_snake_layer(GameConfig.Layer.OVERPASS, ts)
	
	# 8. Fruits on the track
	for f in engine.fruits:
		if not f["collected"]:
			draw_fruit_item(f["pos"].x * ts, f["pos"].y * ts, ts, f["type"])
			
	# 9. Stacked 3x3 Delivery Crates Hub
	draw_stacked_crates_hub(ts)

func draw_clover_field(w: float, h: float) -> void:
	# Soft clover dots pattern
	var step = 80.0
	for gx in range(-20, int(w + 40), int(step)):
		for gy in range(-20, int(h + 40), int(step)):
			draw_circle(Vector2(gx, gy), 6.0, GameConfig.COLOR_GRASS_ALT)
			draw_circle(Vector2(gx + 6, gy - 4), 5.0, GameConfig.COLOR_GRASS_ALT)
			draw_circle(Vector2(gx - 6, gy - 4), 5.0, GameConfig.COLOR_GRASS_ALT)

func draw_road_tile(x: float, y: float, s: float, r: int, c: int) -> void:
	# Asphalt road bed with curb shadow
	draw_rect(Rect2(x - 1, y - 1, s + 2, s + 2), GameConfig.COLOR_ISLAND_BORDER, false, 2.0)
	draw_rect(Rect2(x, y, s, s), GameConfig.COLOR_ROAD_ASPHALT, true)
	
	# Check if this is a junction node, draw square indent
	if engine.grid[r][c] in [GameConfig.TILE_JUNCTION, GameConfig.TILE_CRATE]:
		draw_rect(Rect2(x + s * 0.25, y + s * 0.25, s * 0.5, s * 0.5), GameConfig.COLOR_JUNCTION_INDENT, true)

func draw_underpass_tunnel(x: float, y: float, s: float) -> void:
	# Vertical dark trench beneath the bridge
	draw_rect(Rect2(x + 6, y, s - 12, s), Color("#1e242f"), true)
	draw_rect(Rect2(x + 6, y, 4, s), Color(0, 0, 0, 0.45), true)
	draw_rect(Rect2(x + s - 10, y, 4, s), Color(0, 0, 0, 0.45), true)

func draw_arched_bridge(x: float, y: float, s: float) -> void:
	# Horizontal arched bridge matching screenshot unlock screen
	# Drop shadow onto underpass
	draw_rect(Rect2(x, y + s - 8, s, 8), Color(0, 0, 0, 0.4), true)
	
	# Bridge deck platform
	draw_rect(Rect2(x, y + 8, s, s - 16), Color("#d4a373"), true) # Wood/cream deck
	
	# Plank lines
	for px in range(int(x + 4), int(x + s), 10):
		draw_line(Vector2(px, y + 8), Vector2(px, y + s - 8), Color(1, 1, 1, 0.25), 1.0)
		
	# Green curved guard rails (iconic arched bridge look)
	draw_rect(Rect2(x, y + 6, s, 4), Color("#4ade80"), true) # Bright green top rail
	draw_rect(Rect2(x, y + 8, s, 2), Color("#15803d"), true)
	draw_rect(Rect2(x, y + s - 10, s, 4), Color("#4ade80"), true) # Bright green bottom rail
	draw_rect(Rect2(x, y + s - 8, s, 2), Color("#15803d"), true)

func draw_junction_reticle(x: float, y: float, s: float) -> void:
	# Orange [ ] corner brackets as seen in screenshots
	var m: float = s * 0.2
	var len: float = s * 0.22
	var col = GameConfig.COLOR_RETICLE_ORANGE
	var lw = 3.0
	
	# Top-Left
	draw_line(Vector2(x + m, y + m), Vector2(x + m + len, y + m), col, lw)
	draw_line(Vector2(x + m, y + m), Vector2(x + m, y + m + len), col, lw)
	# Top-Right
	draw_line(Vector2(x + s - m, y + m), Vector2(x + s - m - len, y + m), col, lw)
	draw_line(Vector2(x + s - m, y + m), Vector2(x + s - m, y + m + len), col, lw)
	# Bottom-Left
	draw_line(Vector2(x + m, y + s - m), Vector2(x + m + len, y + s - m), col, lw)
	draw_line(Vector2(x + m, y + s - m), Vector2(x + m, y + s - m - len), col, lw)
	# Bottom-Right
	draw_line(Vector2(x + s - m, y + s - m), Vector2(x + s - m - len, y + s - m), col, lw)
	draw_line(Vector2(x + s - m, y + s - m), Vector2(x + s - m, y + s - m - len), col, lw)

func draw_preview_chevrons(ts: float) -> void:
	# Animated purple trajectory chevron chain (as in Screenshot 4)
	for i in range(engine.preview_path.size()):
		var pt = engine.preview_path[i]
		var cx = pt.x * ts + ts * 0.5
		var cy = pt.y * ts + ts * 0.5
		
		# Determine chevron direction
		var dir = engine.aim_direction
		if i > 0:
			dir = pt - engine.preview_path[i - 1]
			
		var angle = Vector2(dir.x, dir.y).angle()
		var pulse = sin(anim_time * 8.0 - float(i) * 0.6) * 3.0
		
		var pts = PackedVector2Array([
			Vector2(8 + pulse, 0).rotated(angle) + Vector2(cx, cy),
			Vector2(-6, -8).rotated(angle) + Vector2(cx, cy),
			Vector2(-2, 0).rotated(angle) + Vector2(cx, cy),
			Vector2(-6, 8).rotated(angle) + Vector2(cx, cy)
		])
		draw_colored_polygon(pts, GameConfig.COLOR_CHEVRON)

func draw_snake_layer(target_layer: int, ts: float) -> void:
	for i in range(engine.snake.size() - 1, -1, -1):
		var seg = engine.snake[i]
		if seg["layer"] != target_layer:
			continue
			
		var cx = seg["pos"].x * ts + ts * 0.5
		var cy = seg["pos"].y * ts + ts * 0.5
		if i < visual_positions.size():
			cx = visual_positions[i].x
			cy = visual_positions[i].y
			
		if i == 0:
			draw_snake_head(cx, cy, ts, head_visual_angle)
		else:
			draw_wagon_segment(cx, cy, ts, seg["fruit_type"])

func draw_snake_head(cx: float, cy: float, s: float, angle: float) -> void:
	var r = s * 0.4
	
	# Purple Rounded Block Head
	draw_rect(Rect2(cx - r, cy - r, r * 2, r * 2), GameConfig.COLOR_SNAKE_SHADOW, true)
	draw_rect(Rect2(cx - r + 2, cy - r + 2, r * 2 - 4, r * 2 - 4), GameConfig.COLOR_SNAKE_PURPLE, true)
	
	# Big expressive cartoon eyes looking in direction
	var eye_dist = r * 0.45
	var eye_spread = r * 0.4
	var eye_r = r * 0.32
	
	var left_eye = Vector2(cx, cy) + Vector2(eye_dist, -eye_spread).rotated(angle)
	var right_eye = Vector2(cx, cy) + Vector2(eye_dist, eye_spread).rotated(angle)
	
	draw_circle(left_eye, eye_r, Color.WHITE)
	draw_circle(right_eye, eye_r, Color.WHITE)
	
	var pupil_off = Vector2(2.5, 0).rotated(angle)
	draw_circle(left_eye + pupil_off, eye_r * 0.6, Color("#1e1b4b"))
	draw_circle(right_eye + pupil_off, eye_r * 0.6, Color("#1e1b4b"))
	draw_circle(left_eye + pupil_off + Vector2(1, -1), eye_r * 0.25, Color.WHITE)
	draw_circle(right_eye + pupil_off + Vector2(1, -1), eye_r * 0.25, Color.WHITE)

func draw_wagon_segment(cx: float, cy: float, s: float, fruit_type: String) -> void:
	var w = s * 0.72
	var h = s * 0.72
	
	# Open Purple Wagon Tray
	draw_rect(Rect2(cx - w * 0.5, cy - h * 0.5, w, h), GameConfig.COLOR_WAGON_PURPLE, true)
	draw_rect(Rect2(cx - w * 0.5 + 4, cy - h * 0.5 + 4, w - 8, h - 8), GameConfig.COLOR_WAGON_INNER, true)
	
	# Fruit payload sitting inside wagon tray
	if not fruit_type.is_empty():
		draw_fruit_orb(cx, cy, s * 0.65, fruit_type)

func draw_fruit_item(x: float, y: float, s: float, type: String) -> void:
	var cx = x + s * 0.5
	var cy = y + s * 0.5
	var bob = sin(anim_time * 5.0 + cx) * 2.5
	draw_fruit_orb(cx, cy + bob, s * 0.7, type)

func draw_fruit_orb(cx: float, cy: float, size: float, type: String) -> void:
	var f_data = GameConfig.FRUIT_DATA.get(type, GameConfig.FRUIT_DATA["R"])
	var r = size * 0.4
	
	# Outer shadow
	draw_circle(Vector2(cx, cy + 2), r, Color(0, 0, 0, 0.25))
	# Main fruit circle
	draw_circle(Vector2(cx, cy), r, f_data["color"])
	# Dark lower shading
	draw_circle(Vector2(cx, cy + r * 0.2), r * 0.85, f_data["dark"])
	draw_circle(Vector2(cx, cy), r * 0.75, f_data["color"])
	# Shine spot
	draw_circle(Vector2(cx - r * 0.35, cy - r * 0.35), r * 0.25, Color(1, 1, 1, 0.65))
	# Stem
	draw_line(Vector2(cx, cy - r), Vector2(cx + 2, cy - r - 4), Color("#78350f"), 2.0)

func draw_stacked_crates_hub(ts: float) -> void:
	if engine.crate_stack.is_empty():
		return
		
	# Find crate dock tile or top center
	var dock_pos = engine.crate_dock
	if dock_pos == Vector2i(-1, -1):
		dock_pos = Vector2i(engine.cols / 2, 1)
		
	var cx = dock_pos.x * ts + ts * 0.5
	var cy = dock_pos.y * ts + ts * 0.5
	var crate_size = ts * 1.5
	
	# Draw background crate tiers (stacked below)
	for i in range(engine.crate_stack.size() - 1, engine.active_crate_idx, -1):
		var tier_crate = engine.crate_stack[i]
		var y_off = (i - engine.active_crate_idx) * 8.0
		var tier_col = tier_crate["color"]
		draw_rect(Rect2(cx - crate_size * 0.5, cy - crate_size * 0.5 - 20 + y_off, crate_size, crate_size), tier_col, true)
		
	# Draw active top crate
	if engine.active_crate_idx < engine.crate_stack.size():
		var top_crate = engine.crate_stack[engine.active_crate_idx]
		var base_col = top_crate["color"]
		var crate_rect = Rect2(cx - crate_size * 0.5, cy - crate_size * 0.5 - 20, crate_size, crate_size)
		
		# Crate border
		draw_rect(crate_rect, Color(0, 0, 0, 0.4), true) # shadow
		draw_rect(Rect2(crate_rect.position.x, crate_rect.position.y - 4, crate_rect.size.x, crate_rect.size.y), base_col, true)
		# Inner tray (light beige)
		var inner_rect = Rect2(crate_rect.position.x + 8, crate_rect.position.y + 4, crate_rect.size.x - 16, crate_rect.size.y - 16)
		draw_rect(inner_rect, Color("#fef3c7"), true)
		
		# 3x3 Circular Slots inside the crate (as seen in screenshots)
		var slot_step = inner_rect.size.x / 3.0
		var filled_count = top_crate["filled"]
		var slot_idx = 0
		
		for row in range(3):
			for col in range(3):
				var scx = inner_rect.position.x + col * slot_step + slot_step * 0.5
				var scy = inner_rect.position.y + row * slot_step + slot_step * 0.5
				
				if slot_idx < filled_count:
					# Draw filled fruit in this slot!
					draw_fruit_orb(scx, scy, slot_step * 0.9, top_crate["fruit"])
				else:
					# Empty slot indent
					draw_circle(Vector2(scx, scy), slot_step * 0.32, Color("#e2d2a4"))
					draw_circle(Vector2(scx, scy), slot_step * 0.28, Color("#f3e8c8"))
				slot_idx += 1
