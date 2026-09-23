extends RefCounted
class_name LevelSolver

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const DIRECTION_NAMES := ["UP", "RIGHT", "DOWN", "LEFT"]

static func solve(data: LevelData, node_limit: int = 50000, depth_limit: int = 200) -> Dictionary:
	var result := {"solvable": false, "solution": [], "node_count": 0, "limited": false, "message": ""}
	
	var road_cells: Array[Vector2i] = []
	for r in data.roads:
		for x in range(r.width):
			for y in range(r.height):
				road_cells.append(Vector2i(r.x + x, r.y + y))
				
	var grid := GridManager.new()
	grid.setup_level(data.grid_columns, data.grid_rows, int(data.cell_size.x), road_cells, [])
	
	var fruits: Array[Dictionary] = []
	var trucks: Array[Dictionary] = []
	var player_start: Vector2i = Vector2i.ZERO
	for e in data.entities:
		if e.type == "player":
			player_start = Vector2i(e.cell_x, e.cell_y)
		elif e.type == "box":
			trucks.append({
				"position": Vector2i(e.cell_x, e.cell_y),
				"width": int(e.get("width", 1)),
				"height": int(e.get("height", 1)),
				"type": "apple_red",
				"required": 5
			})
		else:
			fruits.append({"position": Vector2i(e.cell_x, e.cell_y), "type": e.type})

	var initial := {"position": player_start, "collected": [], "progress": _zero_progress(trucks), "path": []}
	var queue: Array[Dictionary] = [initial]
	var visited := {_state_key(initial): true}

	while not queue.is_empty():
		var state: Dictionary = queue.pop_front()
		result["node_count"] += 1
		if _goal_reached(state, trucks):
			result["solvable"] = true
			result["solution"] = state["path"]
			result["message"] = "Solved in %d moves." % state["path"].size()
			return result
		if result["node_count"] >= node_limit or state["path"].size() >= depth_limit:
			result["limited"] = true
			result["message"] = "Unsolved within search limit."
			return result

		for direction_index in range(DIRECTIONS.size()):
			var direction: Vector2i = DIRECTIONS[direction_index]
			var destination := grid.get_slide_destination(state["position"], direction)
			if destination == state["position"]:
				continue
			var crossed := grid.get_cells_along_path(state["position"], direction)
			var next_state := _advance_state(state, destination, crossed, fruits, trucks)
			next_state["path"] = state["path"].duplicate()
			next_state["path"].append(DIRECTION_NAMES[direction_index])
			var key := _state_key(next_state)
			if not visited.has(key):
				visited[key] = true
				queue.append(next_state)

	result["message"] = "No solution exists."
	return result

static func _advance_state(state: Dictionary, destination: Vector2i, crossed: Array[Vector2i], fruits: Array[Dictionary], trucks: Array[Dictionary]) -> Dictionary:
	var collected: Array = state["collected"].duplicate()
	for index in range(fruits.size()):
		if index not in collected and fruits[index].get("position") in crossed:
			collected.append(index)
	var progress: Array = state["progress"].duplicate()
	for truck_index in range(trucks.size()):
		var t_pos: Vector2i = trucks[truck_index].get("position")
		var t_w: int = int(trucks[truck_index].get("width", 1))
		var t_h: int = int(trucks[truck_index].get("height", 1))
		var at_truck = destination.x >= t_pos.x and destination.x < t_pos.x + t_w and \
					   destination.y >= t_pos.y and destination.y < t_pos.y + t_h
		if at_truck:
			var truck_type: String = trucks[truck_index].get("type", "")
			var available := 0
			for fruit_index in collected:
				if fruits[fruit_index].get("type", "") == truck_type:
					available += 1
			for previous_truck_index in range(trucks.size()):
				if previous_truck_index != truck_index and trucks[previous_truck_index].get("type", "") == truck_type:
					available -= int(progress[previous_truck_index])
			var needed := int(trucks[truck_index].get("required", 0)) - int(progress[truck_index])
			progress[truck_index] += min(needed, max(0, available))
	return {"position": destination, "collected": collected, "progress": progress, "path": []}

static func _goal_reached(state: Dictionary, trucks: Array[Dictionary]) -> bool:
	for index in range(trucks.size()):
		if int(state["progress"][index]) < int(trucks[index].get("required", 0)):
			return false
	return true

static func _state_key(state: Dictionary) -> String:
	return "%s|%s|%s" % [state["position"], state["collected"], state["progress"]]

static func _zero_progress(trucks: Array[Dictionary]) -> Array:
	var progress: Array = []
	for _truck in trucks:
		progress.append(0)
	return progress
