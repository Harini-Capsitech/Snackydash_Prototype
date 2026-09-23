class_name StationData
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var required_food_id: String = "burger"
@export var visual_pos: Vector2 = Vector2.ZERO
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_rot: float = 0.0
@export var texture_path: String = ""

func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"required_food_id": required_food_id
	}

func from_dict(data: Dictionary) -> void:
	position = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	required_food_id = data.get("required_food_id", "burger")
