extends Resource
class_name LevelData

@export var level_id: int = 1
@export var width: int = 10
@export var height: int = 14
@export var cell_size: int = 48
@export var road_cells: Array[Vector2i] = []
@export var blocked_footprints: Array[Dictionary] = []
@export var player_start: Vector2i = Vector2i(-1, -1)
@export var fruits: Array[Dictionary] = []
@export var trucks: Array[Dictionary] = []

static func from_dictionary(source: Dictionary) -> LevelData:
	var data := LevelData.new()
	data.level_id = int(source.get("level_id", 1))
	data.width = int(source.get("width", 10))
	data.height = int(source.get("height", 14))
	data.cell_size = int(source.get("cell_size", 48))
	data.player_start = _vector_from_value(source.get("player_start", Vector2i(-1, -1)))

	for value in source.get("road_cells", []):
		data.road_cells.append(_vector_from_value(value))
	for value in source.get("blocked_footprints", []):
		var footprint: Dictionary = value.duplicate(true)
		footprint["position"] = _vector_from_value(footprint.get("position", Vector2i.ZERO))
		footprint["size"] = _vector_from_value(footprint.get("size", Vector2i.ONE))
		data.blocked_footprints.append(footprint)
	for value in source.get("fruits", []):
		var fruit: Dictionary = value.duplicate(true)
		fruit["position"] = _vector_from_value(fruit.get("position", Vector2i.ZERO))
		fruit["type"] = str(fruit.get("type", "APPLE"))
		data.fruits.append(fruit)
	for value in source.get("trucks", []):
		var truck: Dictionary = value.duplicate(true)
		truck["position"] = _vector_from_value(truck.get("position", Vector2i.ZERO))
		truck["type"] = str(truck.get("type", "APPLE"))
		truck["required"] = int(truck.get("required", 1))
		data.trucks.append(truck)
	return data

static func from_json(json_text: String) -> LevelData:
	var parsed = JSON.parse_string(json_text)
	if not parsed is Dictionary:
		return null
	return from_dictionary(parsed)

func to_dictionary() -> Dictionary:
	var result := {
		"level_id": level_id,
		"width": width,
		"height": height,
		"cell_size": cell_size,
		"road_cells": [],
		"blocked_footprints": [],
		"player_start": _vector_to_array(player_start),
		"fruits": [],
		"trucks": []
	}
	for cell in road_cells:
		result["road_cells"].append(_vector_to_array(cell))
	for value in blocked_footprints:
		result["blocked_footprints"].append({
			"position": _vector_to_array(value.get("position", Vector2i.ZERO)),
			"size": _vector_to_array(value.get("size", Vector2i.ONE))
		})
	for value in fruits:
		result["fruits"].append({
			"type": str(value.get("type", "APPLE")),
			"position": _vector_to_array(value.get("position", Vector2i.ZERO))
		})
	for value in trucks:
		result["trucks"].append({
			"type": str(value.get("type", "APPLE")),
			"position": _vector_to_array(value.get("position", Vector2i.ZERO)),
			"required": int(value.get("required", 1))
		})
	return result

func to_json() -> String:
	return JSON.stringify(to_dictionary(), "  ")

func footprint_cells(footprint: Dictionary) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var position: Vector2i = footprint.get("position", Vector2i.ZERO)
	var size: Vector2i = footprint.get("size", Vector2i.ONE)
	for y in range(size.y):
		for x in range(size.x):
			cells.append(position + Vector2i(x, y))
	return cells

static func _vector_from_value(value: Variant) -> Vector2i:
	if value is Vector2i:
		return value
	if value is Vector2:
		return Vector2i(value)
	if value is Array and value.size() >= 2:
		return Vector2i(int(value[0]), int(value[1]))
	if value is Dictionary:
		return Vector2i(int(value.get("x", 0)), int(value.get("y", 0)))
	return Vector2i.ZERO

static func _vector_to_array(value: Variant) -> Array:
	var vector := _vector_from_value(value)
	return [vector.x, vector.y]