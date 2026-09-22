## TrackGraph handles node-to-node path tracing across the road maze.
## Implements the autonomous glide mechanic: once the player drags in a direction,
## the snake dashes forward down the corridor until it reaches the next Junction/Checkpoint.
class_name TrackGraph
extends RefCounted

const GameConfig = preload("res://scripts/game_config.gd")

## Returns true if a tile position is walkable road
static func is_road(pos: Vector2i, grid: Array, rows: int, cols: int) -> bool:
	if pos.x < 0 or pos.x >= cols or pos.y < 0 or pos.y >= rows:
		return false
	var tile: String = grid[pos.y][pos.x]
	return tile != GameConfig.TILE_WALL

## Returns all orthogonal road neighbors for a tile
static func get_neighbors(pos: Vector2i, grid: Array, rows: int, cols: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var dirs = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	for d in dirs:
		var np = pos + d
		if is_road(np, grid, rows, cols):
			result.append(np)
	return result

## Determines if a grid coordinate is a Junction Node (fork, intersection, or checkpoint)
static func is_junction(pos: Vector2i, grid: Array, rows: int, cols: int) -> bool:
	if not is_road(pos, grid, rows, cols):
		return false
	var tile: String = grid[pos.y][pos.x]
	if tile == GameConfig.TILE_JUNCTION:
		return true
	if tile == GameConfig.TILE_BRIDGE:
		return false # Bridges are 3D crossovers (overpass/underpass), never stopping junctions!
		
	var neighbors = get_neighbors(pos, grid, rows, cols)
	# A 3-way or 4-way intersection is always a junction
	if neighbors.size() >= 3:
		return true
	# A dead-end is also a stop node
	if neighbors.size() == 1:
		return true
	# Check if adjacent to a Crate intake
	for n in neighbors:
		if grid[n.y][n.x] == GameConfig.TILE_CRATE:
			return true
			
	return false

## Traces autonomous linear travel from start_pos along initial direction.
## Continues through single corners, and stops at the next Junction Checkpoint.
## Returns Array[Vector2i] representing the ordered path of steps.
static func trace_path_to_next_junction(
	start_pos: Vector2i,
	initial_dir: Vector2i,
	grid: Array,
	rows: int,
	cols: int
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if initial_dir == Vector2i.ZERO:
		return path
		
	var curr: Vector2i = start_pos
	var current_dir: Vector2i = initial_dir
	var max_steps: int = 200 # Safety against infinite loop
	
	# Initial step
	var next_tile: Vector2i = curr + current_dir
	if not is_road(next_tile, grid, rows, cols):
		return path # Blocked
		
	path.append(next_tile)
	curr = next_tile
	
	# If the immediate next tile is already a junction, we stop right there
	if is_junction(curr, grid, rows, cols):
		return path
		
	# Otherwise, glide automatically down the corridor until hitting a junction
	while max_steps > 0:
		max_steps -= 1
		
		# If we reached a junction checkpoint, stop!
		if is_junction(curr, grid, rows, cols):
			break
			
		var neighbors = get_neighbors(curr, grid, rows, cols)
		
		# If on a bridge, force continuation straight across overpass / through underpass
		if grid[curr.y][curr.x] == GameConfig.TILE_BRIDGE:
			var bridge_straight = curr + current_dir
			if is_road(bridge_straight, grid, rows, cols):
				path.append(bridge_straight)
				curr = bridge_straight
				continue

		# Try to continue in the same direction
		var straight_tile = curr + current_dir
		if straight_tile in neighbors:
			path.append(straight_tile)
			curr = straight_tile
			continue
			
		# If cannot go straight, find the only available turn (excluding the tile we just came from)
		var prev_tile = path[path.size() - 2] if path.size() >= 2 else start_pos
		var valid_turns: Array[Vector2i] = []
		for n in neighbors:
			if n != prev_tile:
				valid_turns.append(n)
				
		if valid_turns.size() == 1:
			var turn_tile = valid_turns[0]
			current_dir = turn_tile - curr
			path.append(turn_tile)
			curr = turn_tile
		else:
			# Junction or dead end reached
			break
			
	return path
