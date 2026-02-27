extends SceneTree

func _init():
	print("Running MatchFinder tests...")
	var MF = load("res://scripts/services/MatchFinder.gd")
	var passed = 0
	var failed = 0

	# Test 1: simple horizontal
	var grid = []
	for x in range(5):
		grid.append([0,0,0,0,0])
	grid[0][2] = 1
	grid[1][2] = 1
	grid[2][2] = 1
	var res = MF.find_matches(grid, 5, 5)
	if res.size() == 3:
		print("Test1 passed")
		passed += 1
	else:
		print("Test1 failed: ", res)
		failed += 1

	# Test 2: overlapping horizontal and vertical (T-shape)
	grid = []
	for x in range(5):
		grid.append([0,0,0,0,0])
	grid[1][1] = 2
	grid[2][1] = 2
	grid[3][1] = 2
	grid[2][0] = 2
	grid[2][2] = 2
	res = MF.find_matches(grid, 5, 5)
	# expecting five positions
	if res.size() == 5:
		print("Test2 passed")
		passed += 1
	else:
		print("Test2 failed: ", res)
		failed += 1

	# Test3: vertical line
	grid = []
	for x in range(4):
		grid.append([0,0,0,0])
	grid[1][0] = 3
	grid[1][1] = 3
	grid[1][2] = 3
	grid[1][3] = 3
	res = MF.find_matches(grid, 4, 4)
	if res.size() == 4:
		print("Test3 passed")
		passed += 1
	else:
		print("Test3 failed: ", res)
		failed += 1

	print("MatchFinder tests complete - passed:", passed, " failed:", failed)
	# Quit the game loop
	self.quit()
