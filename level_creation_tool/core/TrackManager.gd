class_name TrackManager
extends Node

# Key: Vector2i, Value: TrackCellData
var tracks: Dictionary = {}
var grid: EditorGrid

func _init(p_grid: EditorGrid) -> void:
	grid = p_grid

func get_track(pos: Vector2i) -> TrackCellData:
	return tracks.get(pos, null)

func add_track(pos: Vector2i) -> void:
	if not grid.is_within_bounds(pos): return
	if not tracks.has(pos):
		tracks[pos] = TrackCellData.new(pos)

func remove_track(pos: Vector2i) -> void:
	if tracks.has(pos):
		var track = tracks[pos]
		# Disconnect neighbors
		if track.connect_up: disconnect_cells(pos, pos + Vector2i(0, -1))
		if track.connect_down: disconnect_cells(pos, pos + Vector2i(0, 1))
		if track.connect_left: disconnect_cells(pos, pos + Vector2i(-1, 0))
		if track.connect_right: disconnect_cells(pos, pos + Vector2i(1, 0))
		tracks.erase(pos)

func connect_cells(pos1: Vector2i, pos2: Vector2i) -> void:
	add_track(pos1)
	add_track(pos2)
	
	var track1 = tracks[pos1]
	var track2 = tracks[pos2]
	
	var diff = pos2 - pos1
	if diff == Vector2i(0, -1):
		track1.connect_up = true
		track2.connect_down = true
	elif diff == Vector2i(0, 1):
		track1.connect_down = true
		track2.connect_up = true
	elif diff == Vector2i(-1, 0):
		track1.connect_left = true
		track2.connect_right = true
	elif diff == Vector2i(1, 0):
		track1.connect_right = true
		track2.connect_left = true

func disconnect_cells(pos1: Vector2i, pos2: Vector2i) -> void:
	if not tracks.has(pos1) or not tracks.has(pos2): return
	var track1 = tracks[pos1]
	var track2 = tracks[pos2]
	
	var diff = pos2 - pos1
	if diff == Vector2i(0, -1):
		track1.connect_up = false
		track2.connect_down = false
	elif diff == Vector2i(0, 1):
		track1.connect_down = false
		track2.connect_up = false
	elif diff == Vector2i(-1, 0):
		track1.connect_left = false
		track2.connect_right = false
	elif diff == Vector2i(1, 0):
		track1.connect_right = false
		track2.connect_left = false

func determine_track_shape(pos: Vector2i) -> String:
	if not tracks.has(pos): return "empty"
	var t = tracks[pos]
	
	var connections = 0
	if t.connect_up: connections += 1
	if t.connect_down: connections += 1
	if t.connect_left: connections += 1
	if t.connect_right: connections += 1
	
	if connections == 0: return "empty"
	if connections == 1: return "dead_end"
	
	if connections == 2:
		if t.connect_left and t.connect_right: return "horizontal"
		if t.connect_up and t.connect_down: return "vertical"
		return "corner"
		
	if connections == 3: return "t_junction"
	if connections == 4: return "cross_junction"
	
	return "empty"

func clear_all() -> void:
	tracks.clear()
