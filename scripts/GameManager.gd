extends Node

signal score_changed(new_score)
signal level_changed(new_level)
signal moves_changed(moves_left)
signal game_over
signal level_complete
signal level_loaded
signal collectibles_changed(collected, target)

# Game configuration
var GRID_WIDTH = 8
var GRID_HEIGHT = 8
const TILE_TYPES = 6
const MIN_MATCH_SIZE = 3
const HORIZTONAL_ARROW = 7
const VERTICAL_ARROW = 8
const FOUR_WAY_ARROW = 9
const COLLECTIBLE = 10  # Special type for collectibles - won't match with regular tiles
const UNMOVABLE_SOFT = 11  # Special type for unmovable_soft tiles - destroyed by adjacent matches

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

# Collectible tracking
var collectibles_collected = 0
var collectible_target = 0  # 0 = score-based level, >0 = collectible-based level
var collectible_type: String = "coin"  # Type of collectible for current level

# Unmovable tracking
var unmovable_type: String = "snow"  # Type of unmovable_soft for current level
var unmovables_cleared = 0  # Number of unmovable tiles destroyed
var unmovable_target = 0  # 0 = not required, >0 = must clear this many unmovables

signal unmovables_changed(cleared, target)

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

# Booster selection system
var available_boosters: Array = []  # Boosters available for current level

# Collectibles & special layout markers
var collectible_positions: Array = []
var unmovable_map: Dictionary = {}

# Booster tier definitions (for random selection)
const BOOSTER_TIERS = {
	"common": ["hammer", "shuffle", "swap"],
	"uncommon": ["chain_reaction", "bomb_3x3", "line_blast"],
	"rare": ["row_clear", "column_clear", "tile_squasher", "extra_moves"]
}

# Booster selection weights (probability distribution)
const TIER_WEIGHTS = {
	"common": 0.60,      # 60% chance
	"uncommon": 0.30,    # 30% chance
	"rare": 0.10         # 10% chance
}

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

		# Load collectible target (0 = score-based level)
		collectible_target = level_data.collectible_target if "collectible_target" in level_data else 0
		collectible_type = level_data.collectible_type if "collectible_type" in level_data else "coin"
		collectibles_collected = 0

		# Load unmovable type and target
		unmovable_type = level_data.unmovable_type if "unmovable_type" in level_data else "snow"
		unmovable_target = level_data.unmovable_target if "unmovable_target" in level_data else 0
		unmovables_cleared = 0

		print("[GameManager]   unmovable_type='", unmovable_type, "'")

		if unmovable_target > 0:
			print("[GameManager]   unmovable_target=", unmovable_target, " (must clear all unmovables)")
		else:
			print("[GameManager]   No unmovable target (score/collectible based)")

		if collectible_target > 0:
			print("[GameManager]   collectible_target=", collectible_target, " (collectible-based level)")
			print("[GameManager]   collectible_type='", collectible_type, "'")
		else:
			print("[GameManager]   Score-based level (no collectible target)")

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

	# Select random boosters for this level BEFORE emitting level_loaded
	# This ensures the UI can display them when it receives the signal
	select_level_boosters()

	emit_signal("level_loaded")

	# Emit unmovables_changed after level_loaded to ensure UI is ready
	if unmovable_target > 0:
		call_deferred("emit_signal", "unmovables_changed", unmovables_cleared, unmovable_target)

	# Emit collectibles_changed after level_loaded for consistency
	if collectible_target > 0:
		call_deferred("emit_signal", "collectibles_changed", collectibles_collected, collectible_target)

	print("[GameManager] ✓ load_current_level() completed, initialized =", initialized)


func select_level_boosters():
	"""Select 3-5 random boosters for the current level based on tier weights"""
	var rng = RandomNumberGenerator.new()
	# Use level number as seed for consistent selection per level
	rng.seed = hash(level)

	# Determine how many boosters to offer (3-5)
	var booster_count = rng.randi_range(3, 5)

	available_boosters.clear()
	var selected_set = {}  # Track selected to avoid duplicates

	print("[GameManager] Selecting %d boosters for level %d" % [booster_count, level])

	# Selection strategy:
	# - Always include at least 1 common booster
	# - Remaining slots based on weighted probability

	# First, guarantee 1 common booster
	var common_list = BOOSTER_TIERS["common"].duplicate()
	common_list.shuffle()
	var first_common = common_list[0]
	available_boosters.append(first_common)
	selected_set[first_common] = true
	print("[GameManager]   Guaranteed common: %s" % first_common)

	# Fill remaining slots with weighted random selection
	var attempts = 0
	var max_attempts = 50  # Prevent infinite loop

	while available_boosters.size() < booster_count and attempts < max_attempts:
		attempts += 1

		# Roll for tier based on weights
		var roll = rng.randf()
		var tier = ""

		if roll < TIER_WEIGHTS["rare"]:
			tier = "rare"
		elif roll < (TIER_WEIGHTS["rare"] + TIER_WEIGHTS["uncommon"]):
			tier = "uncommon"
		else:
			tier = "common"

		# Select random booster from tier
		var tier_boosters = BOOSTER_TIERS[tier].duplicate()
		tier_boosters.shuffle()

		# Find first non-selected booster from this tier
		for booster in tier_boosters:
			if not selected_set.has(booster):
				available_boosters.append(booster)
				selected_set[booster] = true
				print("[GameManager]   Selected %s: %s" % [tier, booster])
				break

	print("[GameManager] Final booster selection for level %d: " % level, available_boosters)

	return available_boosters

func create_empty_grid():
	grid.clear()
	for x in range(GRID_WIDTH):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(0)

func fill_grid_from_layout(layout: Array):
	"""Fill the grid based on level layout. Supports layout entries as ints (-1,0,N) or single-char tokens like 'C','U','H'."""
	# Clear helper structures
	collectible_positions.clear()
	unmovable_map.clear()

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var cell_value = layout[x][y]

			# Normalize string tokens if present
			if typeof(cell_value) == TYPE_STRING:
				# Single-char tokens expected
				var token = cell_value
				if token == "X" or token == "x":
					grid[x][y] = -1
					continue
				elif token == "0":
					grid[x][y] = 0
					continue
				elif token == "C":
					# Collectible: spawn as special type that won't match with regular tiles
					grid[x][y] = COLLECTIBLE
					collectible_positions.append(Vector2(x, y))
					continue
				elif token == "U":
					# Unmovable soft - single hit to destroy
					grid[x][y] = UNMOVABLE_SOFT
					# Store unmovable entry with hit count (1 by default)
					var key = str(x) + "," + str(y)
					unmovable_map[key] = 1
					print("[UNMOVABLE] Created unmovable at (", x, ",", y, ") with key '", key, "' and 1 hit")
					continue
				elif token == "H":
					# Unmovable hard (not yet fully implemented)
					grid[x][y] = 0
					unmovable_map[str(x) + "," + str(y)] = 4
					continue

			# Handle numeric / existing values
			if cell_value == -1:
				grid[x][y] = -1
			elif cell_value == 0:
				# Empty - fill with random tile
				var tile_type = get_safe_random_tile(x, y)
				grid[x][y] = tile_type
			else:
				# Specific tile type number
				grid[x][y] = int(cell_value)

	print("[GameManager] fill_grid_from_layout: collected collectible_positions size=", collectible_positions.size(), ", unmovable_map size=", unmovable_map.size())

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

	# Only blocked cells (-1) are considered blocked for layout/navigation.
	# Unmovable soft tiles are active cells (they occupy a cell and block falling until removed)
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

# New: whether cell contains a movable tile (not an unmovable_soft)
func is_cell_movable(x: int, y: int) -> bool:
	if x < 0 or x >= GRID_WIDTH or y < 0 or y >= GRID_HEIGHT:
		return false
	if grid.size() <= x or grid[x].size() <= y:
		return false
	var v = grid[x][y]
	# Movable if it's a regular tile or a special tile; not movable if blocked, empty or unmovable_soft
	if v == -1 or v == 0:
		return false
	if v == UNMOVABLE_SOFT:
		return false
	return true

func can_swap(pos1: Vector2, pos2: Vector2) -> bool:
	if not is_valid_position(pos1) or not is_valid_position(pos2):
		return false
	# Both positions must be movable (unmovable_soft cannot be swapped)
	if not is_cell_movable(int(pos1.x), int(pos1.y)) or not is_cell_movable(int(pos2.x), int(pos2.y)):
		return false
	return are_adjacent(pos1, pos2)

func swap_tiles(pos1: Vector2, pos2: Vector2) -> bool:
	# Only allow swap if both cells are movable and adjacent
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
					# CRITICAL: Don't match unmovables, collectibles, or special tiles
					if current_type != UNMOVABLE_SOFT and current_type != COLLECTIBLE:
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
					# CRITICAL: Don't match unmovables, collectibles, or special tiles
					if current_type != UNMOVABLE_SOFT and current_type != COLLECTIBLE:
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

		var grid_val = grid[match_pos.x][match_pos.y]

		# CRITICAL: Never remove unmovable tiles - they can only be destroyed by adjacent matches!
		if grid_val == UNMOVABLE_SOFT:
			print("[UNMOVABLE] ❌ ERROR: Unmovable at (", match_pos.x, ",", match_pos.y, ") was included in matches - this is a bug!")
			continue  # Skip it - unmovables can't match!

		if grid_val > 0:
			# Skip the swapped position if we're creating a special tile there
			if special_tile_type > 0 and match_pos.x == swapped_pos.x and match_pos.y == swapped_pos.y:
				continue
			grid[match_pos.x][match_pos.y] = 0
			tiles_removed += 1

	# After removing matched tiles, damage adjacent unmovable_soft tiles
	print("[UNMOVABLE] === CHECKING MATCH FOR ADJACENT UNMOVABLES ===")
	print("[UNMOVABLE] Matched tiles: ", matches.size(), " tiles")
	for i in range(matches.size()):
		print("[UNMOVABLE]   Match[", i, "]: position (", matches[i].x, ",", matches[i].y, ")")

	var adj_unmovables = []
	for match_pos in matches:
		var dirs = [Vector2(-1,0), Vector2(1,0), Vector2(0,-1), Vector2(0,1)]
		for d in dirs:
			var nx = int(match_pos.x) + int(d.x)
			var ny = int(match_pos.y) + int(d.y)
			if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
				var grid_value = grid[nx][ny]
				if grid_value == UNMOVABLE_SOFT:
					var vec = Vector2(nx, ny)
					if not adj_unmovables.has(vec):
						adj_unmovables.append(vec)
						print("[UNMOVABLE] Found unmovable at (", nx, ",", ny, ") adjacent to match at (", match_pos.x, ",", match_pos.y, ")")
				else:
					# Debug: show what's at adjacent positions that aren't unmovables
					if grid_value != -1 and grid_value != 0:  # Not blocked and not empty
						print("[UNMOVABLE]   Adjacent position (", nx, ",", ny, ") has grid value: ", grid_value, " (not unmovable)")

	print("[UNMOVABLE] Total adjacent unmovables found: ", adj_unmovables.size())

	if adj_unmovables.size() > 0:
		var board = get_node_or_null("/root/MainGame/GameBoard")
		var destroyed_any := false
		for pos in adj_unmovables:
			var key = str(int(pos.x)) + "," + str(int(pos.y))
			print("[UNMOVABLE] Processing unmovable at (", pos.x, ",", pos.y, "), key: ", key)

			# Decrement hit count in unmovable_map
			var remaining = 0
			if unmovable_map.has(key):
				var current_hits = int(unmovable_map[key])
				remaining = current_hits - 1
				print("[UNMOVABLE]   Current hits: ", current_hits, ", After damage: ", remaining)
			else:
				# default to 0 -> destroyed (shouldn't happen)
				print("[UNMOVABLE]   WARNING: Unmovable not in map! Defaulting to destroyed.")
				remaining = 0

			if remaining <= 0:
				# Delegate model updates to report_unmovable_destroyed which centralizes counters and signals
				report_unmovable_destroyed(pos)

				# Trigger visual destruction on board if tile exists
				if board and board.tiles and int(pos.x) < board.tiles.size():
					var tn = board.tiles[int(pos.x)][int(pos.y)] if int(pos.y) < board.tiles[int(pos.x)].size() else null
					if tn and tn.has_method("take_hit"):
						# Call take_hit which updates visuals; then animate destroy if destroyed
						var destroyed = tn.take_hit(1)
						if destroyed:
							if tn.has_method("animate_destroy"):
								tn.animate_destroy()
							# Delay queue_free to allow particle effects to spawn
							if not tn.is_queued_for_deletion():
								# Use call_deferred with a slight delay to ensure particles are created first
								tn.get_tree().create_timer(0.1).timeout.connect(tn.queue_free)
							# Clear visual reference so gravity will pick up tiles above
							if int(pos.x) < board.tiles.size() and int(pos.y) < board.tiles[int(pos.x)].size():
								board.tiles[int(pos.x)][int(pos.y)] = null
							destroyed_any = true
					else:
						# No method - just free it
						if tn and not tn.is_queued_for_deletion():
							tn.queue_free()
							if int(pos.x) < board.tiles.size() and int(pos.y) < board.tiles[int(pos.x)].size():
								board.tiles[int(pos.x)][int(pos.y)] = null
							destroyed_any = true
			else:
				# Update remaining hits
				unmovable_map[key] = remaining
				# If board tile exists, call take_hit to update its visual (no destroy yet)
				if board and board.tiles and int(pos.x) < board.tiles.size():
					var tn2 = board.tiles[int(pos.x)][int(pos.y)] if int(pos.y) < board.tiles[int(pos.x)].size() else null
					if tn2 and tn2.has_method("take_hit"):
						tn2.take_hit(1)

		# If any unmovable was destroyed, schedule gravity+refill to ensure tiles above fall into place
		if destroyed_any and board:
			print("[GameManager] Unmovable destroyed - scheduling gravity+refill on GameBoard")
			# Use call_deferred to avoid interfering with current flow; call the combined helper
			board.call_deferred("deferred_gravity_then_refill")

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

	# Track achievements
	if tiles_removed > 0:
		RewardManager.track_match_made()
		RewardManager.track_tiles_cleared(tiles_removed)
	RewardManager.track_combo_reached(combo_count)

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

		# Skip to first non-blocked position from bottom
		while write_pos >= 0 and is_cell_blocked(x, write_pos):
			write_pos -= 1

		# Scan from bottom to top, moving tiles down to fill gaps, but treat UNMOVABLE_SOFT as fixed obstacles
		for read_pos in range(GRID_HEIGHT - 1, -1, -1):
			# If the read position contains an unmovable soft, it should remain in place
			if grid[x][read_pos] == UNMOVABLE_SOFT:
				# Unmovable blocks gravity - set write_pos just above it
				# This ensures tiles above won't fall past the unmovable
				write_pos = read_pos - 1
				# Skip any blocked cells above the unmovable
				while write_pos >= 0 and is_cell_blocked(x, write_pos):
					write_pos -= 1
				continue

			# Skip blocked cells
			if is_cell_blocked(x, read_pos):
				continue

			var tile = grid[x][read_pos]
			if tile > 0 and tile != UNMOVABLE_SOFT:
				if read_pos != write_pos:
					# Move tile down to the write_pos
					grid[x][write_pos] = tile
					grid[x][read_pos] = 0
					moved = true

				# Move write position up for next tile
				write_pos -= 1

				# Skip any positions that are occupied by unmovable tiles OR blocked cells
				while write_pos >= 0 and (grid[x][write_pos] == UNMOVABLE_SOFT or is_cell_blocked(x, write_pos)):
					write_pos -= 1

	# Ensure that unmovable tiles remain in their original spots and not overwritten
	# (this is handled by above logic)

	if DEBUG_LOGGING:
		print("apply_gravity: END — grid snapshot after gravity:")
		for x in range(GRID_WIDTH):
			var col = []
			for y in range(GRID_HEIGHT):
				col.append(grid[x][y])
			print("col[", x, "] = ", col)
		print("apply_gravity: moved = ", moved)

	return moved

func has_clear_path_from_top(x: int, y: int) -> bool:
	"""Check if a cell has a clear path from the spawn point (first non-blocked row from top)"""
	# Find the first non-blocked row in this column (the spawn row)
	var spawn_row = -1
	for check_y in range(GRID_HEIGHT):
		if not is_cell_blocked(x, check_y):
			spawn_row = check_y
			break

	if spawn_row == -1:
		# Entire column is blocked - no tiles can spawn
		return false

	# Check all cells between spawn_row and target y for unmovables
	# (but don't include spawn_row itself or target y in the check)
	for check_y in range(spawn_row, y):
		if grid[x][check_y] == UNMOVABLE_SOFT:
			# There's an unmovable blocking the path from spawn point
			return false

	return true

func fill_empty_spaces() -> Array:
	var new_tiles = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if is_cell_blocked(x, y):
				continue  # Skip blocked cells

			if grid[x][y] == 0:
				# Only spawn tiles if there's a clear path from the spawn point
				# (no unmovable tiles blocking from spawn point)
				if not has_clear_path_from_top(x, y):
					# This cell is blocked from spawn point by an unmovable - leave it empty
					continue

				# Check if this position should spawn a collectible
				var should_spawn_collectible = false

				# For collectible levels, check if we haven't reached the target yet
				if collectible_target > 0 and collectibles_collected < collectible_target:
					# Check if there's a collectible position marker in this column that needs spawning
					for cpos in collectible_positions:
						if int(cpos.x) == x:
							# Spawn collectible in this column
							# Use a spawn rate to control frequency
							var spawn_chance = 0.3  # 30% chance per empty cell in marked column
							if randf() < spawn_chance:
								should_spawn_collectible = true
								break

				if should_spawn_collectible:
					# Spawn as collectible type
					grid[x][y] = COLLECTIBLE
					new_tiles.append(Vector2(x, y))
				else:
					# Spawn as regular tile
					grid[x][y] = randi_range(1, TILE_TYPES)
					new_tiles.append(Vector2(x, y))

	return new_tiles

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)

	# For unmovable-based levels, score doesn't trigger completion - only clearing all unmovables does
	if unmovable_target > 0:
		print("[GameManager] 🧱 UNMOVABLE LEVEL - Score: %d/%d, Unmovables: %d/%d - Score won't trigger completion" % [score, target_score, unmovables_cleared, unmovable_target])
		return

	# For collectible-based levels, score doesn't trigger completion - only collecting all collectibles does
	if collectible_target > 0:
		print("[GameManager] 🪙 COLLECTIBLE LEVEL - Score: %d/%d, Collectibles: %d/%d - Score won't trigger completion" % [score, target_score, collectibles_collected, collectible_target])
		return

	# For score-based levels, proceed with normal score-based completion
	print("[GameManager] 📊 SCORE LEVEL - Score: %d/%d" % [score, target_score])

	# If a failure was pending but the score reached the target during a cascade, cancel failure
	if score >= target_score and pending_level_failed:
		print("[GameManager] ✓ Score reached target during cascade - cancelling pending failure")
		pending_level_failed = false

	if score >= target_score and not level_transitioning:
		print("[GameManager] 🎯 TARGET SCORE REACHED - Triggering level completion")
		# Store level completion state
		last_level_won = true
		last_level_score = score
		last_level_target = target_score
		last_level_number = level
		last_level_moves_left = moves_left

		# Mark that a level completion should occur, but defer until board activity stops
		if not pending_level_complete:
			pending_level_complete = true
			print("[GameManager] → Setting pending_level_complete = true, calling _attempt_level_complete()")
			# Start the coroutine that will wait for ongoing activity to finish before advancing
			_attempt_level_complete()

func advance_level():
	# Called when level is complete - just trigger the level complete flow
	# The level will be advanced later when user clicks Continue on the transition screen
	print("[GameManager] 🎬 advance_level() called")
	if unmovable_target > 0:
		print("[GameManager] → Level type: UNMOVABLE")
		print("[GameManager] → Unmovables: %d/%d" % [unmovables_cleared, unmovable_target])
	elif collectible_target > 0:
		print("[GameManager] → Level type: COLLECTIBLE")
		print("[GameManager] → Collectibles: %d/%d, Score: %d/%d" % [collectibles_collected, collectible_target, score, target_score])
	else:
		print("[GameManager] → Level type: SCORE")
		print("[GameManager] → Score: %d/%d" % [score, target_score])
	combo_count = 0
	on_level_complete()

func use_move():
	moves_left -= 1
	emit_signal("moves_changed", moves_left)

	print("[GameManager] use_move() called - moves_left now=", moves_left, ", score=", score, ", target=", target_score)

	# Determine if level is failed based on level type
	var level_failed = false

	if unmovable_target > 0:
		# Unmovable-based level: fail if not all unmovables cleared and out of moves
		if moves_left <= 0 and unmovables_cleared < unmovable_target:
			level_failed = true
			print("[GameManager] Unmovable level failed: ", unmovables_cleared, "/", unmovable_target, " cleared")
	elif collectible_target > 0:
		# Collectible-based level: fail if collectibles not collected and out of moves
		if moves_left <= 0 and collectibles_collected < collectible_target:
			level_failed = true
			print("[GameManager] Collectible level failed: ", collectibles_collected, "/", collectible_target, " collected")
	else:
		# Score-based level: fail if score not reached and out of moves
		if moves_left <= 0 and score < target_score:
			level_failed = true
			print("[GameManager] Score level failed: ", score, "/", target_score, " points")

	if level_failed and not level_transitioning:
		# Instead of immediately failing, mark a pending failure and wait for cascades to finish
		pending_level_failed = true
		print("[GameManager] pending_level_failed set = true")
		# Store level failure state snapshot (may be updated if goal reached during cascade)
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
		# Check if level completed while waiting based on level type
		var goal_met = false
		if unmovable_target > 0:
			goal_met = unmovables_cleared >= unmovable_target
		elif collectible_target > 0:
			goal_met = collectibles_collected >= collectible_target
		else:
			goal_met = score >= target_score

		if goal_met or level_transitioning:
			pending_level_failed = false
			return

	# Short buffer
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	# Check if the goal was reached during the wait, cancel failure
	var goal_met = false
	if unmovable_target > 0:
		goal_met = unmovables_cleared >= unmovable_target
	elif collectible_target > 0:
		goal_met = collectibles_collected >= collectible_target
	else:
		goal_met = score >= target_score

	if goal_met:
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

	print("[GameManager] Level failed - emitting game_over signal")
	print("[GameManager]   Score: %d, Target: %d, Moves left: %d" % [score, target_score, moves_left])

	# Emit game_over signal to show the enhanced game over screen
	emit_signal("game_over")

	level_transitioning = false

func on_level_complete():
	print("[GameManager] 🎯 on_level_complete() called")
	print("[GameManager] → Level: %d, Type: %s" % [level, "COLLECTIBLE" if collectible_target > 0 else "SCORE"])
	print("[GameManager] → Collectibles: %d/%d, Score: %d/%d, Moves left: %d" % [collectibles_collected, collectible_target, score, target_score, moves_left])

	if level_transitioning:
		print("[GameManager] → Already transitioning, returning")
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

	# Set transitioning flag to prevent any further gameplay
	level_transitioning = true

	# Store original moves_left before bonus conversion
	var original_moves_left = moves_left

	# Bonus: Convert remaining moves to special tiles (like "Sugar Crush")
	if moves_left > 0:
		print("[GameManager] 🎉 BONUS! Converting %d remaining moves to special tiles!" % moves_left)
		await _convert_remaining_moves_to_bonus(moves_left)
		# Consume all remaining moves
		moves_left = 0
		emit_signal("moves_changed", moves_left)

	# Ensure final level score snapshot is stored
	last_level_won = true
	last_level_score = score
	last_level_target = target_score
	last_level_number = level
	last_level_moves_left = original_moves_left  # Use original count for star calculation

	print("[GameManager] Level complete snapshot:")
	print("[GameManager]   GameManager.level = ", level)
	print("[GameManager]   last_level_number = ", last_level_number)
	print("[GameManager]   LevelManager.current_level_index = ", level_manager.current_level_index if level_manager else "N/A")
	print("[GameManager]   RewardManager.levels_completed (before) = ", RewardManager.levels_completed)

	# Calculate stars based on performance using StarRatingManager
	# Note: Final score includes bonus points from remaining moves conversion
	var level_data = level_manager.get_level(level_manager.current_level_index)
	var total_moves = level_data.moves if level_data else 20
	var moves_used = total_moves - original_moves_left  # Use original count
	var star_manager = get_node("/root/StarRatingManager")
	var stars = star_manager.calculate_stars(score, target_score, moves_used, total_moves)
	print("[GameManager] Level completed with %d stars! (Score: %d, Target: %d, Moves: %d/%d)" % [stars, score, target_score, moves_used, total_moves])
	if original_moves_left > 0:
		print("[GameManager] Note: Score includes bonus from %d remaining moves" % original_moves_left)

	# Save star rating (only if better than previous)
	star_manager.save_level_stars(level, stars)

	# Grant rewards through RewardManager to update levels_completed
	RewardManager.grant_level_completion_reward(level, stars)

	# Track achievements for level completion
	print("[GameManager]   Total stars collected: ", star_manager.get_total_stars())

	# Emit signal to show reward dialog in GameUI
	print("[GameManager] Emitting level_complete signal")
	emit_signal("level_complete")

	# Keep level_transitioning = true to prevent further gameplay
	# This will be reset when the next level loads or game restarts
	# DO NOT set to false here!

var bonus_skipped = false  # Flag to track if player skipped bonus animation

func _convert_remaining_moves_to_bonus(remaining_moves: int):
	"""Convert remaining moves into special tiles and activate them for bonus points
	This creates a fun visual celebration similar to Candy Crush's 'Sugar Crush'
	Player can tap to skip and instantly calculate all bonus points"""

	print("[GameManager] 🎉 _convert_remaining_moves_to_bonus called with %d moves" % remaining_moves)

	# Lock player input during bonus phase
	processing_moves = true
	bonus_skipped = false

	# Get GameBoard reference
	var game_board = get_node_or_null("/root/MainGame/GameBoard")
	if not game_board:
		print("[GameManager] ❌ GameBoard not found, skipping bonus conversion")
		processing_moves = false
		return

	print("[GameManager] ✓ GameBoard found, starting bonus conversion")

	# Show "Tap to Skip" message
	if game_board.has_method("show_skip_bonus_hint"):
		game_board.show_skip_bonus_hint()
		print("[GameManager] ✓ Skip hint shown")
	else:
		print("[GameManager] ⚠️ GameBoard doesn't have show_skip_bonus_hint method")

	var bonus_points = 0

	# Convert each remaining move into a special tile
	for i in range(remaining_moves):
		print("[GameManager] Bonus move %d/%d - Looking for position..." % [i+1, remaining_moves])

		# Check if player skipped
		if bonus_skipped:
			print("[GameManager] ⏩ Bonus skipped! Calculating remaining points instantly...")
			# Calculate remaining bonus points instantly
			for j in range(i, remaining_moves):
				var instant_bonus = 100 * (j + 1)
				bonus_points += instant_bonus
				add_score(instant_bonus)
			print("[GameManager] 🌟 Instant bonus added: %d points" % (bonus_points - (100 * i * (i + 1) / 2)))
			break

		# Find random active tile position
		var random_pos = _get_random_active_tile_position()
		if random_pos == Vector2(-1, -1):
			print("[GameManager] ⚠️ No valid tile position found, ending bonus early at move %d/%d" % [i+1, remaining_moves])
			break  # No more active tiles

		print("[GameManager] ✓ Found position: %s" % random_pos)

		# Decide which special tile to create based on move number
		var special_type = FOUR_WAY_ARROW  # Most powerful for bonus

		# Create special tile at this position
		grid[int(random_pos.x)][int(random_pos.y)] = special_type
		print("[GameManager] ✓ Created special tile type %d at %s" % [special_type, random_pos])

		# Update visual tile if GameBoard has it
		if game_board.has_method("update_tile_visual"):
			game_board.update_tile_visual(random_pos, special_type)
		else:
			print("[GameManager] ⚠️ GameBoard doesn't have update_tile_visual method")

		# Small delay between conversions for visual effect
		await get_tree().create_timer(0.1).timeout

		# Activate the special tile immediately
		if game_board.has_method("activate_special_tile"):
			print("[GameManager] Activating special tile at %s..." % random_pos)
			await game_board.activate_special_tile(random_pos)
			print("[GameManager] ✓ Special tile activated")
		else:
			print("[GameManager] ⚠️ GameBoard doesn't have activate_special_tile method")

		# Calculate bonus points (each remaining move is worth progressively more)
		var move_bonus = 100 * (i + 1)  # 100, 200, 300, etc.
		bonus_points += move_bonus
		add_score(move_bonus)

		print("[GameManager] Bonus move %d/%d: Created special tile at %s, +%d points" % [i+1, remaining_moves, random_pos, move_bonus])

	# Hide skip hint
	if game_board.has_method("hide_skip_bonus_hint"):
		game_board.hide_skip_bonus_hint()

	if bonus_points > 0:
		print("[GameManager] 🌟 Bonus complete! Total bonus points: %d" % bonus_points)

	# If bonus was skipped, add a small delay to ensure board state settles
	if bonus_skipped:
		print("[GameManager] Bonus was skipped - adding settling delay before showing rewards")
		await get_tree().create_timer(0.5).timeout  # Increased from 0.3 to 0.5

		# Ensure board is hidden and stays hidden
		if game_board:
			game_board.visible = false
			print("[GameManager] After skip delay: board.visible = ", game_board.visible)

	# Release processing lock
	processing_moves = false
	print("[GameManager] _convert_remaining_moves_to_bonus finished, processing_moves = false")
	print("[GameManager] About to return to on_level_complete() to emit level_complete signal")

func skip_bonus_animation():
	"""Called when player taps to skip bonus animation"""
	if not bonus_skipped:
		bonus_skipped = true
		print("[GameManager] Player requested to skip bonus animation")

func _get_random_active_tile_position() -> Vector2:
	"""Get a random active (non-blocked, non-empty) tile position
	Excludes special tiles (7-9) and collectibles (10)"""
	var active_positions = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile_type = grid[x][y]
			# Include only regular tiles (1-6), exclude:
			# - blocked cells (-1)
			# - empty cells (0)
			# - special tiles (7-9)
			# - collectibles (10)
			if not is_cell_blocked(x, y) and tile_type >= 1 and tile_type <= TILE_TYPES:
				active_positions.append(Vector2(x, y))

	if active_positions.size() == 0:
		print("[GameManager] ⚠️ No valid positions for bonus conversion (active positions: 0)")
		return Vector2(-1, -1)

	# Return random position
	var random_index = randi() % active_positions.size()
	return active_positions[random_index]

func calculate_stars(final_score: int, target: int) -> int:
	"""DEPRECATED: Use StarRatingManager.calculate_stars() instead
	Calculate star rating (1-3) based on score performance"""
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

# Collectible handling
var _collectible_spawned_positions: Array = []  # track positions already spawned to avoid duplicates

func spawn_collectibles_for_targets():
	"""Queue collectible visuals for all target positions that haven't been spawned yet."""
	for cp in collectible_positions:
		var key = str(int(cp.x)) + "," + str(int(cp.y))
		if not _collectible_spawned_positions.has(key):
			# Request GameBoard to spawn visual
			var board = get_node_or_null("/root/MainGame/GameBoard")
			if board and board.has_method("spawn_collectible_visual"):
				board.spawn_collectible_visual(int(cp.x), int(cp.y), "coin")
				_collectible_spawned_positions.append(key)

func collectible_landed_at(pos: Vector2, coll_type: String):
	"""Called by GameBoard when a falling collectible lands on its target position."""
	print("[GameManager] 🪙 collectible_landed_at: ", pos, " type: ", coll_type)

	# Increment collected counter
	collectibles_collected += 1
	emit_signal("collectibles_changed", collectibles_collected, collectible_target)
	print("[GameManager] 🪙 Collected ", coll_type, " -> ", collectibles_collected, "/", collectible_target)

	# Remove the collectible marker so it doesn't respawn
	for i in range(collectible_positions.size()-1, -1, -1):
		var cp = collectible_positions[i]
		if int(cp.x) == int(pos.x) and int(cp.y) == int(pos.y):
			collectible_positions.remove_at(i)

	# Grant reward points
	var reward_points = 500
	add_score(reward_points)

	# Check if level is complete (if collectible-based level)
	if collectible_target > 0 and collectibles_collected >= collectible_target:
		print("[GameManager] ✨ ALL COLLECTIBLES COLLECTED! Level complete!")
		print("[GameManager] → Collectibles: %d/%d, Score: %d/%d" % [collectibles_collected, collectible_target, score, target_score])
		if not level_transitioning and not pending_level_complete:
			# Store level completion state
			last_level_won = true
			last_level_score = score
			last_level_target = target_score
			last_level_number = level
			last_level_moves_left = moves_left

			# Use pending mechanism to wait for any ongoing animations
			pending_level_complete = true
			print("[GameManager] → Setting pending_level_complete = true, calling _attempt_level_complete()")
			_attempt_level_complete()

	# NOTE: Gravity/refill is handled by GameBoard after collection animation

	# Clean spawned positions tracking
	var key = str(int(pos.x)) + "," + str(int(pos.y))
	if _collectible_spawned_positions.has(key):
		_collectible_spawned_positions.erase(key)

func report_unmovable_destroyed(pos: Vector2) -> void:
	"""Update model when an unmovable soft tile is destroyed.
	This centralizes counter updates, signal emission and level-completion checks.
	"""
	var key = str(int(pos.x)) + "," + str(int(pos.y))

	# Remove from map if present
	if unmovable_map.has(key):
		unmovable_map.erase(key)

	# Clear grid cell to empty so gravity/refill can proceed
	if int(pos.x) < grid.size() and int(pos.y) < grid[int(pos.x)].size():
		grid[int(pos.x)][int(pos.y)] = 0

	# Track unmovables cleared and notify UI
	unmovables_cleared += 1
	emit_signal("unmovables_changed", unmovables_cleared, unmovable_target)
	print("[GameManager] Unmovable reported destroyed at (", pos.x, ",", pos.y, ") - Cleared: ", unmovables_cleared, "/", unmovable_target)

	# Check completion
	if unmovable_target > 0 and unmovables_cleared >= unmovable_target:
		print("[GameManager] 🎯 ALL UNMOVABLES CLEARED - Triggering level completion (report_unmovable_destroyed)")
		if not pending_level_complete and not level_transitioning:
			last_level_won = true
			last_level_score = score
			last_level_target = unmovable_target
			last_level_number = level
			last_level_moves_left = moves_left
			pending_level_complete = true
			_attempt_level_complete()

# In the adjacent-unmovable handling block, replace the direct model updates with a call to report_unmovable_destroyed
# ...existing code...
