extends Node

# Pure model for grid state and pure grid transformations
# Do NOT declare class_name here — this script is used as an autoload singleton and declaring a class_name
# with the same name hides the autoload (causes "hides an autoload singleton" parse error). Use load().new() or
# NodeResolvers._fallback_autoload("GameState") to get instances instead.

var width: int = 8
var height: int = 8
var grid: Array = []
var collectible_positions: Array = []
var unmovable_map: Dictionary = {}
var spreader_positions: Array = []
var spreader_count: int = 0

var TILE_TYPES: int = 6
var COLLECTIBLE: int = 10
var UNMOVABLE: int = 11  # Sentinel for unmovable cells — excluded from matching, not a hard blocker
var SPREADER: int = 12

func _init(w: int = 8, h: int = 8, tile_types: int = 6):
	width = w
	height = h
	TILE_TYPES = tile_types
	create_empty_grid()

func create_empty_grid(w: int = -1, h: int = -1):
	if w > 0:
		width = w
	if h > 0:
		height = h
	grid.clear()
	for x in range(width):
		grid.append([])
		for y in range(height):
			grid[x].append(0)
	# Reset helpers
	collectible_positions = []
	unmovable_map = {}
	spreader_positions = []
	spreader_count = 0
	return grid

func fill_from_layout(layout: Array):
	# Fills self.grid based on layout array and returns a dictionary of derived data
	collectible_positions.clear()
	unmovable_map.clear()
	spreader_positions.clear()
	spreader_count = 0

	# Ensure grid sized correctly
	create_empty_grid(width, height)

	for x in range(width):
		for y in range(height):
			var cell_value = layout[x][y]

			# Normalize string tokens if present
			if typeof(cell_value) == TYPE_STRING:
				var token = cell_value
				if token == "X" or token == "x":
					grid[x][y] = -1
					continue
				elif token == "0":
					grid[x][y] = 0
					continue
				elif token == "C":
					grid[x][y] = COLLECTIBLE
					collectible_positions.append(Vector2(x, y))
					continue
				elif token == "S":
					grid[x][y] = SPREADER
					spreader_positions.append(Vector2(x, y))
					spreader_count += 1
					continue
				elif token == "U" or token == "u":
					# Soft unmovable — 1 hit, uses level default type
					grid[x][y] = UNMOVABLE
					var key_u = str(x) + "," + str(y)
					unmovable_map[key_u] = {"hits": 1, "type": "snow", "hard": false}
					continue
				elif token.begins_with("H") and ":" in token:
					var parts = token.substr(1, token.length()).split(":")
					var hits = 1
					var htype = "rock"
					if parts.size() >= 2:
						hits = int(parts[0]) if parts[0].is_valid_int() else 1
						htype = parts[1]
					# Use UNMOVABLE sentinel (11) so:
					# - GravityService skips it via _is_unmovable_cell()
					# - MatchFinder excludes it but does NOT break adjacent tile runs
					# - is_cell_blocked() returns false (it's not a hard X cell)
					# - Tile overlay correctly draws over it
					grid[x][y] = UNMOVABLE
					var key2 = str(x) + "," + str(y)
					unmovable_map[key2] = {"hits": hits, "type": htype, "hard": true}
					continue

			# Handle numeric / existing values
			if cell_value == -1:
				grid[x][y] = -1
			elif cell_value == 0:
				var tile_type = get_safe_random_tile(x, y)
				grid[x][y] = tile_type
			else:
				grid[x][y] = int(cell_value)

	return {
		"grid": grid,
		"collectible_positions": collectible_positions,
		"unmovable_map": unmovable_map,
		"spreader_positions": spreader_positions,
		"spreader_count": spreader_count
	}

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
	return 1

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

	return h_count >= 3 or v_count >= 3

func is_cell_blocked(x: int, y: int) -> bool:
	if x < 0 or x >= width or y < 0 or y >= height:
		return true
	if grid.size() <= x:
		return true
	if grid[x].size() <= y:
		return true
	return grid[x][y] == -1
