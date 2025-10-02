extends Node

signal score_changed(new_score)
signal level_changed(new_level)
signal moves_changed(moves_left)
signal game_over
signal level_complete

# Game configuration
const GRID_WIDTH = 8
const GRID_HEIGHT = 8
const TILE_TYPES = 6
const MIN_MATCH_SIZE = 3

# Scoring
const POINTS_PER_TILE = 100
const COMBO_MULTIPLIER = 1.5
const LEVEL_SCORE_REQUIREMENT = 10000

# Game state
var score = 0
var level = 1
var moves_left = 30
var target_score = 10000
var grid = []
var combo_count = 0
var processing_moves = false

func _ready():
	initialize_game()

func initialize_game():
	score = 0
	level = 1
	moves_left = 30
	target_score = LEVEL_SCORE_REQUIREMENT
	combo_count = 0
	processing_moves = false

	create_empty_grid()
	fill_initial_grid()

	emit_signal("score_changed", score)
	emit_signal("level_changed", level)
	emit_signal("moves_changed", moves_left)

func create_empty_grid():
	grid.clear()
	for x in range(GRID_WIDTH):
		grid.append([])
		for y in range(GRID_HEIGHT):
			grid[x].append(0)

func fill_initial_grid():
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var tile_type = get_safe_random_tile(x, y)
			grid[x][y] = tile_type

func get_safe_random_tile(x: int, y: int) -> int:
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

func is_valid_position(pos: Vector2) -> bool:
	return pos.x >= 0 and pos.x < GRID_WIDTH and pos.y >= 0 and pos.y < GRID_HEIGHT

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

			if tile_type != current_type or x == GRID_WIDTH:
				if x - match_start >= MIN_MATCH_SIZE and current_type > 0:
					for i in range(match_start, x):
						matches.append(Vector2(i, y))
				current_type = tile_type
				match_start = x

	# Find vertical matches
	for x in range(GRID_WIDTH):
		var current_type = grid[x][0]
		var match_start = 0

		for y in range(1, GRID_HEIGHT + 1):
			var tile_type = grid[x][y] if y < GRID_HEIGHT else -1

			if tile_type != current_type or y == GRID_HEIGHT:
				if y - match_start >= MIN_MATCH_SIZE and current_type > 0:
					for i in range(match_start, y):
						matches.append(Vector2(x, i))
				current_type = tile_type
				match_start = y

	return remove_duplicates(matches)

func remove_duplicates(matches: Array) -> Array:
	var unique_matches = []
	for match in matches:
		if not match in unique_matches:
			unique_matches.append(match)
	return unique_matches

func remove_matches(matches: Array) -> int:
	var tiles_removed = 0
	for match_pos in matches:
		if grid[match_pos.x][match_pos.y] > 0:
			grid[match_pos.x][match_pos.y] = 0
			tiles_removed += 1

	var points = calculate_points(tiles_removed)
	add_score(points)
	combo_count += 1

	return tiles_removed

func calculate_points(tiles_removed: int) -> int:
	var base_points = tiles_removed * POINTS_PER_TILE
	var combo_bonus = pow(COMBO_MULTIPLIER, combo_count - 1)
	return int(base_points * combo_bonus)

func apply_gravity() -> bool:
	var moved = false

	for x in range(GRID_WIDTH):
		var write_pos = GRID_HEIGHT - 1

		for y in range(GRID_HEIGHT - 1, -1, -1):
			if grid[x][y] > 0:
				if y != write_pos:
					grid[x][write_pos] = grid[x][y]
					grid[x][y] = 0
					moved = true
				write_pos -= 1

	return moved

func fill_empty_spaces() -> Array:
	var new_tiles = []

	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			if grid[x][y] == 0:
				grid[x][y] = randi() % TILE_TYPES + 1
				new_tiles.append(Vector2(x, y))

	return new_tiles

func add_score(points: int):
	score += points
	emit_signal("score_changed", score)

	if score >= target_score:
		advance_level()

func advance_level():
	level += 1
	target_score += LEVEL_SCORE_REQUIREMENT
	moves_left = 30
	combo_count = 0

	emit_signal("level_changed", level)
	emit_signal("moves_changed", moves_left)
	emit_signal("level_complete")

func use_move():
	moves_left -= 1
	emit_signal("moves_changed", moves_left)

	if moves_left <= 0:
		emit_signal("game_over")

func reset_combo():
	combo_count = 0

func get_tile_at(pos: Vector2) -> int:
	if is_valid_position(pos):
		return grid[pos.x][pos.y]
	return 0

func has_possible_moves() -> bool:
	for x in range(GRID_WIDTH):
		for y in range(GRID_HEIGHT):
			var pos = Vector2(x, y)

			# Check right
			if x < GRID_WIDTH - 1:
				var right_pos = Vector2(x + 1, y)
				if would_create_match_after_swap(pos, right_pos):
					return true

			# Check down
			if y < GRID_HEIGHT - 1:
				var down_pos = Vector2(x, y + 1)
				if would_create_match_after_swap(pos, down_pos):
					return true

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
