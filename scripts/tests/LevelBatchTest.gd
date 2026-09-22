extends SceneTree

func _init() -> void:
	var directory := DirAccess.open("res://levels")
	if directory == null:
		print("No levels directory found.")
		quit(1)
		return
	var passed := 0
	var total := 0
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while file_name != "":
		if not directory.current_is_dir() and file_name.ends_with(".tres"):
			total += 1
			var data = load("res://levels/" + file_name)
			var valid := data is LevelData and LevelValidator.is_valid(data)
			var solved := false
			var message := "invalid"
			if valid:
				var result := LevelSolver.solve(data)
				solved = result["solvable"]
				message = result["message"]
			if valid and solved:
				passed += 1
			print("%s: %s (%s)" % [file_name, "PASS" if valid and solved else "FAIL", message])
		file_name = directory.get_next()
	directory.list_dir_end()
	print("Level batch: %d/%d passed" % [passed, total])
	quit(0 if passed == total else 1)