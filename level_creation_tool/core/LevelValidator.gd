class_name LevelValidator
extends Node

static func validate_level(level_data: RailwayLevelData) -> Array[String]:
	var errors: Array[String] = []
	
	if level_data.tracks.size() == 0:
		errors.append("No tracks placed.")
		
	if level_data.train_spawn == null:
		errors.append("Missing Train Spawn.")
	else:
		var train_pos = level_data.train_spawn.position
		var found_track = false
		for t in level_data.tracks:
			if t.position == train_pos:
				found_track = true
				break
		if not found_track:
			errors.append("Train spawn is not on a track.")
			
	if level_data.foods.size() == 0:
		errors.append("Level has no food items.")
		
	if level_data.stations.size() == 0:
		errors.append("Level has no delivery stations.")
		
	# Check matching foods and stations
	var food_counts = {}
	for f in level_data.foods:
		food_counts[f.food_id] = food_counts.get(f.food_id, 0) + 1
		
	var station_reqs = {}
	for s in level_data.stations:
		if s.tray_food_ids.size() > 0:
			for fid in s.tray_food_ids:
				station_reqs[fid] = station_reqs.get(fid, 0) + 1
		elif s.required_food_id != "":
			station_reqs[s.required_food_id] = station_reqs.get(s.required_food_id, 0) + 1
		
	for food_id in food_counts:
		if not station_reqs.has(food_id):
			errors.append("Food '" + food_id + "' has no matching delivery station.")
			
	for req_id in station_reqs:
		if not food_counts.has(req_id):
			errors.append("Station requires '" + req_id + "' but no such food exists in level.")
	
	# More advanced validation (graph connectivity) could go here
	
	return errors
