extends Node

var MF = null

# Unit tests for MatchFinder.find_matches
# Runs several scenarios and asserts expected returned positions.

func _to_key(v: Vector2) -> String:
	return str(int(v.x)) + "," + str(int(v.y))

func _to_set(arr: Array) -> Array:
	var s = []
	for v in arr:
		s.append(_to_key(v))
	return s

func _contains_all(set_arr: Array, expected: Array) -> bool:
	for e in expected:
		if not e in set_arr:
			return false
	return true

func _ready():
	MF = load("res://games/match3/board/services/MatchFinder.gd").new()
	print("[TEST] test_matchfinder_unit starting")
	# Case 1: horizontal match on row 0 at x=0..2
	var w = 5
	var h = 5
	var grid = []
	for x in range(w):
		grid.append([])
		for y in range(h):
			if y == 0:
				grid[x].append(1 if x < 3 else 2)
			else:
				grid[x].append(2)

	var res = MF.find_matches_instance(grid, w, h, 3, [10,12], -1)
	var s = _to_set(res)
	var expected = ["0,0", "1,0", "2,0"]
	assert(s.size() >= expected.size())
	assert(_contains_all(s, expected))
	print("[TEST] Case 1 passed")

	# Case 2: vertical match on column 1 at y=1..3
	grid = []
	for x in range(w):
		grid.append([])
		for y in range(h):
			if x == 1:
				grid[x].append(3 if y >= 1 and y <= 3 else 2)
			else:
				grid[x].append(2)

	res = MF.find_matches_instance(grid, w, h, 3, [10,12], -1)
	s = _to_set(res)
	expected = ["1,1", "1,2", "1,3"]
	assert(_contains_all(s, expected))
	print("[TEST] Case 2 passed")

	# Case 3: blocked cell breaks a potential match
	# Row 2 would have 3 tiles but a blocked (-1) in middle prevents matching
	grid = []
	for x in range(5):
		grid.append([])
		for y in range(5):
			grid[x].append(1)
	# Block position 1,2
	grid[1][2] = -1
	# Now horizontal run at y=2 is split; no 3-match
	res = MF.find_matches_instance(grid, 5, 5, 3, [], -1)
	s = _to_set(res)
	# Ensure that none of the blocked-run positions are reported as a 3-match
	assert(not "0,2" in s and not "1,2" in s and not "2,2" in s)
	print("[TEST] Case 3 passed")

	# Case 4: excluded values (collectible/spreader) should not be matched
	# Create 3 same tiles but middle is COLLECTIBLE (10)
	grid = []
	for x in range(5):
		grid.append([])
		for y in range(5):
			grid[x].append(2)
	grid[0][0] = 4
	grid[1][0] = 10  # collectible - should exclude
	grid[2][0] = 4

	res = MF.find_matches_instance(grid, 5, 5, 3, [10,12], -1)
	s = _to_set(res)
	# There should be no 3-match reported because the middle tile is excluded
	assert(not "0,0" in s and not "1,0" in s and not "2,0" in s)
	print("[TEST] Case 4 passed")

	# Case 5: T-shape (both horizontal and vertical). Expect union of positions.
	# Grid: vertical at x=2 y=0..3; horizontal at y=1 x=1..3 (forms T at 2,1)
	grid = []
	for x in range(5):
		grid.append([])
		for y in range(5):
			grid[x].append(2)
	# vertical
	grid[2][0] = 5
	grid[2][1] = 5
	grid[2][2] = 5
	grid[2][3] = 5
	# horizontal crossing at y=1
	grid[1][1] = 5
	grid[3][1] = 5

	res = MF.find_matches_instance(grid, 5, 5, 3, [], -1)
	s = _to_set(res)
	expected = ["2,0","2,1","2,2","1,1","3,1","2,3"]
	assert(_contains_all(s, expected))
	print("[TEST] Case 5 passed")

	print("[TEST] All MatchFinder unit tests passed")
	get_tree().quit()
