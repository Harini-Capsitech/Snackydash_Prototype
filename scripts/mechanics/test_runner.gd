extends SceneTree

const GameConfig = preload("res://scripts/game_config.gd")
const LevelData = preload("res://scripts/level_data.gd")
const LevelModel = preload("res://scripts/level_model.gd")
const GameEngine = preload("res://scripts/game_engine.gd")
const TrackGraph = preload("res://scripts/track_graph.gd")

func _init() -> void:
	print("\n===========================================================")
	print(" Snacky Dash - Dynamic Tail Inventory Verification Suite   ")
	print("===========================================================\n")
	
	var levels = LevelData.get_all_levels()
	var engine = GameEngine.new()
	engine.load_level(levels[0]) # Level 1
	
	print("[PASS] Initial snake length: %d segment (Head only)" % engine.snake.size())
	if engine.snake.size() != 1:
		push_error("FAILED: Snake must start with length 1!")
		quit(1)
		return
		
	# 1. TEST FRUIT PICKUP & DYNAMIC TAIL GROWTH
	# Add a second fruit to the immediate corridor to test collecting 2 fruits
	engine.fruits.append({ "pos": Vector2i(4, 4), "type": "R", "collected": false })
	
	engine.set_aim_direction(Vector2i(1, 0))
	var dash_ok = engine.confirm_dash(true)
	print("[PASS] Dash executed: %s" % str(dash_ok))
	print("       Snake length after collecting 2 fruits: %d segments (Head + 2 Wagons)" % engine.snake.size())
	if engine.snake.size() != 3:
		push_error("FAILED: Snake length must be exactly 3 after collecting 2 fruits!")
		quit(1)
		return
		
	print("       Wagon 1: %s | Wagon 2: %s" % [engine.snake[1]["fruit_type"], engine.snake[2]["fruit_type"]])
	
	# 2. TEST CRATE DELIVERY OF 1 FRUIT -> LENGTH DECREASES BY 1
	print("\n[TEST] Crate accepts 1 fruit first...")
	var dock_pos = engine.crate_dock
	var active_crate = engine.crate_stack[0]
	active_crate["capacity"] = 2 # Total capacity is 2
	active_crate["filled"] = 0
	
	# Simulate delivery with 1 capacity left first
	active_crate["capacity"] = 1
	var size_before = engine.snake.size()
	engine.process_crate_delivery(dock_pos)
	var size_after = engine.snake.size()
	
	print("[PASS] Tail dynamically shrunk by 1: from %d to %d segments!" % [size_before, size_after])
	if size_after != 2:
		push_error("FAILED: Tail length must decrease by 1 to 2 segments!")
		quit(1)
		return
		
	print("       Remaining fruit in wagon: %s" % engine.snake[1]["fruit_type"])
	
	# 3. TEST DELIVERING 2ND FRUIT -> LENGTH DECREASES TO 1
	print("\n[TEST] Expand capacity to accept second fruit...")
	active_crate["capacity"] = 2
	engine.active_crate_idx = 0 # keep on active crate
	engine.process_crate_delivery(dock_pos)
	
	print("[PASS] Tail shrunk again! Final length: %d (just head)" % engine.snake.size())
	if engine.snake.size() != 1:
		push_error("FAILED: Tail must return to length 1 after delivering all fruits!")
		quit(1)
		return
		
	# 4. TEST FILTERED DELIVERY (Red vs Blue)
	print("\n[TEST] Testing mixed cargo (Apple R and Plum B) at Red Crate...")
	engine.snake.append({ "pos": Vector2i(0, 0), "layer": 0, "fruit_type": "R" })
	engine.snake.append({ "pos": Vector2i(0, 1), "layer": 0, "fruit_type": "B" })
	print("       Snake holding: 1 Apple (R) and 1 Plum (B). Length: %d" % engine.snake.size())
	
	active_crate["capacity"] = 10
	active_crate["filled"] = 0
	active_crate["fruit"] = "R" # Red crate only accepts R!
	engine.active_crate_idx = 0
	
	engine.process_crate_delivery(dock_pos)
	print("       Delivered to Red crate. New length: %d" % engine.snake.size())
	if engine.snake.size() != 2:
		push_error("FAILED: Only Red fruit should be delivered, leaving Blue Plum in wagon!")
		quit(1)
		return
		
	print("[PASS] Red apple delivered! Blue plum remains in wagon: %s" % engine.snake[1]["fruit_type"])
	if engine.snake[1]["fruit_type"] != "B":
		push_error("FAILED: Remaining fruit must be B (Plum)!")
		quit(1)
		return
		
	print("\n===========================================================")
	print(" >>> ALL DYNAMIC TAIL INVENTORY TESTS PASSED CLEANLY! <<<  ")
	print("===========================================================\n")
	quit(0)
