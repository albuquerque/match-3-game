extends Node2D
class_name GameBoard

signal move_completed

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
			var tile = tile_scene.instantiate()
			var tile_type = GameManager.get_tile_at(Vector2(x, y))

			tile.setup(tile_type, Vector2(x, y), scale_factor)
			tile.position = grid_to_world_position(Vector2(x, y))
			tile.connect("tile_clicked", _on_tile_clicked)
			tile.connect("tile_swiped", _on_tile_swiped)

			add_child(tile)
			tiles[x].append(tile)

func clear_tiles():
	for child in get_children():
		if child is Tile:
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

func _on_tile_clicked(tile: Tile):
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
		print("GameBoard: Swipe target out of bounds")
		return

	# Get the target tile
	var target_tile = tiles[int(target_pos.x)][int(target_pos.y)]
	if not target_tile:
		print("GameBoard: No tile at target position")
		return

	# Perform the swap directly
	print("GameBoard: Swipe swap from ", tile.grid_position, " to ", target_pos)
	await perform_swap(tile, target_tile)

func perform_swap(tile1: Tile, tile2: Tile):
	GameManager.processing_moves = true

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

	await tween1.finished

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

		# Pass the swapped position to cascade for special tile creation
		await process_cascade(swap_pos_in_match)
	else:
		# No matches, revert swap
		GameManager.swap_tiles(pos1, pos2)

		var revert_tween1 = tile1.animate_swap_to(target_pos2)
		var revert_tween2 = tile2.animate_swap_to(target_pos1)

		tiles[pos1.x][pos1.y] = tile1
		tiles[pos2.x][pos2.y] = tile2
		tile1.grid_position = pos1
		tile2.grid_position = pos2

		await revert_tween1.finished

	GameManager.processing_moves = false
	emit_signal("move_completed")

func process_cascade(initial_swap_pos: Vector2 = Vector2(-1, -1)):
	var is_first_match = initial_swap_pos.x >= 0

	while true:
		var matches = GameManager.find_matches()
		if matches.size() == 0:
			break

		# Highlight matches briefly
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
			# Don't destroy the tile at special position - it will become special
			await animate_destroy_matches_except(matches, special_tile_pos)
			GameManager.remove_matches(matches, special_tile_pos)

			# Update the visual tile to show the special arrow
			var special_tile_type = GameManager.get_tile_at(special_tile_pos)
			if special_tile_type > 0:
				var tile_at_pos = tiles[int(special_tile_pos.x)][int(special_tile_pos.y)]
				if tile_at_pos:
					tile_at_pos.update_type(special_tile_type)
		else:
			# Normal match, destroy all tiles
			await animate_destroy_matches(matches)
			GameManager.remove_matches(matches)

		# Apply gravity
		await animate_gravity()

		# Fill empty spaces
		await animate_refill()

	GameManager.reset_combo()

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
		var tile = tiles[match_pos.x][match_pos.y]
		if tile:
			highlight_tweens.append(tile.animate_match_highlight())

	if highlight_tweens.size() > 0:
		await highlight_tweens[0].finished

func animate_destroy_matches(matches: Array):
	var destroy_tweens = []
	for match_pos in matches:
		var tile = tiles[match_pos.x][match_pos.y]
		if tile:
			destroy_tweens.append(tile.animate_destroy())
			tiles[match_pos.x][match_pos.y] = null

	if destroy_tweens.size() > 0:
		await destroy_tweens[0].finished

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
	GameManager.apply_gravity()

	var gravity_tweens = []

	for x in range(GameManager.GRID_WIDTH):
		var write_y = GameManager.GRID_HEIGHT - 1

		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if GameManager.get_tile_at(Vector2(x, y)) > 0:
				# Find the tile that should be here
				var source_tile = find_tile_for_position(x, y, write_y)

				if source_tile:
					tiles[x][write_y] = source_tile
					source_tile.grid_position = Vector2(x, write_y)
					source_tile.tile_type = GameManager.get_tile_at(Vector2(x, write_y))

					var target_pos = grid_to_world_position(Vector2(x, write_y))
					if source_tile.position.distance_to(target_pos) > 1:
						gravity_tweens.append(source_tile.animate_to_position(target_pos))

				write_y -= 1

	if gravity_tweens.size() > 0:
		await gravity_tweens[0].finished

func find_tile_for_position(x: int, target_y: int, write_y: int) -> Tile:
	for y in range(target_y, -1, -1):
		if tiles[x][y] != null:
			var tile = tiles[x][y]
			tiles[x][y] = null
			return tile
	return null

func animate_refill():
	var new_tile_positions = GameManager.fill_empty_spaces()
	var spawn_tweens = []

	for pos in new_tile_positions:
		var tile = tile_scene.instantiate()
		var tile_type = GameManager.get_tile_at(pos)

		tile.setup(tile_type, pos)
		tile.position = grid_to_world_position(Vector2(pos.x, -1))  # Start above grid
		tile.connect("tile_clicked", _on_tile_clicked)
		tile.connect("tile_swiped", _on_tile_swiped)

		add_child(tile)
		tiles[pos.x][pos.y] = tile

		var target_pos = grid_to_world_position(pos)
		spawn_tweens.append(tile.animate_to_position(target_pos))
		spawn_tweens.append(tile.animate_spawn())

	if spawn_tweens.size() > 0:
		await spawn_tweens[0].finished

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

func restart_game():
	GameManager.initialize_game()
	create_visual_grid()
