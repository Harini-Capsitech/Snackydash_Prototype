extends Node2D
class_name LevelBuilder

const ROAD_COLORS := {
	0: Color("#858b91"), 1: Color("#9aa1a8"), 2: Color("#9aa1a8"), 3: Color("#aeb4ba"),
	4: Color("#9aa1a8"), 5: Color("#aeb4ba"), 6: Color("#aeb4ba"), 7: Color("#c0c5ca"),
	8: Color("#9aa1a8"), 9: Color("#aeb4ba"), 10: Color("#aeb4ba"), 11: Color("#c0c5ca"),
	12: Color("#aeb4ba"), 13: Color("#c0c5ca"), 14: Color("#c0c5ca"), 15: Color("#d3d7db")
}

func build(data: LevelData, grid: GridManager, player: Player, items_container: Node, trucks_container: Node, walls_container: Node) -> Dictionary:
	clear_visuals(items_container, trucks_container, walls_container)
	var blocked_cells: Array[Vector2i] = []
	for footprint in data.blocked_footprints:
		blocked_cells.append_array(data.footprint_cells(footprint))
	grid.setup_level(data.width, data.height, data.cell_size, data.road_cells, blocked_cells)
	_build_road_tile_map(data, grid, walls_container)
	_build_footprints(data, grid, walls_container)
	player.setup(data.player_start, grid)

	var fruit_scene := load("res://scenes/Fruit.tscn")
	var fruits: Array[Fruit] = []
	for fruit_data in data.fruits:
		var fruit: Fruit = fruit_scene.instantiate()
		items_container.add_child(fruit)
		fruit.setup(fruit_data["position"], fruit_data["type"], grid)
		fruits.append(fruit)

	var truck_scene := load("res://scenes/Truck.tscn")
	var trucks: Array[Truck] = []
	for truck_data in data.trucks:
		var truck: Truck = truck_scene.instantiate()
		trucks_container.add_child(truck)
		truck.setup(truck_data["position"], truck_data["type"], truck_data["required"], grid)
		trucks.append(truck)
	return {"fruits": fruits, "trucks": trucks}

func clear_visuals(items_container: Node, trucks_container: Node, walls_container: Node) -> void:
	for container in [items_container, trucks_container, walls_container]:
		for child in container.get_children():
			child.queue_free()

func _build_road_tile_map(data: LevelData, grid: GridManager, parent: Node) -> void:
	var road_tile_map := TileMap.new()
	road_tile_map.name = "RoadTileMap"
	road_tile_map.tile_set = load("res://tiles/RoadTileSet.tres")
	parent.add_child(road_tile_map)
	for cell in data.road_cells:
		var tile := ColorRect.new()
		tile.name = "Road_%d_%d" % [cell.x, cell.y]
		tile.size = Vector2(data.cell_size - 2, data.cell_size - 2)
		tile.color = ROAD_COLORS.get(_neighbor_mask(cell, data.road_cells), ROAD_COLORS[0])
		tile.position = grid.cell_to_world(cell) - tile.size / 2.0
		road_tile_map.add_child(tile)

func _build_footprints(data: LevelData, grid: GridManager, parent: Node) -> void:
	for index in range(data.blocked_footprints.size()):
		var footprint: Dictionary = data.blocked_footprints[index]
		var island := ColorRect.new()
		island.name = "BlockedFootprint_%d" % index
		var size: Vector2i = footprint["size"]
		island.size = Vector2(size.x * data.cell_size, size.y * data.cell_size)
		island.color = Color("#4f7d54")
		island.position = grid.cell_to_world(footprint["position"]) - Vector2(data.cell_size, data.cell_size) / 2.0
		parent.add_child(island)

func _neighbor_mask(cell: Vector2i, roads: Array[Vector2i]) -> int:
	var mask := 0
	if cell + Vector2i.UP in roads:
		mask |= 1
	if cell + Vector2i.RIGHT in roads:
		mask |= 2
	if cell + Vector2i.DOWN in roads:
		mask |= 4
	if cell + Vector2i.LEFT in roads:
		mask |= 8
	return mask