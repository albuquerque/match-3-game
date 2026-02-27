extends Node

func _ready():
	print("[TEST] test_spreader_service starting")
	var Spreader = load("res://scripts/game/SpreaderService.gd")
	assert(Spreader != null)

	# Create a 5x5 grid filled with type 1
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

	# Run spread with limit 2
	var res = Spreader.spread(spreader_positions, grid, w, h, 2, "virus")
	assert(typeof(res) == TYPE_DICTIONARY)
	assert(res.has("new_spreaders"))
	assert(res.has("grid"))

	var new_list = res["new_spreaders"]
	var new_grid = res["grid"]

	print("[TEST] SpreaderService returned new_spreaders=", new_list)
	# Should create exactly 2 new spreaders when limit=2
	assert(new_list.size() == 2)

	# Verify grid positions were converted to 12
	for np in new_list:
		var x = int(np.x)
		var y = int(np.y)
		assert(new_grid[x][y] == 12)

	print("[TEST] test_spreader_service passed")
	get_tree().quit()
