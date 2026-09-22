@tool
class_name LevelEditor extends Node2D

@export_group("Textures")
@export var road_texture: Texture2D
@export var entity_sprites: Dictionary = {
	"player": null,
	"apple_red": null,
	"apple_green": null,
	"blueberry": null,
	"peach": null,
	"box": null,
	"rock": load("res://Sprites/rock.png")
}:
	set(value):
		entity_sprites = value
		notify_property_list_changed()

@export_group("Level Configuration")
@export var target_level_resource: LevelData
@export var level_file_path: String = "res://levels/level_01.tres"
@export var grid_width: int = 9
@export var grid_height: int = 17
@export var texture_overlap: int = 0

@export var add_road_rect: Rect2i = Rect2i(0, 0, 9, 17)
@export var add_road_button: bool = false:
	set(value):
		if value:
			_add_road()
		add_road_button = false

var selected_entity_type: String = "player"
@export var entity_grid_pos: Vector2i = Vector2i(0, 0)
@export var place_entity_button: bool = false:
	set(value):
		if value:
			_place_entity()
		place_entity_button = false

@export var clear_board_button: bool = false:
	set(value):
		if value:
			_clear_board()
		clear_board_button = false
		
@export var save_level_button: bool = false:
	set(value):
		if value:
			_save_level()
		save_level_button = false
		
@export var load_level_button: bool = false:
	set(value):
		if value:
			_load_level()
		load_level_button = false

# Internal state
var cell_size: Vector2 = Vector2(64, 64)

# Container nodes for organization
var bg_node: Node2D
var roads_node: Node2D
var entities_node: Node2D

func _get_property_list() -> Array:
	var props = []
	var hint_string = ",".join(entity_sprites.keys())
	props.append({
		"name": "selected_entity_type",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": hint_string
	})
	return props

func _ready():
	_ensure_containers()
	if Engine.is_editor_hint():
		queue_redraw()
		if not child_entered_tree.is_connected(_on_child_entered_tree):
			child_entered_tree.connect(_on_child_entered_tree)

func _on_child_entered_tree(node: Node):
	if Engine.is_editor_hint() and node is Sprite2D:
		call_deferred("_assimilate_dragged_sprite", node)

func _assimilate_dragged_sprite(sprite: Sprite2D):
	if not is_instance_valid(sprite) or sprite.get_parent() != self:
		return
		
	var tex = sprite.texture
	if tex == null:
		return
		
	# Handle road
	if tex == road_texture:
		var size_px = sprite.scale * tex.get_size()
		var top_left_px = sprite.position
		if sprite.centered:
			top_left_px -= size_px / 2.0
			
		var grid_x = int(round(top_left_px.x / cell_size.x))
		var grid_y = int(round(top_left_px.y / cell_size.y))
		var grid_w = int(max(1, round(size_px.x / cell_size.x)))
		var grid_h = int(max(1, round(size_px.y / cell_size.y)))
		
		# Prevent placing outside grid bounds
		if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
			sprite.queue_free()
			return
			
		add_road_rect = Rect2i(grid_x, grid_y, grid_w, grid_h)
		_add_road()
		sprite.queue_free()
		print("Assimilated dragged object as road at ", add_road_rect)
		return
		
	var matched_type = ""
	for type in entity_sprites.keys():
		if entity_sprites[type] == tex:
			matched_type = type
			break
			
	if matched_type != "":
		# Calculate grid position as integers
		var grid_x = int(floor(sprite.position.x / cell_size.x))
		var grid_y = int(floor(sprite.position.y / cell_size.y))
		
		if grid_x < 0 or grid_x >= grid_width or grid_y < 0 or grid_y >= grid_height:
			return
		
		# Reparent to entities_node first so local coordinates are correct
		sprite.reparent(entities_node)
		
		# Snap position
		sprite.position = Vector2(grid_x * cell_size.x + cell_size.x / 2.0, grid_y * cell_size.y + cell_size.y / 2.0)
		
		# Add metadata
		sprite.set_meta("grid_x", grid_x)
		sprite.set_meta("grid_y", grid_y)
		sprite.set_meta("type", matched_type)
		sprite.name = "Entity_" + matched_type + "_" + str(grid_x) + "_" + str(grid_y)
		
		_set_owner_recursive(sprite)
		
		# Remove any existing entity at this position (unless it's the same sprite)
		for child in entities_node.get_children():
			if child != sprite and child.has_meta("grid_x") and child.has_meta("grid_y"):
				if int(child.get_meta("grid_x")) == grid_x and int(child.get_meta("grid_y")) == grid_y:
					child.queue_free()
					
		print("Assimilated dragged object as ", matched_type, " at ", Vector2i(grid_x, grid_y))
		queue_redraw()

func _ensure_containers():
	if not has_node("Background"):
		bg_node = Node2D.new()
		bg_node.name = "Background"
		add_child(bg_node)
		_set_owner_recursive(bg_node)
	else:
		bg_node = get_node("Background")
	bg_node.z_index = 0
		
	if not has_node("Roads"):
		roads_node = Node2D.new()
		roads_node.name = "Roads"
		add_child(roads_node)
		_set_owner_recursive(roads_node)
	else:
		roads_node = get_node("Roads")
	roads_node.z_index = 20
		
	if not has_node("Entities"):
		entities_node = Node2D.new()
		entities_node.name = "Entities"
		add_child(entities_node)
		_set_owner_recursive(entities_node)
	else:
		entities_node = get_node("Entities")
	entities_node.z_index = 40

func _draw():
	if not Engine.is_editor_hint():
		return
		
	# Draw grid
	var grid_color = Color(1.0, 1.0, 1.0, 0.2)
	for x in range(grid_width + 1):
		draw_line(Vector2(x * cell_size.x, 0), Vector2(x * cell_size.x, grid_height * cell_size.y), grid_color)
	for y in range(grid_height + 1):
		draw_line(Vector2(0, y * cell_size.y), Vector2(grid_width * cell_size.x, y * cell_size.y), grid_color)

func _add_road():
	_ensure_containers()
	var rect = add_road_rect
	
	var road = NinePatchRect.new()
	road.name = "Road_" + str(rect.position.x) + "_" + str(rect.position.y)
	road.texture = road_texture
	var overlap = 0
	if typeof(texture_overlap) == TYPE_INT or typeof(texture_overlap) == TYPE_FLOAT:
		overlap = int(texture_overlap)
		
	if rect.size.y > rect.size.x:
		# Vertical road (rotate 90 degrees)
		road.size = Vector2(rect.size.y * cell_size.y + overlap * 2, rect.size.x * cell_size.x + overlap * 2)
		road.rotation_degrees = 90
		road.position = Vector2(rect.position.x * cell_size.x + rect.size.x * cell_size.x + overlap, rect.position.y * cell_size.y - overlap)
	else:
		# Horizontal road
		road.size = Vector2(rect.size.x * cell_size.x + overlap * 2, rect.size.y * cell_size.y + overlap * 2)
		road.rotation_degrees = 0
		road.position = Vector2(rect.position.x * cell_size.x - overlap, rect.position.y * cell_size.y - overlap)
	
	road.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	road.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
	
	if road_texture != null:
		var img = road_texture.get_image()
		if img != null:
			var used = img.get_used_rect()
			if used.size.x > 0 and used.size.y > 0:
				road.region_rect = Rect2(used)
	
	road.patch_margin_left = 0
	road.patch_margin_top = 0
	road.patch_margin_right = 0
	road.patch_margin_bottom = 0
	
	roads_node.add_child(road)
	_set_owner_recursive(road)
	
	road.set_meta("grid_x", rect.position.x)
	road.set_meta("grid_y", rect.position.y)
	road.set_meta("grid_w", rect.size.x)
	road.set_meta("grid_h", rect.size.y)
	
	queue_redraw()
	print("Added road at ", rect)

func _place_entity():
	_ensure_containers()
	var pos = entity_grid_pos
	var type_str = selected_entity_type
	if type_str == "":
		print("No entity type selected!")
		return
	
	
	if type_str == "rock":
		for child in entities_node.get_children():
			if child.has_meta("grid_x") and child.has_meta("grid_y"):
				if child.get_meta("grid_x") == pos.x and child.get_meta("grid_y") == pos.y:
					if child.get_meta("type") == "rock":
						child.queue_free()
						queue_redraw()
						print("Removed rock at ", pos)
						return

	if type_str == "player":
		for child in entities_node.get_children():
			if child.has_meta("type") and child.get_meta("type") == "player":
				child.queue_free()
	
	for child in entities_node.get_children():
		if child.has_meta("grid_x") and child.has_meta("grid_y"):
			if child.get_meta("grid_x") == pos.x and child.get_meta("grid_y") == pos.y:
				child.queue_free()
				
	var sprite = Sprite2D.new()
	sprite.name = "Entity_" + type_str + "_" + str(pos.x) + "_" + str(pos.y)
	if entity_sprites.has(type_str) and entity_sprites[type_str] != null:
		sprite.texture = entity_sprites[type_str]
		var tex_size = sprite.texture.get_size()
		if tex_size.x > 0 and tex_size.y > 0:
			var scale_factor = min(cell_size.x / tex_size.x, cell_size.y / tex_size.y)
			sprite.scale = Vector2(scale_factor, scale_factor)
	sprite.position = Vector2(pos.x * cell_size.x + cell_size.x / 2.0, pos.y * cell_size.y + cell_size.y / 2.0)
	
	entities_node.add_child(sprite)
	_set_owner_recursive(sprite)
	
	sprite.set_meta("grid_x", pos.x)
	sprite.set_meta("grid_y", pos.y)
	sprite.set_meta("type", type_str)
	
	queue_redraw()
	print("Placed entity ", type_str, " at ", pos)

func _clear_board():
	_ensure_containers()
	for child in roads_node.get_children():
		child.queue_free()
	for child in entities_node.get_children():
		child.queue_free()
	queue_redraw()
	print("Cleared board")

func _save_level():
	var level_data = target_level_resource
	if not level_data:
		level_data = LevelData.new()
		
	level_data.grid_columns = grid_width
	level_data.grid_rows = grid_height
	level_data.cell_size = cell_size
	
	var roads: Array[Dictionary] = []
	if roads_node:
		for child in roads_node.get_children():
			if child is NinePatchRect and child.has_meta("grid_x"):
				var overlap = 0
				if typeof(texture_overlap) == TYPE_INT or typeof(texture_overlap) == TYPE_FLOAT:
					overlap = int(texture_overlap)
					
				var g_x = 0
				var g_y = 0
				var g_w = 0
				var g_h = 0
				
				if is_equal_approx(child.rotation_degrees, 90.0):
					g_h = round((child.size.x - overlap * 2) / cell_size.y)
					g_w = round((child.size.y - overlap * 2) / cell_size.x)
					g_x = round((child.position.x - overlap) / cell_size.x) - g_w
					g_y = round((child.position.y + overlap) / cell_size.y)
				else:
					g_w = round((child.size.x - overlap * 2) / cell_size.x)
					g_h = round((child.size.y - overlap * 2) / cell_size.y)
					g_x = round((child.position.x + overlap) / cell_size.x)
					g_y = round((child.position.y + overlap) / cell_size.y)
					
				roads.append({
					"x": g_x,
					"y": g_y,
					"width": g_w,
					"height": g_h
				})
	level_data.roads = roads
	
	var entities: Array[Dictionary] = []
	var obstacles: Array[Vector2i] = []
	if entities_node:
		for child in entities_node.get_children():
			if child.has_meta("type"):
				var t_str = child.get_meta("type")
				
				# Recalculate based on current visual position in case user dragged it around
				var g_x = int(floor(child.position.x / cell_size.x))
				var g_y = int(floor(child.position.y / cell_size.y))
				
				if g_x < 0 or g_x >= grid_width or g_y < 0 or g_y >= grid_height:
					continue
					
				# Visually snap it to guarantee it aligns with the saved data
				child.position = Vector2(g_x * cell_size.x + cell_size.x / 2.0, g_y * cell_size.y + cell_size.y / 2.0)
				child.name = "Entity_" + t_str + "_" + str(g_x) + "_" + str(g_y)
				child.set_meta("grid_x", g_x)
				child.set_meta("grid_y", g_y)
				
				if t_str == "rock":
					obstacles.append(Vector2i(g_x, g_y))
				else:
					entities.append({
						"cell_x": g_x,
						"cell_y": g_y,
						"type": t_str
					})
	level_data.entities = entities
	level_data.obstacles = obstacles
	
	var dir = level_file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
		
	var err = ResourceSaver.save(level_data, level_file_path)
	if err == OK:
		target_level_resource = level_data
		print("Saved level successfully to ", level_file_path)
	else:
		print("Failed to save level: error code ", err)

func _load_level():
	if not FileAccess.file_exists(level_file_path):
		print("Level file does not exist: ", level_file_path)
		return
		
	var res = ResourceLoader.load(level_file_path)
	if not res is LevelData:
		print("Resource is not LevelData: ", level_file_path)
		return
		
	target_level_resource = res
	grid_width = res.grid_columns
	grid_height = res.grid_rows
	cell_size = res.cell_size
	
	_clear_board()
	_ensure_containers()
	
	var overlap = 0
	if typeof(texture_overlap) == TYPE_INT or typeof(texture_overlap) == TYPE_FLOAT:
		overlap = int(texture_overlap)
	
	var roads_list = res.roads if res.roads != null else []
	for r_data in roads_list:
		var road = NinePatchRect.new()
		road.name = "Road_" + str(r_data.x) + "_" + str(r_data.y)
		road.texture = road_texture
		if r_data.height > r_data.width:
			# Vertical road
			road.size = Vector2(r_data.height * cell_size.y + overlap * 2, r_data.width * cell_size.x + overlap * 2)
			road.rotation_degrees = 90
			road.position = Vector2(r_data.x * cell_size.x + r_data.width * cell_size.x + overlap, r_data.y * cell_size.y - overlap)
		else:
			# Horizontal road
			road.size = Vector2(r_data.width * cell_size.x + overlap * 2, r_data.height * cell_size.y + overlap * 2)
			road.rotation_degrees = 0
			road.position = Vector2(r_data.x * cell_size.x - overlap, r_data.y * cell_size.y - overlap)
		road.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		road.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		
		if road_texture != null:
			var img = road_texture.get_image()
			if img != null:
				var used = img.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					road.region_rect = Rect2(used)
					
		road.patch_margin_left = 0
		road.patch_margin_top = 0
		road.patch_margin_right = 0
		road.patch_margin_bottom = 0
		roads_node.add_child(road)
		_set_owner_recursive(road)
		road.set_meta("grid_x", r_data.x)
		road.set_meta("grid_y", r_data.y)
		road.set_meta("grid_w", r_data.width)
		road.set_meta("grid_h", r_data.height)
	
	for e_data in res.entities:
		var sprite = Sprite2D.new()
		var t_str = e_data.type
		sprite.name = "Entity_" + t_str + "_" + str(e_data.cell_x) + "_" + str(e_data.cell_y)
		if entity_sprites.has(t_str) and entity_sprites[t_str] != null:
			sprite.texture = entity_sprites[t_str]
			var tex_size = sprite.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_factor = min(cell_size.x / tex_size.x, cell_size.y / tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.position = Vector2(e_data.cell_x * cell_size.x + cell_size.x / 2.0, e_data.cell_y * cell_size.y + cell_size.y / 2.0)
		
		entities_node.add_child(sprite)
		_set_owner_recursive(sprite)
		
		sprite.set_meta("grid_x", e_data.cell_x)
		sprite.set_meta("grid_y", e_data.cell_y)
		sprite.set_meta("type", t_str)
		
	var obstacles_list = res.obstacles if res.obstacles != null else []
	for obs in obstacles_list:
		var sprite = Sprite2D.new()
		var t_str = "rock"
		sprite.name = "Entity_" + t_str + "_" + str(obs.x) + "_" + str(obs.y)
		if entity_sprites.has(t_str) and entity_sprites[t_str] != null:
			sprite.texture = entity_sprites[t_str]
			var tex_size = sprite.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_factor = min(cell_size.x / tex_size.x, cell_size.y / tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.position = Vector2(obs.x * cell_size.x + cell_size.x / 2.0, obs.y * cell_size.y + cell_size.y / 2.0)
		
		entities_node.add_child(sprite)
		_set_owner_recursive(sprite)
		
		sprite.set_meta("grid_x", obs.x)
		sprite.set_meta("grid_y", obs.y)
		sprite.set_meta("type", t_str)

	queue_redraw()
	print("Loaded level successfully from ", level_file_path)

func _set_owner_recursive(node: Node):
	if Engine.is_editor_hint():
		if get_tree() and get_tree().edited_scene_root:
			node.owner = get_tree().edited_scene_root
	for child in node.get_children():
		_set_owner_recursive(child)
