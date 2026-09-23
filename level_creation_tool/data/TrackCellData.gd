class_name TrackCellData
extends Resource

@export var position: Vector2i
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var source_id: int = 0

# Logical connections (the Source of Truth)
@export var connect_up: bool = false
@export var connect_down: bool = false
@export var connect_left: bool = false
@export var connect_right: bool = false

# Optional visual metadata (assigned by editor, read by game)
@export var track_type_id: String = "normal"

func _init(p_position: Vector2i = Vector2i.ZERO) -> void:
	position = p_position

func has_any_connection() -> bool:
	return connect_up or connect_down or connect_left or connect_right

func clear_connections() -> void:
	connect_up = false
	connect_down = false
	connect_left = false
	connect_right = false

func to_dict() -> Dictionary:
	return {
		"position": {"x": position.x, "y": position.y},
		"up": connect_up,
		"down": connect_down,
		"left": connect_left,
		"right": connect_right,
		"track_type_id": track_type_id
	}

func from_dict(data: Dictionary) -> void:
	position = Vector2i(data.get("position", {}).get("x", 0), data.get("position", {}).get("y", 0))
	connect_up = data.get("up", false)
	connect_down = data.get("down", false)
	connect_left = data.get("left", false)
	connect_right = data.get("right", false)
	track_type_id = data.get("track_type_id", "normal")
