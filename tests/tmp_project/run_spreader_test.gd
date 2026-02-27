extends Node

func _ready():
	print("[TMP TEST] run_spreader_test starting")
	# Load SpreaderService using relative path to repository
	var Spreader = load("res://../scripts/game/SpreaderService.gd")
	if Spreader == null:
		printerr("[TMP TEST] Failed to load SpreaderService from res://../scripts/game/SpreaderService.gd")
		get_tree().quit()
		return

	# Prepare a small grid
	var w = 5
	var h = 5
	var grid = []
	for x in range(w):
		var col = []
		for y in range(h):
			col.append(1)
		grid.append(col)

	# Place a spreader at center
	grid[2][2] = 12
	var spreader_positions = [Vector2(2,2)]

	var res = Spreader.spread(spreader_positions, grid, w, h, 2, "virus")
	print("[TMP TEST] spread result: ", res)
	if typeof(res) != TYPE_DICTIONARY:
		printerr("[TMP TEST] Unexpected result type")
		get_tree().quit()
		return

	var new_list = res["new_spreaders"]
	assert(new_list.size() == 2)
	for np in new_list:
		assert(grid[int(np.x)][int(np.y)] == 12)

	print("[TMP TEST] run_spreader_test passed")
	get_tree().quit()
