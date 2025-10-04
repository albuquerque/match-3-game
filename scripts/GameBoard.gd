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
		await process_cascade()
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

func process_cascade():
	while true:
		var matches = GameManager.find_matches()
		if matches.size() == 0:
			break

		# Highlight matches briefly
		await highlight_matches(matches)

		# Remove matches
		await animate_destroy_matches(matches)
		GameManager.remove_matches(matches)

		# Apply gravity
		await animate_gravity()

		# Fill empty spaces
		await animate_refill()

	GameManager.reset_combo()

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

		add_child(tile)
		tiles[pos.x][pos.y] = tile

		var target_pos = grid_to_world_position(pos)
		spawn_tweens.append(tile.animate_to_position(target_pos))
		spawn_tweens.append(tile.animate_spawn())

	if spawn_tweens.size() > 0:
		await spawn_tweens[0].finished

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
