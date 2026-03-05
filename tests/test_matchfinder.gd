extends Node

func _ready():
	print("[TEST] test_matchfinder _ready() starting")
	# Simple grid with a horizontal match on row 0
	var grid = []
	var w = 5
	var h = 5
	for x in range(w):
		grid.append([])
		for y in range(h):
			grid[x].append(1 if x < 3 else 2)

	var matches = MatchFinder.find_matches(grid, w, h, 3)
	assert(matches.size() >= 3)
	print("[TEST] test_matchfinder passed: matches=", matches)
	get_tree().quit()
