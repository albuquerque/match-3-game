extends Node

signal score_changed(new_score)
signal level_changed(new_level)
signal moves_changed(moves_left)
signal game_over
signal level_complete
signal level_loaded

# Game configuration
var GRID_WIDTH = 8
var GRID_HEIGHT = 8
const TILE_TYPES = 6
const MIN_MATCH_SIZE = 3
const HORIZTONAL_ARROW = 7
const VERTICAL_ARROW = 8
const FOUR_WAY_ARROW = 9

# Scoring
const POINTS_PER_TILE = 100
const COMBO_MULTIPLIER = 1.5

# Game state
var score = 0
var level = 1
var moves_left = 30
var target_score = 10000
var grid = []
var combo_count = 0
var processing_moves = false

# Level system
var level_manager: Node = null

# Add a flag to prevent multiple triggers of level completion
var level_transitioning = false

# Level completion state
var last_level_won = false
var last_level_score = 0
var last_level_target = 0
var last_level_number = 0
var last_level_moves_left = 0

# Add a flag to request level completion when score threshold is reached but animations are still running
var pending_level_complete = false

# Debugging
var DEBUG_LOGGING = true

func _ready():
	# Get or create LevelManager
	level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager:
		level_manager = preload("res://scripts/LevelManager.gd").new()
		level_manager.name = "LevelManager"
		add_child(level_manager)

	initialize_game()

func initialize_game():
	score = 0
	level = 3
	combo_count = 0
	processing_moves = false
	level_transitioning = false

	# Load the first level
	load_current_level()

	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	emit_signal("moves_changed", moves_left)

func load_current_level():
	"""Load the current level from LevelManager"""
	processing_moves = false  # Reset the processing flag when loading a level
	score = 0  # Reset score for the new level
	combo_count = 0  # Reset combo count

	var level_data = level_manager.get_current_level()

	if level_data:
		GRID_WIDTH = level_data.width
		GRID_HEIGHT = level_data.height
		target_score = level_data.target_score
		moves_left = level_data.moves
		level = level_data.level_number

		create_empty_grid()
		fill_grid_from_layout(level_data.grid_layout)

		print("Loaded level ", level, ": ", level_data.description)
		print("Grid size: ", GRID_WIDTH, "x", GRID_HEIGHT)
		print("Target: ", target_score, " in ", moves_left, " moves")
	else:
		# Fallback to default grid
		print("No level data found, using default grid")
		GRID_WIDTH = 8
		GRID_HEIGHT = 8
		target_score = 10000
		moves_left = 30
		create_empty_grid()
		fill_initial_grid()

	emit_signal("level_loaded")

func create_empty_grid():
	grid.clear()
	for x in range(GRID_WIDTH):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(0)

func fill_grid_from_layout(layout: Array):
	"""Fill the grid based on level layout (-1 = blocked, 0 = random tile)"""
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_value = layout[x][y]

			if cell_value == -1:
				# Blocked cell - stays as -1
				grid[x][y] = -1
			elif cell_value == 0:
				# Empty - fill with random tile
				var tile_type = get_safe_random_tile(x, y)
				grid[x][y] = tile_type
			else:
				# Specific tile type
				grid[x][y] = cell_value

func fill_initial_grid():
	"""Legacy method for backward compatibility"""
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] != -1:  # Don't fill blocked cells
				var tile_type = get_safe_random_tile(x, y)
				grid[x][y] = tile_type

func get_safe_random_tile(x: int, y: int) -> int:
	# Skip if cell is blocked
	if is_cell_blocked(x, y):
		return -1

	var attempts = 0
	while attempts < 50:
		var tile_type = randi() % TILE_TYPES + 1
		if not would_create_initial_match(x, y, tile_type):
			return tile_type
		attempts += 1
	return 1  # Fallback

func would_create_initial_match(x: int, y: int, tile_type: int) -> bool:
	# Check horizontal
	var h_count = 1
	var check_x = x - 1
	while check_x >= 0 and grid[check_x][y] == tile_type:
		h_count += 1
		check_x -= 1

	# Check vertical
	var v_count = 1
	var check_y = y - 1
	while check_y >= 0 and grid[x][check_y] == tile_type:
		v_count += 1
		check_y -= 1

	return h_count >= MIN_MATCH_SIZE or v_count >= MIN_MATCH_SIZE

func is_cell_blocked(x: int, y: int) -> bool:
	"""Check if a cell is blocked"""
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT:
		return true

	return grid[x][y] == -1

func is_valid_position(pos: Vector2) -> bool:
	if pos.x < 0 or pos.x >= GRID_WIDTH or pos.y < 0 or pos.y >= GRID_HEIGHT:
		return false

	# Check if the cell is blocked
	return not is_cell_blocked(int(pos.x), int(pos.y))

func are_adjacent(pos1: Vector2, pos2: Vector2) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx == 1 and dy == 0) or (dx == 0 and dy == 1)

func can_swap(pos1: Vector2, pos2: Vector2) -> bool:
	if not is_valid_position(pos1) or not is_valid_position(pos2):
		return false
	return are_adjacent(pos1, pos2)

func swap_tiles(pos1: Vector2, pos2: Vector2) -> bool:
	if not can_swap(pos1, pos2):
		return false

	var temp = grid[pos1.x][pos1.y]
	grid[pos1.x][pos1.y] = grid[pos2.x][pos2.y]
	grid[pos2.x][pos2.y] = temp
	return true

func find_matches() -> Array:
	var matches = []

	# Find horizontal matches
	for y in range(GRID_HEIGHT):
		var current_type = grid[0][y]
		var match_start = 0

		for x in range(1, GRID_WIDTH + 1):
			var tile_type = grid[x][y] if x < GRID_WIDTH else -1

			# Skip blocked cells
			if x < GRID_WIDTH and is_cell_blocked(x, y):
				tile_type = -2  # Use -2 to break the match

			if tile_type != current_type or x == GRID_WIDTH:
				if x - match_start >= MIN_MATCH_SIZE and current_type > 0 and current_type < 7:
					for i in range(match_start, x):
						if not is_cell_blocked(i, y):
							matches.append(Vector2(i, y))
				current_type = tile_type
				match_start = x

	# Find vertical matches
	for x in range(GRID_WIDTH):
		var current_type = grid[x][0]
		var match_start = 0

		for y in range(1, GRID_HEIGHT + 1):
			var tile_type = grid[x][y] if y < GRID_HEIGHT else -1

			# Skip blocked cells
			if y < GRID_HEIGHT and is_cell_blocked(x, y):
				tile_type = -2  # Use -2 to break the match

			if tile_type != current_type or y == GRID_HEIGHT:
				if y - match_start >= MIN_MATCH_SIZE and current_type > 0 and current_type < 7:
					for i in range(match_start, y):
						if not is_cell_blocked(x, i):
							matches.append(Vector2(x, i))
				current_type = tile_type
				match_start = y
	if DEBUG_LOGGING:
		print("find_matches: END — grid snapshot after gravity:")
		for x in range(GRID_WIDTH):
			var col = []
			for y in range(GRID_HEIGHT):
				col.append(grid[x][y])
			print("col[", x, "] = ", col)
		print("find_matches = ", matches)
	return remove_duplicates(matches)

func remove_duplicates(matches: Array) -> Array:
	var unique_matches = []
	for match in matches:
		if not match in unique_matches:
			unique_matches.append(match)
	return unique_matches

func remove_matches(matches: Array, swapped_pos: Vector2 = Vector2(-1, -1)) -> int:
	matches = matches.filter(func(pos): return not is_cell_blocked(pos.x, pos.y))
	var tiles_removed = 0
	var horizontal = false
	var vertical = false

	# Only create special tiles if we have a valid swapped position
	var create_special = swapped_pos.x >= 0 and swapped_pos.y >= 0

	# Determine match directions (only if creating special tiles)
	var matches_on_same_row = 0
	var matches_on_same_col = 0

	if create_special:
		# Check if there are multiple matches on the same row (horizontal match)
		for match_pos in matches:
			if match_pos.y == swapped_pos.y:
				matches_on_same_row += 1

		# Check if there are multiple matches on the same column (vertical match)
		for match_pos in matches:
			if match_pos.x == swapped_pos.x:
				matches_on_same_col += 1

		# Detect horizontal and vertical matches (3+ tiles for T/L shapes, 4+ for directional arrows)
		horizontal = matches_on_same_row >= 3
		vertical = matches_on_same_col >= 3

	# Determine which special tile to create (before removing tiles)
	var special_tile_type = 0
	if create_special:
		if horizontal and vertical:
			# Both horizontal and vertical matches (T or L shape) - create 4-way arrow
			special_tile_type = FOUR_WAY_ARROW
		elif horizontal and matches_on_same_row >= 4:
			# Only horizontal match of 4+ tiles - create horizontal arrow
			special_tile_type = HORIZTONAL_ARROW
		elif vertical and matches_on_same_col >= 4:
			# Only vertical match of 4+ tiles - create vertical arrow
			special_tile_type = VERTICAL_ARROW

	# Remove matched tiles (but preserve swapped position if creating special tile)
	for match_pos in matches:
		if is_cell_blocked(match_pos.x, match_pos.y):
			continue  # Never remove blocked cells
		if grid[match_pos.x][match_pos.y] > 0:
			# Skip the swapped position if we're creating a special tile there
			if special_tile_type > 0 and match_pos.x == swapped_pos.x and match_pos.y == swapped_pos.y:
				continue
			grid[match_pos.x][match_pos.y] = 0
			tiles_removed += 1

	# Create special tile at swapped position if applicable
	if special_tile_type > 0 and not is_cell_blocked(swapped_pos.x, swapped_pos.y):
		grid[swapped_pos.x][swapped_pos.y] = special_tile_type

	var points = calculate_points(tiles_removed)
	add_score(points)
	combo_count += 1

	return tiles_removed

func activate_special_tile(pos: Vector2):
	var tile_type = grid[pos.x][pos.y]
	if tile_type == HORIZTONAL_ARROW:
		for x in range(GRID_WIDTH):
			if not is_cell_blocked(x, int(pos.y)):
				grid[x][pos.y] = 0
	elif tile_type == VERTICAL_ARROW:
		for y in range(GRID_HEIGHT):
			if not is_cell_blocked(int(pos.x), y):
				grid[pos.x][y] = 0
	elif tile_type == FOUR_WAY_ARROW:
		for x in range(GRID_WIDTH):
			if not is_cell_blocked(x, int(pos.y)):
				grid[x][pos.y] = 0
		for y in range(GRID_HEIGHT):
			if not is_cell_blocked(int(pos.x), y):
				grid[pos.x][y] = 0

func calculate_points(tiles_removed: int) -> int:
	var base_points = tiles_removed * POINTS_PER_TILE
	var combo_bonus = pow(COMBO_MULTIPLIER, combo_count - 1)
	return int(base_points * combo_bonus)

func apply_gravity() -> bool:
	var moved = false

	if DEBUG_LOGGING:
		print("apply_gravity: START — grid snapshot before gravity:")
		for x in range(GRID_WIDTH):
			var col = []
			for y in range(GRID_HEIGHT):
				col.append(grid[x][y])
			print("col[", x, "] = ", col)

	for x in range(GRID_WIDTH):
		# Start from the bottom and work upward
		var write_pos = GRID_HEIGHT - 1

		# Find the lowest available (non-blocked) position
		while write_pos >= 0 and is_cell_blocked(x, write_pos):
			write_pos -= 1

		if write_pos < 0:
			continue  # Entire column blocked

		# Scan from bottom to top, moving tiles down to fill gaps
		for read_pos in range(GRID_HEIGHT - 1, -1, -1):
			# Skip blocked cells
			if is_cell_blocked(x, read_pos):
				continue

			# If we find a tile
			var tile = grid[x][read_pos]
			if tile > 0:
				if read_pos != write_pos:
					grid[x][write_pos] = tile
					grid[x][read_pos] = 0
					moved = true

				# Move write position up for next tile
				write_pos -= 1

				# Skip any blocked cells in write position
				while write_pos >= 0 and is_cell_blocked(x, write_pos):
					write_pos -= 1

	if DEBUG_LOGGING:
		print("apply_gravity: END — grid snapshot after gravity:")
		for x in range(GRID_WIDTH):
			var col = []
			for y in range(GRID_HEIGHT):
				col.append(grid[x][y])
			print("col[", x, "] = ", col)
		print("apply_gravity: moved = ", moved)

	return moved

func fill_empty_spaces() -> Array:
	var new_tiles = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if is_cell_blocked(x, y):
				continue  # Skip blocked cells

			if grid[x][y] == 0:
				grid[x][y] = randi_range(1, TILE_TYPES)
				new_tiles.append(Vector2(x, y))

	return new_tiles

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)

	if score >= target_score and not level_transitioning:
		# Store level completion state
		last_level_won = true
		last_level_score = score
		last_level_target = target_score
		last_level_number = level
		last_level_moves_left = moves_left

		# Mark that a level completion should occur, but defer until board activity stops
		if not pending_level_complete:
			pending_level_complete = true
			# Start the coroutine that will wait for ongoing activity to finish before advancing
			_attempt_level_complete()

func advance_level():
	# Try to advance to next level
	if level_manager.advance_to_next_level():
		level += 1
		combo_count = 0

		# Trigger level completion and transition to LevelProgressScene
		on_level_complete()
	else:
		# No more levels - game complete!
		print("All levels completed!")
		last_level_won = true
		last_level_score = score
		last_level_target = target_score
		last_level_number = level
		last_level_moves_left = moves_left
		on_level_complete()

func use_move():
	moves_left -= 1
	emit_signal("moves_changed", moves_left)

	if moves_left <= 0 and score < target_score and not level_transitioning:
		# Store level failure state
		last_level_won = false
		last_level_score = score
		last_level_target = target_score
		last_level_number = level
		last_level_moves_left = 0
		emit_signal("game_over")
		# Transition to results screen
		on_level_failed()

func reset_combo():
	combo_count = 0

func get_tile_at(pos: Vector2) -> int:
	if is_valid_position(pos):
		return grid[int(pos.x)][int(pos.y)]
	return -1

func has_possible_moves() -> bool:
	"""Check if there are any valid moves available on the board"""
	# First check if there are any special tiles - they're always valid moves
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not is_cell_blocked(x, y):
				var tile_type = grid[x][y]
				if tile_type >= 7 and tile_type <= 9:
					print("Special tile found at (", x, ", ", y, ") - valid move exists")
					return true

	# Check for regular match-creating moves
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if is_cell_blocked(x, y) or grid[x][y] <= 0:
				continue

			var pos = Vector2(x, y)

			# Check right swap
			if x < GRID_WIDTH - 1 and not is_cell_blocked(x + 1, y):
				var right_pos = Vector2(x + 1, y)
				if would_create_match_after_swap(pos, right_pos):
					return true

			# Check down swap
			if y < GRID_HEIGHT - 1 and not is_cell_blocked(x, y + 1):
				var down_pos = Vector2(x, y + 1)
				if would_create_match_after_swap(pos, down_pos):
					return true

	return false

func shuffle_board():
	"""Shuffle all non-blocked tiles on the board"""
	print("Shuffling board...")

	# Collect all non-blocked, non-special tile values
	var tile_values = []
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not is_cell_blocked(x, y) and grid[x][y] > 0 and grid[x][y] < 7:
				tile_values.append(grid[x][y])

	# Shuffle the values
	tile_values.shuffle()

	# Redistribute the shuffled values (keep special tiles in place)
	var index = 0
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if not is_cell_blocked(x, y) and grid[x][y] > 0 and grid[x][y] < 7:
				grid[x][y] = tile_values[index]
				index += 1

	print("Board shuffled")

func has_immediate_matches() -> bool:
	"""Check if the current board has any matches without any moves"""
	var matches = find_matches()
	return matches.size() > 0

func shuffle_until_moves_available() -> bool:
	"""Shuffle the board until valid moves are available and no immediate matches exist"""
	var max_attempts = 100
	var attempts = 0

	while attempts < max_attempts:
		shuffle_board()
		attempts += 1

		# Check if shuffle created immediate matches - if so, reshuffle
		if has_immediate_matches():
			print("Shuffle created matches, reshuffling... (attempt ", attempts, ")")
			continue

		# Check if valid moves exist
		if has_possible_moves():
			print("Valid moves found after ", attempts, " shuffle(s)")
			return true

		print("No valid moves after shuffle attempt ", attempts)

	print("WARNING: Could not find valid moves after ", max_attempts, " attempts")
	return false

func would_create_match_after_swap(pos1: Vector2, pos2: Vector2) -> bool:
	# Temporarily swap
	swap_tiles(pos1, pos2)

	# Check for matches
	var matches = find_matches()
	var has_match = matches.size() > 0

	# Swap back
	swap_tiles(pos1, pos2)

	return has_match

func _attempt_level_complete():
	# Wait until no board activity (swaps/cascades/refills) are in progress
	# If another transition is already in progress, cancel
	if level_transitioning:
		pending_level_complete = false
		return

	# Poll until processing_moves is false, yielding small delays to avoid blocking
	while processing_moves:
		await get_tree().create_timer(0.1).timeout
		# If a transition began while waiting, abort
		if level_transitioning:
			pending_level_complete = false
			return

	# Give a short extra buffer so any last deferred callbacks/tweens complete
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	# Clear pending flag and advance level now that the board is idle
	pending_level_complete = false
	advance_level()

func on_level_failed():
	if level_transitioning:
		return

	level_transitioning = true

	# Wait for any board activity to finish before transitioning
	while processing_moves:
		if get_tree() == null:
			break
		await get_tree().create_timer(0.1).timeout

	# Short buffer to allow final tweens/deferred calls to complete
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	print("Level failed, transitioning to LevelProgressScene...")
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/LevelProgressScene.tscn")

	level_transitioning = false

func on_level_complete():
	if level_transitioning:
		return

	level_transitioning = true

	# Ensure LevelManager is initialized before transitioning
	if not level_manager or level_manager.levels.size() == 0:
		print("Waiting for LevelManager to initialize...")
		if get_tree() != null:
			await get_tree().create_timer(0.1).timeout
		on_level_complete()
		return

	# Wait for any ongoing board activity to finish before changing scene
	while processing_moves:
		if get_tree() == null:
			break
		await get_tree().create_timer(0.1).timeout

	# Small buffer to ensure tweens/deferred callbacks finish
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	print("Transitioning to LevelProgressScene...")
	if get_tree() != null:
		get_tree().change_scene_to_file("res://scenes/LevelProgressScene.tscn")

	level_transitioning = false
