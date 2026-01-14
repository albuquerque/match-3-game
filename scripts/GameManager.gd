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

# Theme system
var theme_manager: Node = null

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

# Add a flag to request level failure when moves reach zero but cascades are still in progress
var pending_level_failed = false

# Debugging
var DEBUG_LOGGING = true

# Flag to check if the game manager has been initialized
var initialized = false

func _ready():
	print("[GameManager] _ready() - initializing")
	# Get the autoloaded LevelManager
	level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager:
		print("[GameManager] WARNING: LevelManager not found as autoload!")

	# Get the autoloaded ThemeManager
	theme_manager = get_node_or_null("/root/ThemeManager")
	if not theme_manager:
		print("[GameManager] WARNING: ThemeManager not found as autoload!")

	# Do NOT auto-initialize the game here. The UI will present a StartPage and call initialize_game() when the
	# player explicitly starts the level
	# initialize_game()

func initialize_game():
	score = 0
	# Don't hardcode level - let load_current_level() set it from LevelManager
	combo_count = 0
	processing_moves = false
	level_transitioning = false
	# Do NOT set initialized here; set it after a level is actually loaded in load_current_level()

	print("[GameManager] initialize_game() - current score=", score, ", moves_left=", moves_left)

	# Load the first level and wait for it to finish so callers can rely on initialized
	await load_current_level()

	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	emit_signal("moves_changed", moves_left)

	print("[GameManager] ✓ initialize_game() completed, initialized =", initialized, ", grid size =", grid.size())

func load_current_level():
	"""Load the current level from LevelManager"""
	processing_moves = false  # Reset the processing flag when loading a level
	score = 0  # Reset score for the new level
	combo_count = 0  # Reset combo count

	print("[GameManager] load_current_level() - loading level data")

	# Ensure LevelManager is available and has loaded levels (wait briefly if needed)
	if not level_manager or (level_manager and level_manager.levels.size() == 0):
		print("[GameManager] LevelManager not ready yet - waiting up to 2s for levels to load")
		var attempts = 0
		var max_attempts = 40  # 40 * 0.05s = 2s
		while (not level_manager or level_manager.levels.size() == 0) and attempts < max_attempts:
			level_manager = get_node_or_null("/root/LevelManager")
			await get_tree().create_timer(0.05).timeout
			attempts += 1
		if attempts >= max_attempts:
			print("[GameManager] Waited 2s but LevelManager did not become ready")

	if not level_manager:
		print("[GameManager] ERROR: LevelManager still not available after waiting; using fallback default level")

	var level_data = null
	if level_manager:
		level_data = level_manager.get_current_level()

	if level_data:
		print("[GameManager] Found level_data: level=", level_data.level_number)
		print("[GameManager]   width=", level_data.width, ", height=", level_data.height)
		print("[GameManager]   target_score=", level_data.target_score)
		print("[GameManager]   moves=", level_data.moves)
		print("[GameManager]   theme='", level_data.theme, "'")
		print("[GameManager]   description='", level_data.description, "'")

		GRID_WIDTH = level_data.width
		GRID_HEIGHT = level_data.height
		target_score = level_data.target_score
		moves_left = level_data.moves
		level = level_data.level_number

		# Set theme if specified in level data
		if theme_manager:
			if level_data.theme != "" and level_data.theme != null:
				theme_manager.set_theme_by_name(level_data.theme)
				print("[GameManager] Applied theme from JSON: ", level_data.theme)
			else:
				# Default: use legacy for odd levels, modern for even levels
				if level % 2 == 1:
					theme_manager.set_theme_by_name("legacy")
				else:
					theme_manager.set_theme_by_name("modern")
				print("[GameManager] Applied default theme for level ", level, ": ", "legacy" if level % 2 == 1 else "modern")

		create_empty_grid()
		fill_grid_from_layout(level_data.grid_layout)

		print("Loaded level ", level, ": ", level_data.description)
		print("Grid size: ", GRID_WIDTH, "x", GRID_HEIGHT)
		print("Target: ", target_score, " in ", moves_left, " moves")
		initialized = true
		print("[GameManager] ✓ Level loaded successfully, initialized = true")

		# Debug: print a small snapshot of the grid to help UI select tiles
		print("[GameManager] Grid snapshot after load:")
		for y in range(GRID_HEIGHT):
			var row = []
			for x in range(GRID_WIDTH):
				row.append(grid[x][y])
			print(row)
	else:
		# Fallback to default grid
		print("No level data found, using default grid")
		GRID_WIDTH = 8
		GRID_HEIGHT = 8
		target_score = 10000
		moves_left = 30
		if theme_manager:
			theme_manager.set_theme_by_name("modern")
		create_empty_grid()
		fill_initial_grid()
		initialized = true

		# Debug: print a small snapshot of the fallback grid
		print("[GameManager] Fallback grid snapshot:")
		for y in range(GRID_HEIGHT):
			var row = []
			for x in range(GRID_WIDTH):
				row.append(grid[x][y])
			print(row)

	emit_signal("level_loaded")
	print("[GameManager] ✓ load_current_level() completed, initialized =", initialized)

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

	# Check if grid is properly initialized
	if grid.size() <= x:
		return true
	if grid[x].size() <= y:
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
	print("[FIND_MATCHES] Starting search...")

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
					print("[FIND_MATCHES] Horizontal match found: y=", y, ", x from ", match_start, " to ", x-1, ", type=", current_type)
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
					print("[FIND_MATCHES] Vertical match found: x=", x, ", y from ", match_start, " to ", y-1, ", type=", current_type)
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
	print("[SCORING] ========== remove_matches called ==========")
	print("[SCORING] Input matches count: ", matches.size())
	print("[SCORING] Swapped position: ", swapped_pos)
	print("[SCORING] Current combo_count: ", combo_count)

	# Log what's actually at each match position
	for i in range(min(matches.size(), 10)):  # Limit to first 10 to avoid spam
		var pos = matches[i]
		var val = grid[int(pos.x)][int(pos.y)] if is_valid_position(pos) else -999
		print("[SCORING]   Match[", i, "]: pos=", pos, " grid_value=", val, " blocked=", is_cell_blocked(pos.x, pos.y))

	# Filter out any blocked cells from matches
	matches = matches.filter(func(pos): return not is_cell_blocked(pos.x, pos.y))
	print("[SCORING] After filtering blocked: ", matches.size(), " matches")

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
		print("remove_matches: create_special true, swapped_pos=", swapped_pos)
		print("remove_matches: initial matches count=", matches.size())
		print("remove_matches: computed matches_on_same_row=", matches_on_same_row, " matches_on_same_col=", matches_on_same_col)
		if horizontal and vertical:
			# Both horizontal and vertical matches (T or L shape) - create 4-way arrow
			special_tile_type = FOUR_WAY_ARROW
		elif horizontal and matches_on_same_row >= 4:
			# Only horizontal match of 4+ tiles - create horizontal arrow
			special_tile_type = HORIZTONAL_ARROW
		elif vertical and matches_on_same_col >= 4:
			# Only vertical match of 4+ tiles - create vertical arrow
			special_tile_type = VERTICAL_ARROW

		print("remove_matches: special_tile_type after basic checks =", special_tile_type)

		# If nothing selected but there exists a 4+ line or T/L anywhere in the matches,
		# pick a valid position from the matches to create the special tile.
		if special_tile_type == 0:
			print("remove_matches: special_tile_type == 0, scanning matches for fallback special")
			# Scan matches for T/L or 4+ lines
			for test_pos in matches:
				var row_count = 0
				var col_count = 0
				for mpos in matches:
					if mpos.y == test_pos.y:
						row_count += 1
					if mpos.x == test_pos.x:
						col_count += 1
				# T/L shape
				if row_count >= 3 and col_count >= 3:
					special_tile_type = FOUR_WAY_ARROW
					swapped_pos = test_pos
					print("remove_matches: found T/L fallback at ", test_pos)
					break
				# 4+ horizontal
				if row_count >= 4:
					special_tile_type = HORIZTONAL_ARROW
					swapped_pos = test_pos
					print("remove_matches: found 4+ horizontal fallback at ", test_pos)
					break
				# 4+ vertical
				if col_count >= 4:
					special_tile_type = VERTICAL_ARROW
					swapped_pos = test_pos
					print("remove_matches: found 4+ vertical fallback at ", test_pos)
					break
			print("remove_matches: fallback result special_tile_type=", special_tile_type, " swapped_pos=", swapped_pos)

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
		print("remove_matches: placed special tile type", special_tile_type, "at", swapped_pos)
	# Safeguard: if a special was expected but not placed for some reason, force it (avoid blocked cells)
	if special_tile_type > 0:
		if is_cell_blocked(swapped_pos.x, swapped_pos.y):
			print("remove_matches: expected special at", swapped_pos, "but cell is blocked; skipping force-creation")
		elif grid[swapped_pos.x][swapped_pos.y] != special_tile_type:
			grid[swapped_pos.x][swapped_pos.y] = special_tile_type
			print("remove_matches: [safeguard] forced special tile type", special_tile_type, "at", swapped_pos)

	var points = calculate_points(tiles_removed)
	print("[SCORING] Removed ", tiles_removed, " tiles, combo_count = ", combo_count, ", points = ", points)
	add_score(points)
	combo_count += 1
	print("[SCORING] New score: ", score, ", combo_count now: ", combo_count)

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
	# combo_count starts at 0 for first match, so use max(0, combo_count) to ensure:
	# First match (combo=0): 1.5^0 = 1.0x
	# Second match (combo=1): 1.5^1 = 1.5x
	# Third match (combo=2): 1.5^2 = 2.25x
	var combo_bonus = pow(COMBO_MULTIPLIER, max(0, combo_count))
	var total_points = int(base_points * combo_bonus)
	print("[SCORING] calculate_points: tiles=", tiles_removed, ", base=", base_points, ", combo_count=", combo_count, ", bonus=", combo_bonus, ", total=", total_points)
	return total_points

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

	# If a failure was pending but the score reached the target during a cascade, cancel failure
	if score >= target_score and pending_level_failed:
		pending_level_failed = false

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
	# Called when level is complete - just trigger the level complete flow
	# The level will be advanced later when user clicks Continue on the transition screen
	combo_count = 0
	on_level_complete()

func use_move():
	moves_left -= 1
	emit_signal("moves_changed", moves_left)

	print("[GameManager] use_move() called - moves_left now=", moves_left, ", score=", score, ", target=", target_score)

	if moves_left <= 0 and score < target_score and not level_transitioning:
		# Instead of immediately failing, mark a pending failure and wait for cascades to finish
		pending_level_failed = true
		print("[GameManager] pending_level_failed set = true")
		# Store level failure state snapshot (may be updated if score reaches target during cascade)
		last_level_won = false
		last_level_score = score
		last_level_target = target_score
		last_level_number = level
		last_level_moves_left = 0
		_attempt_level_failed()

func add_moves(amount: int):
	"""Add moves to the current game (e.g., from purchasing extra moves)"""
	moves_left += amount
	emit_signal("moves_changed", moves_left)
	print("[GameManager] Added %d moves. New total: %d" % [amount, moves_left])

	# If level was previously failed due to no moves, cancel pending failure
	if pending_level_failed:
		pending_level_failed = false
		print("[GameManager] Cancelled pending level failure - extra moves added")

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

func _attempt_level_failed():
	if level_transitioning:
		pending_level_failed = false
		return

	# Wait until board activity completes
	while processing_moves:
		await get_tree().create_timer(0.1).timeout
		# If level completed while waiting, cancel failure
		if score >= target_score or level_transitioning:
			pending_level_failed = false
			return

	# Short buffer
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	# If the score reached target during the wait, cancel failure
	if score >= target_score:
		pending_level_failed = false
		# Trigger completion flow
		if not level_transitioning:
			pending_level_complete = true
			_attempt_level_complete()
		return

	# Proceed with failure transition
	pending_level_failed = false
	on_level_failed()

func on_level_failed():
	if level_transitioning:
		return

	level_transitioning = true
	print("[GameManager] on_level_failed() called - transitioning to LevelProgressScene")

	# Wait for any board activity to finish before transitioning
	while processing_moves:
		if get_tree() == null:
			break
		await get_tree().create_timer(0.1).timeout

	# Short buffer to allow final tweens/deferred calls to complete
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	# Ensure the last level score is the final score at transition time
	last_level_won = false
	last_level_score = score
	last_level_target = target_score
	last_level_number = level
	last_level_moves_left = 0

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

	# Ensure final level score snapshot is stored
	last_level_won = true
	last_level_score = score
	last_level_target = target_score
	last_level_number = level
	last_level_moves_left = moves_left

	print("[GameManager] Level complete snapshot:")
	print("[GameManager]   GameManager.level = ", level)
	print("[GameManager]   last_level_number = ", last_level_number)
	print("[GameManager]   LevelManager.current_level_index = ", level_manager.current_level_index if level_manager else "N/A")
	print("[GameManager]   RewardManager.levels_completed (before) = ", RewardManager.levels_completed)

	# Calculate stars based on performance (1-3 stars)
	var stars = calculate_stars(score, target_score)
	print("Level completed with %d stars!" % stars)

	# Grant rewards through RewardManager to update levels_completed
	RewardManager.grant_level_completion_reward(level, stars)

	print("[GameManager]   RewardManager.levels_completed (after) = ", RewardManager.levels_completed)

	# Emit signal to show reward dialog in GameUI
	print("[GameManager] Emitting level_complete signal")
	emit_signal("level_complete")

	level_transitioning = false

func calculate_stars(final_score: int, target: int) -> int:
	"""Calculate star rating (1-3) based on score performance"""
	var performance_ratio = float(final_score) / float(target)

	if performance_ratio >= 2.0:
		# 200%+ of target = 3 stars
		return 3
	elif performance_ratio >= 1.5:
		# 150%-199% of target = 2 stars
		return 2
	elif performance_ratio >= 1.0:
		# 100%-149% of target = 1 star
		return 1
	else:
		# Below target = 0 stars (shouldn't happen as level completes when target reached)
		return 1
