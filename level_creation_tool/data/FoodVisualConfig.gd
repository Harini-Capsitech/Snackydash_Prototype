class_name FoodVisualConfig
extends Resource

@export var burger: Texture2D
@export var pizza: Texture2D
@export var donut: Texture2D
@export var fries: Texture2D
@export var ice_cream: Texture2D
@export var taco: Texture2D

func get_texture_by_id(food_id: String) -> Texture2D:
	var id = food_id.to_lower().replace(" ", "_")
	match id:
		"burger": return burger
		"pizza": return pizza
		"donut": return donut
		"fries": return fries
		"ice_cream", "icecream": return ice_cream
		"taco": return taco
	return null
