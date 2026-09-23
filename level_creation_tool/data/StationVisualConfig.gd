class_name StationVisualConfig
extends Resource

@export var station_base: Texture2D
@export var default_tray_texture: Texture2D
@export var tray_configs: Array[TrayVisualConfig] = []
@export var station_variants: Array[StationVariant] = []

func get_tray_config(food_id: String) -> TrayVisualConfig:
	var target = food_id.to_lower().replace(" ", "_")
	for cfg in tray_configs:
		if cfg and cfg.food_id.to_lower().replace(" ", "_") == target:
			return cfg
	return null

func get_variant_by_food_id(food_id: String) -> StationVariant:
	var target = food_id.to_lower().replace(" ", "_")
	for variant in station_variants:
		if variant and variant.required_food_type.to_lower().replace(" ", "_") == target:
			return variant
	return null
