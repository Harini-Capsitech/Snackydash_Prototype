@tool
class_name LevelObject
extends Sprite2D

enum ObjectType {
	TRAIN,
	FOOD,
	STATION,
	OBSTACLE
}

@export var type: ObjectType = ObjectType.FOOD
@export var subtype_id: String = "burger"
@export var train_facing: Vector2i = Vector2i.RIGHT
@export var station_tray_foods: Array[String] = ["burger", "pizza"]
