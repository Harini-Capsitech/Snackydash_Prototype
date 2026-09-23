extends Node2D
class_name LevelBuilder

func build(data: LevelData, grid: GridManager, game_manager: Node2D) -> Dictionary:
	var walls_container = Node2D.new()
	walls_container.name = "Walls"
	game_manager.add_child(walls_container)
	
	var items_container = Node2D.new()
	items_container.name = "Items"
	game_manager.add_child(items_container)
	
	var trucks_container = Node2D.new()
	trucks_container.name = "Trucks"
	game_manager.add_child(trucks_container)
	
	var player_scene = load("res://scenes/Player.tscn")
	var player = player_scene.instantiate()
	player.name = "Player"
	game_manager.add_child(player)
	var road_cells: Array[Vector2i] = []
	for r in data.roads:
		for x in range(r.width):
			for y in range(r.height):
				road_cells.append(Vector2i(r.x + x, r.y + y))
				
	var blocked_cells: Array[Vector2i] = []
	if data.obstacles != null:
		blocked_cells.append_array(data.obstacles)
	grid.setup_level(data.grid_columns, data.grid_rows, int(data.cell_size.x), road_cells, blocked_cells)
	
	var offset_x = (1080 - (data.grid_columns * data.cell_size.x)) / 2.0
	var offset_y = (1920 - (data.grid_rows * data.cell_size.y)) / 2.0
	
	var road_texture = null
	
	var editor_scene = load("res://scenes/editor/level.tscn")
	var entity_sprites = {}
	if editor_scene:
		var editor = editor_scene.instantiate()
		road_texture = editor.road_texture
		entity_sprites = editor.entity_sprites.duplicate()
		editor.queue_free()

	# Create Roads
	var roads_node = Node2D.new()
	roads_node.position = Vector2(offset_x, offset_y)
	walls_container.add_child(roads_node)
	for r_data in data.roads:
		var road = NinePatchRect.new()
		road.texture = road_texture
		if r_data.height > r_data.width:
			road.size = Vector2(r_data.height * data.cell_size.y, r_data.width * data.cell_size.x)
			road.rotation_degrees = 90
			road.position = Vector2(r_data.x * data.cell_size.x + r_data.width * data.cell_size.x, r_data.y * data.cell_size.y)
		else:
			road.size = Vector2(r_data.width * data.cell_size.x, r_data.height * data.cell_size.y)
			road.rotation_degrees = 0
			road.position = Vector2(r_data.x * data.cell_size.x, r_data.y * data.cell_size.y)
		road.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		road.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_STRETCH
		
		if road_texture != null:
			var img = road_texture.get_image()
			if img != null:
				var used = img.get_used_rect()
				if used.size.x > 0 and used.size.y > 0:
					road.region_rect = Rect2(used)
		roads_node.add_child(road)
		
	var fruit_scene := load("res://scenes/Fruit.tscn")
	var fruits: Array[Fruit] = []
	var truck_scene := load("res://scenes/Truck.tscn")
	var trucks: Array[Truck] = []
	
	var obstacles: Array[Vector2i] = data.obstacles if data.obstacles != null else []
	for obs in obstacles:
		var sprite = Sprite2D.new()
		sprite.texture = entity_sprites.get("rock", null)
		if sprite.texture:
			var tex_size = sprite.texture.get_size()
			if tex_size.x > 0 and tex_size.y > 0:
				var scale_factor = min(data.cell_size.x / tex_size.x, data.cell_size.y / tex_size.y)
				sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.position = Vector2(offset_x + obs.x * data.cell_size.x + data.cell_size.x / 2.0, offset_y + obs.y * data.cell_size.y + data.cell_size.y / 2.0)
		walls_container.add_child(sprite)

	for e in data.entities:
		var tex = entity_sprites.get(e.type, null)
		var e_w = int(e.get("width", 1))
		var e_h = int(e.get("height", 1))
		if e.type == "player":
			player.setup(Vector2i(e.cell_x, e.cell_y), grid, entity_sprites)
		elif e.type == "box":
			var truck: Truck = truck_scene.instantiate()
			trucks_container.add_child(truck)
			truck.setup(Vector2i(e.cell_x, e.cell_y), "", 0, grid, tex, entity_sprites, Vector2i(e_w, e_h))
			
			var fruit_counts = {}
			for f_data in data.entities:
				if f_data.type != "player" and f_data.type != "box":
					if not fruit_counts.has(f_data.type):
						fruit_counts[f_data.type] = 0
					fruit_counts[f_data.type] += 1
					
			var dynamic_crate_stack: Array[Dictionary] = []
			for f_type in fruit_counts.keys():
				dynamic_crate_stack.append({
					"type": f_type,
					"amount": fruit_counts[f_type],
					"delivered": 0
				})
			
			truck.set_crates(dynamic_crate_stack)
			
			trucks.append(truck)
		else:
			var fruit: Fruit = fruit_scene.instantiate()
			items_container.add_child(fruit)
			fruit.setup(Vector2i(e.cell_x, e.cell_y), e.type, grid, tex)
			fruits.append(fruit)

	return {
		"fruits": fruits, 
		"trucks": trucks,
		"player": player,
		"items_container": items_container,
		"trucks_container": trucks_container,
		"walls_container": walls_container
	}

func clear_visuals(items_container: Node, trucks_container: Node, walls_container: Node) -> void:
	for container in [items_container, trucks_container, walls_container]:
		for child in container.get_children():
			child.queue_free()
