extends RefCounted
class_name LevelValidator

static func validate(data: LevelData) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if data == null:
		return [_result(false, "Level data is missing.")]
	if data.width <= 0 or data.height <= 0:
		results.append(_result(false, "Grid dimensions must be greater than zero."))
	if data.cell_size <= 0:
		results.append(_result(false, "Cell size must be greater than zero."))

	var road_lookup := {}
	for cell in data.road_cells:
		if not _inside(data, cell):
			results.append(_result(false, "Road cell %s is outside the grid." % cell))
		road_lookup[cell] = true

	var footprint_lookup := {}
	for footprint in data.blocked_footprints:
		var position: Vector2i = footprint.get("position", Vector2i.ZERO)
		var size: Vector2i = footprint.get("size", Vector2i.ZERO)
		if size.x <= 0 or size.y <= 0:
			results.append(_result(false, "Blocked footprint at %s has invalid size." % position))
			continue
		for cell in data.footprint_cells(footprint):
			if not _inside(data, cell):
				results.append(_result(false, "Blocked footprint cell %s is outside the grid." % cell))
			if road_lookup.has(cell):
				results.append(_result(false, "Blocked footprint overlaps road cell %s." % cell))
			if footprint_lookup.has(cell):
				results.append(_result(false, "Blocked footprints overlap at %s." % cell))
			footprint_lookup[cell] = true

	if data.player_start == Vector2i(-1, -1):
		results.append(_result(false, "A player start must be placed."))
	elif not _inside(data, data.player_start) or data.player_start not in data.road_cells:
		results.append(_result(false, "Player start must be inside a road cell."))

	var fruit_types := {}
	for fruit in data.fruits:
		var fruit_position: Vector2i = fruit.get("position", Vector2i(-1, -1))
		if not _inside(data, fruit_position) or fruit_position not in data.road_cells:
			results.append(_result(false, "Fruit at %s must be inside a road cell." % fruit_position))
		var fruit_type := str(fruit.get("type", ""))
		if fruit_type.is_empty():
			results.append(_result(false, "Fruit at %s has no type." % fruit_position))
		fruit_types[fruit_type] = true

	for truck in data.trucks:
		var truck_position: Vector2i = truck.get("position", Vector2i(-1, -1))
		if not _inside(data, truck_position) or truck_position not in data.road_cells:
			results.append(_result(false, "Truck at %s must be inside a road cell." % truck_position))
		var truck_type := str(truck.get("type", ""))
		if not fruit_types.has(truck_type):
			results.append(_result(false, "Truck type %s has no matching fruit." % truck_type))
		if int(truck.get("required", 0)) <= 0:
			results.append(_result(false, "Truck at %s must require at least one fruit." % truck_position))

	if results.is_empty():
		results.append(_result(true, "Level structure is valid."))
	return results

static func is_valid(data: LevelData) -> bool:
	for result in validate(data):
		if not result["pass"]:
			return false
	return true

static func _inside(data: LevelData, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < data.width and cell.y >= 0 and cell.y < data.height

static func _result(passed: bool, message: String) -> Dictionary:
	return {"pass": passed, "message": message}