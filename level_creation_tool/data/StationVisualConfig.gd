class_name StationVisualConfig
extends Resource

@export var station_base: Texture2D
@export var station_variants: Array[StationVariant] = []

func get_variant_by_food_id(food_id: String) -> StationVariant:
	var target = food_id.to_lower().replace(" ", "_")
	for variant in station_variants:
		if variant.required_food_type.to_lower().replace(" ", "_") == target:
			return variant
	return null
