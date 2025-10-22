extends Node2D
class_name GameBoard

signal move_completed
signal board_idle

# Helper: await multiple tweens with timeout to avoid hanging if a tween never finishes
func _await_tweens_with_timeout(tweens: Array, timeout: float = 2.0) -> void:
	if tweens == null or tweens.size() == 0:
		return

	var finished_map = {}
	for tween in tweens:
		if tween == null:
			continue
		finished_map[tween] = false
		var local_tween = tween
		# Connect finished to set flag
		local_tween.finished.connect(func(): finished_map[local_tween] = true)

	var start_time = Time.get_ticks_msec()
	while true:
		var all_done = true
		for t in finished_map.keys():
			if not finished_map[t]:
				all_done = false
				break
		if all_done:
			break
		var elapsed = (Time.get_ticks_msec() - start_time) / 1000.0
		if elapsed >= timeout:
			print("[WARNING] Tween wait timed out after ", timeout, "s")
			break
		if get_tree() == null:
			break
		await get_tree().create_timer(0.05).timeout

var tiles = []
var selected_tile = null
var tile_scene = preload("res://scenes/Tile.tscn")

# Dynamic sizing variables
var tile_size: float
var grid_offset: Vector2
var board_margin: float = 20.0

const BOARD_BACKGROUND_COLOR = Color(0.2, 0.2, 0.3, 0.8)

@onready var background = $Background

func _ready():
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("level_complete", _on_level_complete)
	GameManager.connect("level_loaded", _on_level_loaded)

	calculate_responsive_layout()
	setup_background()
	create_visual_grid()

func calculate_responsive_layout():
	var viewport = get_viewport()
	var screen_size = viewport.get_visible_rect().size

	# Calculate available space for the game board
	var ui_top_space = 180.0  # Space for UI at top
	var ui_bottom_space = 100.0  # Space for UI at bottom
	var available_width = screen_size.x - (board_margin * 2)
	var available_height = screen_size.y - ui_top_space - ui_bottom_space - (board_margin * 2)

	# Calculate tile size based on available space
	var max_tile_size_width = available_width / GameManager.GRID_WIDTH
	var max_tile_size_height = available_height / GameManager.GRID_HEIGHT
	tile_size = min(max_tile_size_width, max_tile_size_height)

	# Ensure minimum tile size for playability
	tile_size = max(tile_size, 50.0)

	# Calculate grid offset to center the board
	var total_grid_width = GameManager.GRID_WIDTH * tile_size
	var total_grid_height = GameManager.GRID_HEIGHT * tile_size

	grid_offset = Vector2(
		(screen_size.x - total_grid_width) / 2,
		ui_top_space + (available_height - total_grid_height) / 2
	)

	print("Screen size: ", screen_size)
	print("Calculated tile size: ", tile_size)
	print("Grid offset: ", grid_offset)

func setup_background():
	# Create board background using dynamic sizing
	var board_size = Vector2(
		GameManager.GRID_WIDTH * tile_size + 20,
		GameManager.GRID_HEIGHT * tile_size + 20
	)

	background.color = BOARD_BACKGROUND_COLOR
	background.size = board_size
	# Center the background properly - tiles start at grid_offset, so background should be offset by half the padding
	background.position = Vector2(
		grid_offset.x - 10,
		grid_offset.y - 10
	)

func create_visual_grid():
	clear_tiles()
	tiles.clear()

	# Calculate scale factor for tiles based on dynamic tile size
	var scale_factor = tile_size / 64.0  # 64 is the base tile size

	for x in range(GameManager.GRID_WIDTH):
		tiles.append([])
		for y in range(GameManager.GRID_HEIGHT):
			var tile_type = GameManager.get_tile_at(Vector2(x, y))

			# Skip blocked cells (-1)
			if tile_type == -1:
				tiles[x].append(null)
				continue

			var tile = tile_scene.instantiate()
			tile.setup(tile_type, Vector2(x, y), scale_factor)
			tile.position = grid_to_world_position(Vector2(x, y))
			tile.connect("tile_clicked", _on_tile_clicked)
			tile.connect("tile_swiped", _on_tile_swiped)

			add_child(tile)
			tiles[x].append(tile)

func clear_tiles():
	for child in get_children():
		if child.has_method("setup"):  # Check if it's a Tile
			child.queue_free()

func grid_to_world_position(grid_pos: Vector2) -> Vector2:
	return Vector2(
		grid_pos.x * tile_size + grid_offset.x + tile_size/2,
		grid_pos.y * tile_size + grid_offset.y + tile_size/2
	)

func world_to_grid_position(world_pos: Vector2) -> Vector2:
	return Vector2(
		int((world_pos.x - grid_offset.x) / tile_size),
		int((world_pos.y - grid_offset.y) / tile_size)
	)

func _on_tile_clicked(tile):
	print("GameBoard received tile_clicked signal from tile at ", tile.grid_position)

	if GameManager.processing_moves:
		print("GameBoard: Move processing blocked")
		return

	# Check if clicked tile is a special tile (7, 8, or 9)
	var tile_type = GameManager.get_tile_at(tile.grid_position)
	if tile_type >= 7 and tile_type <= 9:
		print("Special tile activated at ", tile.grid_position, " type: ", tile_type)
		# Clear any existing selection
		if selected_tile:
			selected_tile.set_selected(false)
			selected_tile = null
		# Activate the special tile
		await activate_special_tile(tile.grid_position)
		return

	if selected_tile == null:
		# First selection
		print("GameBoard: Selecting first tile at ", tile.grid_position)
		selected_tile = tile
		tile.set_selected(true)
	elif selected_tile == tile:
		# Deselect same tile
		print("GameBoard: Deselecting tile at ", tile.grid_position)
		tile.set_selected(false)
		selected_tile = null
	else:
		# Try to swap tiles
		print("GameBoard: Attempting to swap tiles ", selected_tile.grid_position, " and ", tile.grid_position)
		if GameManager.can_swap(selected_tile.grid_position, tile.grid_position):
			print("GameBoard: Swap allowed, performing swap")
			await perform_swap(selected_tile, tile)
		else:
			print("GameBoard: Swap not allowed, selecting new tile")
			# Select new tile
			selected_tile.set_selected(false)
			selected_tile = tile
			tile.set_selected(true)

func _on_tile_swiped(tile: Tile, direction: Vector2):
	print("GameBoard received tile_swiped signal from tile at ", tile.grid_position, " direction: ", direction)

	if GameManager.processing_moves:
		print("GameBoard: Move processing blocked")
		return

	# Clear any existing selection when swiping
	if selected_tile:
		selected_tile.set_selected(false)
		selected_tile = null

	# Calculate the target tile position based on swipe direction
	var target_pos = tile.grid_position + direction

	# Check if target position is valid
	if not GameManager.is_valid_position(target_pos):
		print("GameBoard: Swipe target out of bounds or blocked")
		return

	# Get the target tile
	var target_tile = tiles[int(target_pos.x)][int(target_pos.y)]
	if not target_tile:
		print("GameBoard: No tile at target position (blocked cell)")
		return

	# Perform the swap directly
	print("GameBoard: Swipe swap from ", tile.grid_position, " to ", target_pos)
	await perform_swap(tile, target_tile)

func perform_swap(tile1: Tile, tile2: Tile):
	GameManager.processing_moves = true
	print("perform_swap: processing_moves = true")

	# Clear selections
	tile1.set_selected(false)
	tile2.set_selected(false)
	selected_tile = null

	var pos1 = tile1.grid_position
	var pos2 = tile2.grid_position

	# Perform swap in game logic
	GameManager.swap_tiles(pos1, pos2)

	# Animate swap
	var target_pos1 = grid_to_world_position(pos2)
	var target_pos2 = grid_to_world_position(pos1)

	var tween1 = tile1.animate_swap_to(target_pos1)
	var tween2 = tile2.animate_swap_to(target_pos2)

	# Update grid references
	tiles[pos1.x][pos1.y] = tile2
	tiles[pos2.x][pos2.y] = tile1
	tile1.grid_position = pos2
	tile2.grid_position = pos1

	# Wait for both swap tweens to finish to avoid racing visual/logic
	if tween1 != null:
		await tween1.finished
	if tween2 != null:
		await tween2.finished

    # Check for matches
	var matches = GameManager.find_matches()
	if matches.size() > 0:
		GameManager.use_move()

		# Determine which swapped position is part of the match
		var swap_pos_in_match = null
		if pos1 in matches:
			swap_pos_in_match = pos1
		elif pos2 in matches:
			swap_pos_in_match = pos2

		await process_cascade(swap_pos_in_match)
		GameManager.processing_moves = false
		print("perform_swap: processing_moves = false (from cascade end)")
		emit_signal("move_completed")
		return
	else:
		GameManager.swap_tiles(pos1, pos2)

		var revert_tween1 = tile1.animate_swap_to(target_pos2)
		var revert_tween2 = tile2.animate_swap_to(target_pos1)

		tiles[pos1.x][pos1.y] = tile1
		tiles[pos2.x][pos2.y] = tile2
		tile1.grid_position = pos1
		tile2.grid_position = pos2

		if revert_tween1 != null:
			await revert_tween1.finished
		if revert_tween2 != null:
			await revert_tween2.finished

	GameManager.processing_moves = false
	print("perform_swap: processing_moves = false")
	emit_signal("move_completed")


func process_cascade(initial_swap_pos: Vector2 = Vector2(-1, -1)):
	var is_first_match = initial_swap_pos.x >= 0
	var cascade_depth = 0
	var cascade_error = null
	print("=== Starting cascade process ===")
	while true:
		cascade_depth += 1
		if cascade_depth > 20:
			print("[ERROR] Cascade depth exceeded limit! Breaking loop.")
			break
		var matches = GameManager.find_matches()
		print("Found ", matches.size(), " matches in cascade")
		print("Grid after match check:")
		for y in range(GameManager.GRID_HEIGHT):
			var row = []
			for x in range(GameManager.GRID_WIDTH):
				row.append(GameManager.grid[x][y])
			print(row)
		print("Matches found:", matches)
		if matches.size() == 0:
			break

		await highlight_matches(matches)

		# For first match, use the swap position. For cascade matches, find the best position
		var special_tile_pos = null
		var will_create_special = false

		if is_first_match and initial_swap_pos.x >= 0 and initial_swap_pos.y >= 0:
			# Use the swap position for the first match
			var matches_on_same_row = 0
			var matches_on_same_col = 0
			for match_pos in matches:
				if match_pos.y == initial_swap_pos.y:
					matches_on_same_row += 1
				if match_pos.x == initial_swap_pos.x:
					matches_on_same_col += 1

			var has_horizontal = matches_on_same_row >= 3
			var has_vertical = matches_on_same_col >= 3
			var is_t_or_l_shape = has_horizontal and has_vertical
			var is_long_line = matches_on_same_row >= 4 or matches_on_same_col >= 4

			will_create_special = is_t_or_l_shape or is_long_line
			if will_create_special:
				special_tile_pos = initial_swap_pos

			print("First match - Row: ", matches_on_same_row, " Col: ", matches_on_same_col,
				  " T/L: ", is_t_or_l_shape, " Long: ", is_long_line, " Special: ", will_create_special)

			is_first_match = false
		else:
			# For cascade matches, detect T/L shapes or 4+ lines anywhere in the matches
			special_tile_pos = find_special_tile_position_in_matches(matches)
			will_create_special = special_tile_pos != null

			if will_create_special:
				print("Cascade match - Special tile will be created at: ", special_tile_pos)

		if will_create_special and special_tile_pos != null:
			await animate_destroy_matches_except(matches, special_tile_pos)
			var tiles_removed = GameManager.remove_matches(matches, special_tile_pos)
		else:
			print("Destroying ", matches.size(), " matched tiles")
			await animate_destroy_matches(matches)
			var tiles_removed = GameManager.remove_matches(matches)
			# Points are added inside GameManager.remove_matches(), do not add again here to avoid double-counting
			# var points = GameManager.calculate_points(tiles_removed)
			# GameManager.add_score(points)

		# Apply gravity
		print("Applying gravity...")
		await animate_gravity()
		print("Gravity complete")

		# Fill empty spaces
		print("Refilling empty spaces...")
		await animate_refill()
		print("Refill complete")
		print("Grid after refill:")
		for y in range(GameManager.GRID_HEIGHT):
			var row = []
			for x in range(GameManager.GRID_WIDTH):
				row.append(GameManager.grid[x][y])
			print(row)
	# Always reset processing_moves and combo, even if an error occurred
	GameManager.processing_moves = false
	GameManager.reset_combo()
	print("=== Cascade process complete ===")
	# Short buffer to ensure all last tweens/deferred calls have finished before marking board idle
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout
	if not GameManager.has_possible_moves():
		print("No valid moves detected! Auto-shuffling...")
		await get_tree().create_timer(1.0).timeout
		await perform_auto_shuffle()

func perform_auto_shuffle():
	"""Perform an automatic board shuffle with visual feedback"""
	# Show shuffle message/animation
	print("Performing auto-shuffle animation...")

	# Shuffle in GameManager until valid moves are found
	if GameManager.shuffle_until_moves_available():
		# Animate the shuffle visually
		await animate_shuffle()
		print("Board shuffled successfully with valid moves")
	else:
		print("ERROR: Could not find valid board configuration")

func animate_shuffle():
	"""Animate the tiles shuffling on screen"""
	# Create a shake/shuffle effect for all tiles
	var shuffle_tweens = []

	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles[x][y]
			if tile and not GameManager.is_cell_blocked(x, y):
				# Update tile type to match new grid state
				var new_type = GameManager.get_tile_at(Vector2(x, y))
				tile.update_type(new_type)

				# Create a shake effect
				var original_pos = tile.position
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(tile, "position", original_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.1)
				tween.tween_property(tile, "rotation", randf_range(-0.2, 0.2), 0.1)
				tween.set_parallel(false)
				tween.tween_property(tile, "position", original_pos, 0.2)
				tween.tween_property(tile, "rotation", 0.0, 0.1)
				shuffle_tweens.append(tween)

	# Wait for shuffle animation to complete
	if shuffle_tweens.size() > 0:
		await shuffle_tweens[0].finished
	else:
		await get_tree().create_timer(0.3).timeout

func find_special_tile_position_in_matches(matches: Array) -> Variant:
	"""Find if there's a T/L shape or 4+ line match in the matches, return the position for the special tile, or null if none."""
	if matches.size() < 4:
		return null  # Need at least 4 tiles for a special tile

	# First, check for T/L shapes (intersection of 3+ horizontal and 3+ vertical)
	for test_pos in matches:
		var matches_on_same_row = 0
		var matches_on_same_col = 0

		for match_pos in matches:
			if match_pos.y == test_pos.y:
				matches_on_same_row += 1
			if match_pos.x == test_pos.x:
				matches_on_same_col += 1

		# Check for T/L shape (3+ in both directions)
		if matches_on_same_row >= 3 and matches_on_same_col >= 3:
			print("Found T/L shape at ", test_pos, " - Row: ", matches_on_same_row, " Col: ", matches_on_same_col)
			return test_pos

	# Check for 4+ in a line (horizontal or vertical)
	# Group by rows
	var rows_dict = {}
	for match_pos in matches:
		if not rows_dict.has(match_pos.y):
			rows_dict[match_pos.y] = []
		rows_dict[match_pos.y].append(match_pos)

	for row_y in rows_dict:
		var row_matches = rows_dict[row_y]
		if row_matches.size() >= 4:
			print("Found 4+ horizontal line at row ", row_y, " with ", row_matches.size(), " tiles")
			return row_matches[row_matches.size() / 2]  # Use middle tile

	# Group by columns
	var cols_dict = {}
	for match_pos in matches:
		if not cols_dict.has(match_pos.x):
			cols_dict[match_pos.x] = []
		cols_dict[match_pos.x].append(match_pos)

	for col_x in cols_dict:
		var col_matches = cols_dict[col_x]
		if col_matches.size() >= 4:
			print("Found 4+ vertical line at col ", col_x, " with ", col_matches.size(), " tiles")
			return col_matches[col_matches.size() / 2]  # Use middle tile

	return null  # No special tile pattern found

func find_special_tile_position_in_matches(matches: Array) -> Vector2:
	"""Find if there's a T/L shape or 4+ line match in the matches, return the position for the special tile"""
	if matches.size() < 4:
		return Vector2(-1, -1)  # Need at least 4 tiles for a special tile

	# First, check for T/L shapes (intersection of 3+ horizontal and 3+ vertical)
	for test_pos in matches:
		var matches_on_same_row = 0
		var matches_on_same_col = 0

		for match_pos in matches:
			if match_pos.y == test_pos.y:
				matches_on_same_row += 1
			if match_pos.x == test_pos.x:
				matches_on_same_col += 1

		# Check for T/L shape (3+ in both directions)
		if matches_on_same_row >= 3 and matches_on_same_col >= 3:
			print("Found T/L shape at ", test_pos, " - Row: ", matches_on_same_row, " Col: ", matches_on_same_col)
			return test_pos

	# Check for 4+ in a line (horizontal or vertical)
	# Group by rows
	var rows_dict = {}
	for match_pos in matches:
		if not rows_dict.has(match_pos.y):
			rows_dict[match_pos.y] = []
		rows_dict[match_pos.y].append(match_pos)

	for row_y in rows_dict:
		var row_matches = rows_dict[row_y]
		if row_matches.size() >= 4:
			# Pick a random tile from this row for the special tile
			print("Found 4+ horizontal line at row ", row_y, " with ", row_matches.size(), " tiles")
			return row_matches[row_matches.size() / 2]  # Use middle tile

	# Group by columns
	var cols_dict = {}
	for match_pos in matches:
		if not cols_dict.has(match_pos.x):
			cols_dict[match_pos.x] = []
		cols_dict[match_pos.x].append(match_pos)

	for col_x in cols_dict:
		var col_matches = cols_dict[col_x]
		if col_matches.size() >= 4:
			# Pick a random tile from this column for the special tile
			print("Found 4+ vertical line at col ", col_x, " with ", col_matches.size(), " tiles")
			return col_matches[col_matches.size() / 2]  # Use middle tile

	return Vector2(-1, -1)  # No special tile pattern found

func highlight_matches(matches: Array):
	var highlight_tweens = []
	for match_pos in matches:
		var tile = tiles[int(match_pos.x)][int(match_pos.y)]
		if tile:
			highlight_tweens.append(tile.animate_match_highlight())

	# Await all highlight tweens to finish
	for tween in highlight_tweens:
		if tween != null:
			await tween.finished


func animate_destroy_matches(matches: Array):
	print("animate_destroy_matches called with ", matches.size(), " matches")
	var destroy_tweens = []
	var tiles_to_free = []
	var destroyed_positions = []

	for match_pos in matches:
		var tile = tiles[int(match_pos.x)][int(match_pos.y)]
		if tile:
			var tween = tile.animate_destroy()
			if tween:
				destroy_tweens.append(tween)
			tiles_to_free.append(tile)
			destroyed_positions.append(match_pos)

	# Await all destroy tweens (if any), otherwise short timeout
	if destroy_tweens.size() > 0:
		for tween in destroy_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.3).timeout

	print("animate_destroy_matches: animations finished, clearing grid and freeing nodes")
	# Now clear visual grid references and GameManager grid, then free tiles
	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			# Only clear visual cell if it still points to the same instance
			if tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles[int(pos.x)][int(pos.y)] = null
			# Ensure GameManager grid reflects cleared tile (skip blocked cells)
			if not GameManager.is_cell_blocked(int(pos.x), int(pos.y)):
				GameManager.grid[int(pos.x)][int(pos.y)] = 0
			# Safely free the tile node if not already queued
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()
	print("animate_destroy_matches: done")


func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	var destroy_tweens = []
	var tiles_to_free = []
	var destroyed_positions = []

	for match_pos in matches:
		if match_pos == skip_pos:
			continue
		var tile = tiles[int(match_pos.x)][int(match_pos.y)]
		if tile:
			var tween = tile.animate_destroy()
			if tween:
				destroy_tweens.append(tween)
			tiles_to_free.append(tile)
			destroyed_positions.append(match_pos)

	# Await all destroy tweens
	if destroy_tweens.size() > 0:
		for tween in destroy_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.2).timeout

	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0 and tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
			tiles[int(pos.x)][int(pos.y)] = null
			tiles_to_free[i].queue_free()


func animate_destroy_tiles(positions: Array):
	# Destroy tiles at the given positions with animation
	var destroy_tweens = []
	var tiles_to_free = []
	var destroyed_positions = []

	for pos in positions:
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			var tween = tile.animate_destroy()
			if tween:
				destroy_tweens.append(tween)
			tiles_to_free.append(tile)
			destroyed_positions.append(pos)

	# Wait for animations to complete (or short timeout if none)
	if destroy_tweens.size() > 0:
		for tween in destroy_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.3).timeout

	print("animate_destroy_tiles: animations finished, clearing grid and freeing nodes")
	# Now clear visual grid references and GameManager grid, then free tiles
	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			# Only clear visual cell if it still points to the same instance
			if tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles[int(pos.x)][int(pos.y)] = null
			# Ensure GameManager grid reflects cleared tile (skip blocked cells)
			if not GameManager.is_cell_blocked(int(pos.x), int(pos.y)):
				GameManager.grid[int(pos.x)][int(pos.y)] = 0
			# Safely free the tile node if not already queued
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()
	print("animate_destroy_tiles: done")


func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	var destroy_tweens = []
	for match_pos in matches:
		# Skip the position where special tile will be created
		if match_pos == skip_pos:
			continue

		var tile = tiles[match_pos.x][match_pos.y]
		if tile:
			destroy_tweens.append(tile.animate_destroy())
			tiles[match_pos.x][match_pos.y] = null

	if destroy_tweens.size() > 0:
		await destroy_tweens[0].finished

func animate_gravity():
	var moved = GameManager.apply_gravity()
	print("animate_gravity: apply_gravity returned -> ", moved)

	var gravity_tweens = []

	for x in range(GameManager.GRID_WIDTH):
		# Collect all existing non-null tiles in this column from BOTTOM TO TOP
		# This matches the order we'll assign them
		var column_tiles = []
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if not GameManager.is_cell_blocked(x, y) and tiles[x][y] != null:
				column_tiles.append(tiles[x][y])

		# Clear the visual tiles array for this column
		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.grid[x][y] == 0:
				tiles[x][y] = null

		# Now redistribute tiles based on GameManager grid (after gravity has been applied)
		# Iterate from bottom to top and assign tiles from the column_tiles array
		var tile_index = 0
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if GameManager.is_cell_blocked(x, y):
				continue

			var tile_type = GameManager.get_tile_at(Vector2(x, y))

			# If there's a tile in the GameManager grid, use the next available visual tile
			if tile_type > 0 and tile_index < column_tiles.size():
				var tile = column_tiles[tile_index]
				tiles[x][y] = tile
				tile.grid_position = Vector2(x, y)
				tile.update_type(tile_type)

				var target_pos = grid_to_world_position(Vector2(x, y))
				if tile.position.distance_to(target_pos) > 1:
					gravity_tweens.append(tile.animate_to_position(target_pos))

				tile_index += 1

	# Await all gravity tweens (or short timeout)
	if gravity_tweens.size() > 0:
		for tween in gravity_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.01).timeout
	print("animate_gravity: done")
	print("GameManager.grid after gravity:")
	for y in range(GameManager.GRID_HEIGHT):
		var row = []
		for x in range(GameManager.GRID_WIDTH):
			row.append(GameManager.grid[x][y])
		print(row)


func animate_refill():
	var new_tile_positions = GameManager.fill_empty_spaces()
	var spawn_tweens = []

	# Debug: print all positions being refilled
	print("Refilling positions:", new_tile_positions)

	# Calculate scale factor for tiles based on dynamic tile size
	var scale_factor = tile_size / 64.0  # 64 is the base tile size

	for pos in new_tile_positions:
		if not GameManager.is_cell_blocked(int(pos.x), int(pos.y)):
			if tiles[int(pos.x)][int(pos.y)] == null:
				var tile = tile_scene.instantiate()
				var tile_type = GameManager.get_tile_at(pos)
				tile.setup(tile_type, pos, scale_factor)
				tile.position = grid_to_world_position(Vector2(pos.x, -1))
				tile.connect("tile_clicked", _on_tile_clicked)
				tile.connect("tile_swiped", _on_tile_swiped)
				add_child(tile)
				tiles[int(pos.x)][int(pos.y)] = tile
				var target_pos = grid_to_world_position(pos)
				spawn_tweens.append(tile.animate_to_position(target_pos))
				spawn_tweens.append(tile.animate_spawn())

	# --- Sync step: ensure all non-blocked, non-empty grid cells have a visual tile ---
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y) and GameManager.grid[x][y] > 0:
				if tiles[x][y] == null:
					print("[BUG] Visual grid still has null at:", x, y, " -- fixing!")
					var tile = tile_scene.instantiate()
					tile.setup(GameManager.grid[x][y], Vector2(x, y), scale_factor)
					tile.position = grid_to_world_position(Vector2(x, -1))
					tile.connect("tile_clicked", _on_tile_clicked)
					tile.connect("tile_swiped", _on_tile_swiped)
					add_child(tile)
					tiles[x][y] = tile
					var target_pos = grid_to_world_position(Vector2(x, y))
					spawn_tweens.append(tile.animate_to_position(target_pos))
					spawn_tweens.append(tile.animate_spawn())

	# Debug: print visual grid state after refill
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if tiles[x][y] == null:
				print("[BUG] Visual grid still has null at:", x, y)

	# Await all spawn tweens
	if spawn_tweens.size() > 0:
		await _await_tweens_with_timeout(spawn_tweens, 2.0)
	else:
		if get_tree() != null:
			print("Refilling positions... Awaiting timer...")
			await get_tree().create_timer(0.3).timeout
			print("Refilling positions... Awaiting timer... END!")

	print("GameManager.grid after refill:")
	for y in range(GameManager.GRID_HEIGHT):
		var row = []
		for x in range(GameManager.GRID_WIDTH):
			row.append(GameManager.grid[x][y])
		print(row)

func activate_special_tile(pos: Vector2):
	"""Activate a special arrow tile to clear row/column/both"""
	print("activate_special_tile: start at ", pos)
	var tile_type = GameManager.get_tile_at(pos)
	print("Tile type at ", pos, " is ", tile_type)
	GameManager.processing_moves = true
	print("activate_special_tile: processing_moves = true")

	# Collect positions to clear based on tile type
	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:  # Horizontal arrow - clear row
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:  # Vertical arrow - clear column
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:  # 4-way arrow - clear row and column
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				if not positions_to_clear.has(Vector2(pos.x, y)):
					positions_to_clear.append(Vector2(pos.x, y))

	print("Clearing ", positions_to_clear.size(), " tiles")

	# Check for other special tiles in the positions to clear (chain reaction)
	var special_tiles_to_activate = []
	for clear_pos in positions_to_clear:
		if clear_pos == pos:
			continue

		var check_tile_type = GameManager.get_tile_at(clear_pos)
		if check_tile_type >= 7 and check_tile_type <= 9:
			print("Found special tile at ", clear_pos, " type: ", check_tile_type, " - will chain activate")
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	# Highlight the tiles that will be cleared with a special effect
	await highlight_special_activation(positions_to_clear)

	# Destroy the tiles with animation
	await animate_destroy_tiles(positions_to_clear)

	# Clear tiles in GameManager grid
	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	# Use a move for activating special tile
	GameManager.use_move()

	# Add points for cleared tiles
	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	# Activate any special tiles that were hit (chain reaction)
	if special_tiles_to_activate.size() > 0:
		print("Chain activating ", special_tiles_to_activate.size(), " special tiles")
		for special_tile_data in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_data["pos"], special_tile_data["type"])

	# Apply gravity and refill AFTER all chain reactions
	print("activate_special_tile: applying gravity")
	await animate_gravity()
	print("activate_special_tile: gravity complete")
	await animate_refill()
	print("activate_special_tile: refill complete")

	# Check for cascade matches after refill
	await process_cascade()

	GameManager.processing_moves = false
	print("activate_special_tile: processing_moves = false")

func activate_special_tile_chain(pos: Vector2, tile_type: int):
	"""Activate a special tile as part of a chain"""
	print("Chain-activating special tile type ", tile_type, " at ", pos)

	# Collect positions to clear based on tile type
	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:
		for y in range(GameManager.GRID_HEIGHT):
			positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if not positions_to_clear.has(Vector2(pos.x, y)):
				positions_to_clear.append(Vector2(pos.x, y))

	# Check for more special tiles in this chain
	var special_tiles_to_activate = []
	for clear_pos in positions_to_clear:
		if clear_pos == pos:
			continue

		var check_tile_type = GameManager.get_tile_at(clear_pos)
		if check_tile_type >= 7 and check_tile_type <= 9:
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	# Highlight and destroy
	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)

	# Clear tiles in GameManager grid
	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	# Add points
	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	# Recursively activate chained special tiles
	if special_tiles_to_activate.size() > 0:
		for special_tile_info in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

func highlight_special_activation(positions: Array):
	# Flash the tiles that will be cleared by special tile activation
	var highlight_tweens = []
	for pos in positions:
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			var tween = create_tween()
			tween.tween_property(tile, "modulate", Color.WHITE, 0.1)
			tween.tween_property(tile, "modulate", Color.YELLOW, 0.1)
			tween.tween_property(tile, "modulate", Color.WHITE, 0.1)
			highlight_tweens.append(tween)

	if highlight_tweens.size() > 0:
		await highlight_tweens[0].finished

func activate_special_tile(pos: Vector2):
	"""Activate a special arrow tile to clear row/column/both"""
	GameManager.processing_moves = true

	var tile_type = GameManager.get_tile_at(pos)
	print("Activating special tile type ", tile_type, " at ", pos)

	# Collect positions to clear based on tile type
	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:  # Horizontal arrow - clear row
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:  # Vertical arrow - clear column
		for y in range(GameManager.GRID_HEIGHT):
			positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:  # 4-way arrow - clear row and column
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if Vector2(pos.x, y) not in positions_to_clear:
				positions_to_clear.append(Vector2(pos.x, y))

	print("Clearing ", positions_to_clear.size(), " tiles")

	# Check for other special tiles in the positions to clear (chain reaction)
	var special_tiles_to_activate = []
	for clear_pos in positions_to_clear:
		if clear_pos == pos:
			continue

		var check_tile_type = GameManager.get_tile_at(clear_pos)
		if check_tile_type >= 7 and check_tile_type <= 9:
			print("Found special tile at ", clear_pos, " type: ", check_tile_type, " - will chain activate")
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	# Highlight the tiles that will be cleared with a special effect
	await highlight_special_activation(positions_to_clear)

	# Destroy the tiles with animation
	await animate_destroy_tiles(positions_to_clear)

	# Clear tiles in GameManager grid
	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	# Use a move for activating special tile
	GameManager.use_move()

	# Add points for cleared tiles
	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	# Activate any special tiles that were hit (chain reaction)
	if special_tiles_to_activate.size() > 0:
		print("Chain activating ", special_tiles_to_activate.size(), " special tiles")
		for special_tile_data in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_data["pos"], special_tile_data["type"])

	# Apply gravity and refill AFTER all chain reactions
	await animate_gravity()
	await animate_refill()

	# Check for cascade matches after refill
	await process_cascade()

	GameManager.processing_moves = false

func activate_special_tile_chain(pos: Vector2, tile_type: int):
	"""Activate a special tile as part of a chain"""
	print("Chain-activating special tile type ", tile_type, " at ", pos)

	# Collect positions to clear based on tile type
	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:
		for y in range(GameManager.GRID_HEIGHT):
			positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		for x in range(GameManager.GRID_WIDTH):
			positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if Vector2(pos.x, y) not in positions_to_clear:
				positions_to_clear.append(Vector2(pos.x, y))

	# Check for more special tiles in this chain
	var special_tiles_to_activate = []
	for clear_pos in positions_to_clear:
		if clear_pos == pos:
			continue

		var check_tile_type = GameManager.get_tile_at(clear_pos)
		if check_tile_type >= 7 and check_tile_type <= 9:
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	# Highlight and destroy
	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)

	# Clear tiles in GameManager grid
	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	# Add points
	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	# Recursively activate chained special tiles
	if special_tiles_to_activate.size() > 0:
		for special_tile_info in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

func highlight_special_activation(positions: Array):
	# Flash the tiles that will be cleared by special tile activation
	var highlight_tweens = []
	for pos in positions:
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			var tween = create_tween()
			tween.tween_property(tile, "modulate", Color.WHITE, 0.1)
			tween.tween_property(tile, "modulate", Color.YELLOW, 0.1)
			tween.tween_property(tile, "modulate", Color.WHITE, 0.1)
			highlight_tweens.append(tween)

	if highlight_tweens.size() > 0:
		await highlight_tweens[0].finished

func animate_destroy_tiles(positions: Array):
	# Destroy tiles at the given positions with animation
	var destroy_tweens = []
	for pos in positions:
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			destroy_tweens.append(tile.animate_destroy())
			tiles[int(pos.x)][int(pos.y)] = null

	if destroy_tweens.size() > 0:
		await destroy_tweens[0].finished

func _on_game_over():
	GameManager.processing_moves = true
	# Show game over effects
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if tiles[x][y]:
				var tween = create_tween()
				tween.tween_property(tiles[x][y], "modulate", Color.GRAY, 0.5)

func _on_level_complete():
	# Show level complete effects
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if tiles[x][y]:
				var tween = create_tween()
				tween.tween_property(tiles[x][y], "modulate", Color.GOLD, 0.3)
				tween.tween_property(tiles[x][y], "modulate", Color.WHITE, 0.3)

func _on_level_loaded():
	# Rebuild the board when a new level is loaded
	print("Level loaded, rebuilding board")
	calculate_responsive_layout()
	setup_background()
	create_visual_grid()

func restart_game():
	GameManager.initialize_game()
	calculate_responsive_layout()
	setup_background()
	create_visual_grid()
