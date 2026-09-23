class_name TrainSpawnData
extends Resource

@export var position: Vector2i = Vector2i.ZERO
@export var facing_direction: Vector2i = Vector2i.RIGHT
@export var visual_pos: Vector2 = Vector2.ZERO
@export var visual_scale: Vector2 = Vector2.ONE
@export var visual_rot: float = 0.0
@export var texture_path: String = ""

func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"facing_direction": {"x": facing_direction.x, "y": facing_direction.y}
	}

func from_dict(data: Dictionary) -> void:
	position = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	facing_direction = Vector2i(data.get("facing_direction", {}).get("x", 1), data.get("facing_direction", {}).get("y", 0))
