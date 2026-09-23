class_name ObstacleData
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var obstacle_type: String = "barrier"
@export var visual_pos: Vector2 = Vector2.ZERO
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_rot: float = 0.0
@export var texture_path: String = ""

func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"obstacle_type": obstacle_type
	}

func from_dict(data: Dictionary) -> void:
	position = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	obstacle_type = data.get("obstacle_type", "barrier")
