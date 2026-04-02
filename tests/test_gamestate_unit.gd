extends Node

var GS = null

func _to_key(v: Vector2) -> String:
	return str(int(v.x)) + "," + str(int(v.y))

func _to_set(arr: Array) -> Array:
	var s = []
	for v in arr:
		s.append(_to_key(v))
	return s

func _ready():
	GS = load("res://meta/profile/GameState.gd").new(3, 3, 6)
	print("[TEST] test_gamestate_unit starting")

	# Case 1: create_empty_grid
	GS.create_empty_grid(4, 4)
	assert(GS.grid.size() == 4)
	assert(GS.grid[0].size() == 4)
	# All cells should be integers (0 or -1)
	for x in range(4):
		for y in range(4):
			assert(typeof(GS.grid[x][y]) == TYPE_INT)
	print("[TEST] Case 1 passed: create_empty_grid ok")

	# Case 2: fill_from_layout handles tokens X, C, S, Hn:type and numbers
	var layout = []
	# build columns
	for x in range(3):
		layout.append([])
		for y in range(3):
			layout[x].append(0)

	# row 0
	layout[0][0] = "1"
	layout[1][0] = "X"
	layout[2][0] = "C"
	# row 1
	layout[0][1] = "H2:rock"
	layout[1][1] = "S"
	layout[2][1] = "0"
	# row 2
	layout[0][2] = "2"
	layout[1][2] = "3"
	layout[2][2] = "0"

	var result = GS.fill_from_layout(layout)
	# result is a dictionary with keys grid, collectible_positions, unmovable_map, spreader_positions, spreader_count
	assert(result.has("grid"))
	assert(result.has("collectible_positions"))
	assert(result.has("unmovable_map"))
	assert(result.has("spreader_positions"))
	assert(result["grid"][2][0] == GS.COLLECTIBLE)
	# collectible_positions should include (2,0)
	var cset = _to_set(result["collectible_positions"])
	assert("2,0" in cset)
	# spreader at (1,1)
	var sset = _to_set(result["spreader_positions"])
	assert("1,1" in sset)
	# unmovable_map should have key for H2:rock at (0,1)
	var key = str(0) + "," + str(1)
	assert(result["unmovable_map"].has(key))
	print("[TEST] Case 2 passed: fill_from_layout token parsing ok")

	# Case 3: would_create_initial_match horizontal
	GS.create_empty_grid(5,5)
	# set two left neighbors identical at (0,0)=1 and (1,0)=1
	GS.grid[0][0] = 1
	GS.grid[1][0] = 1
	# should create match if placing 1 at (2,0)
	assert(GS.would_create_initial_match(2, 0, 1) == true)
	# vertical test
	GS.create_empty_grid(5,5)
	GS.grid[0][0] = 2
	GS.grid[0][1] = 2
	assert(GS.would_create_initial_match(0, 2, 2) == true)
	print("[TEST] Case 3 passed: would_create_initial_match ok")

	print("[TEST] All GameState unit tests passed")
	get_tree().quit()
