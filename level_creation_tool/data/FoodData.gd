class_name FoodData
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var food_id: String = "burger"
@export var visual_pos: Vector2 = Vector2.ZERO
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_rot: float = 0.0
@export var texture_path: String = ""

func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"food_id": food_id
	}

func from_dict(data: Dictionary) -> void:
	position = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	food_id = data.get("food_id", "burger")
