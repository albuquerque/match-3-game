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

	var start_time = 0
	var attempts = 0
	var max_attempts = int(timeout / 0.05)
	while true:
		var all_done = true
		for t in finished_map.keys():
			if not finished_map[t]:
				all_done = false
				break
		if all_done:
			break
		if attempts >= max_attempts:
			print("[WARNING] Tween wait timed out after ", timeout, "s")
			break
		if get_tree() == null:
			break
		attempts += 1
		await get_tree().create_timer(0.05).timeout

var tiles = []
var selected_tile = null
var tile_scene = preload("res://scenes/Tile.tscn")

# Dynamic sizing variables
var tile_size: float
var grid_offset: Vector2
var board_margin: float = 20.0

# Board appearance configuration
const BOARD_BACKGROUND_COLOR = Color(0.2, 0.2, 0.3, 0.7)  # Slightly translucent
var border_color: Color = Color(0.9, 0.9, 1.0, 0.9)  # Configurable border color
const BORDER_WIDTH = 3.0

# Background image
var background_image_path: String = ""  # Set this to enable background image
var background_sprite = null  # TextureRect for the background image

@onready var background = $Background
var border_container: Node2D  # Container for all border lines
var tile_area_overlay: Control = null  # Container for semi-transparent overlay pieces over tiles

func _ready():
	GameManager.connect("game_over", Callable(self, "_on_game_over"))
	GameManager.connect("level_complete", Callable(self, "_on_level_complete"))
	GameManager.connect("level_loaded", Callable(self, "_on_level_loaded"))

	# Create border container
	border_container = Node2D.new()
	border_container.name = "BorderContainer"
	add_child(border_container)

	# ========== CUSTOMIZATION EXAMPLES ==========
	# Uncomment and modify these lines to customize appearance:

	# Set custom border color (RGBA values from 0.0 to 1.0)
	# border_color = Color(1.0, 0.8, 0.2, 1.0)  # Gold/orange border
	# border_color = Color(0.2, 0.8, 1.0, 1.0)  # Cyan border
	# border_color = Color(1.0, 0.2, 0.8, 1.0)  # Pink border

	# Set background image (put your image in textures/ folder)
	background_image_path = "res://textures/background.jpg"
	# background_image_path = "res://textures/splash_screen.png"  # Example using existing asset

	# ============================================

	calculate_responsive_layout()
	setup_background()

	# Setup background image AFTER layout is calculated
	setup_background_image()

	# Only create visual grid if GameManager has initialized a level; otherwise wait for level_loaded
	if Engine.has_singleton("GameManager") and GameManager.initialized:
		create_visual_grid()
		draw_board_borders()
	else:
		print("[GameBoard] Waiting for GameManager.level_loaded before creating visual grid")

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
	# Hide the board background - we only want translucent tiles, not a background square
	# The background image will show through the tiles instead
	if background:
		background.visible = false

	# Keep the size/position calculations in case we need to re-enable it
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

	# Create semi-transparent overlay for the tile area
	setup_tile_area_overlay()

func setup_tile_area_overlay():
	"""Create a semi-transparent overlay covering only the active tile area (within borders)"""
	# Remove existing overlay if any
	if tile_area_overlay:
		tile_area_overlay.queue_free()
		tile_area_overlay = null

	# Create a container for the overlay pieces
	tile_area_overlay = Control.new()
	tile_area_overlay.name = "TileAreaOverlay"
	tile_area_overlay.z_index = -50  # Above background image, behind tiles
	tile_area_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Create individual semi-transparent rectangles for each active tile position
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y):
				var tile_overlay = ColorRect.new()
				tile_overlay.color = Color(0.1, 0.15, 0.25, 0.5)  # Semi-transparent dark overlay (50% opacity)
				tile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

				# Position and size to match the tile
				var left = x * tile_size + grid_offset.x
				var top = y * tile_size + grid_offset.y
				tile_overlay.position = Vector2(left, top)
				tile_overlay.size = Vector2(tile_size, tile_size)

				tile_area_overlay.add_child(tile_overlay)

	# Add to parent (MainGame)
	var parent = get_parent()
	if parent:
		parent.call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created with individual tile overlays")
	else:
		call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created (added to self)")

func setup_background_image():
	"""Setup a fullscreen background image behind the game board"""
	print("[GameBoard] setup_background_image called with path: ", background_image_path)

	# Remove existing background sprite if any
	if background_sprite:
		background_sprite.queue_free()
		background_sprite = null

	# If no background image path is set, skip
	if background_image_path == "":
		print("[GameBoard] No background image path set")
		return

	# Check if resource exists
	if not ResourceLoader.exists(background_image_path):
		print("[GameBoard] ERROR: Background image not found at: ", background_image_path)
		print("[GameBoard] Please check that the file exists and the path is correct")
		return

	print("[GameBoard] Loading background image...")

	# Create background using TextureRect (works better with Control nodes)
	var background_rect = TextureRect.new()
	background_rect.name = "BackgroundImage"

	# Load the texture
	var texture = load(background_image_path)
	if not texture:
		print("[GameBoard] ERROR: Failed to load texture from: ", background_image_path)
		return

	background_rect.texture = texture
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	print("[GameBoard] Texture loaded, size: ", texture.get_size())

	# Get viewport and screen size
	var viewport = get_viewport()
	if not viewport:
		print("[GameBoard] ERROR: No viewport available")
		return

	var screen_size = viewport.get_visible_rect().size

	print("[GameBoard] Screen size: ", screen_size)

	# Set size to cover entire screen
	background_rect.size = screen_size
	background_rect.position = Vector2.ZERO
	background_rect.z_index = -100  # Behind everything

	print("[GameBoard] Background rect size: ", background_rect.size)
	print("[GameBoard] Background rect position: ", background_rect.position)

	# Store reference (update type)
	if background_sprite:
		background_sprite.queue_free()
	background_sprite = background_rect

	# Add to parent (MainGame) to render behind everything
	# Use call_deferred because parent is busy during _ready()
	var parent = get_parent()
	if parent:
		# Hide or make transparent the existing Background ColorRect in MainGame
		var existing_bg = parent.get_node_or_null("Background")
		if existing_bg and existing_bg is ColorRect:
			# Make it invisible so our background image shows through
			existing_bg.visible = false
			print("[GameBoard] Hidden existing MainGame background to show image")

		# Defer both add_child and move_child
		parent.call_deferred("add_child", background_rect)
		parent.call_deferred("move_child", background_rect, 0)
		print("[GameBoard] Background will be added to parent (deferred): ", parent.name)
	else:
		# Fallback: add to self if no parent
		call_deferred("add_child", background_rect)
		call_deferred("move_child", background_rect, 0)
		print("[GameBoard] Background will be added to self (deferred, no parent found)")

	print("[GameBoard] Background image successfully loaded and will be added to scene!")
	print("[GameBoard] Background z_index: ", background_rect.z_index)
	print("[GameBoard] Background visible: ", background_rect.visible)

func set_border_color(color: Color):
	"""Set the color for the board borders"""
	border_color = color
	# Redraw borders with new color
	draw_board_borders()

func set_background_image(image_path: String):
	"""Set a background image for the game board screen"""
	background_image_path = image_path
	setup_background_image()

func clear_tiles():
	# Remove all Tile instances created by this board
	for child in get_children():
		if child and child.has_method("setup"):
			# Likely a Tile instance - queue for deletion
			child.queue_free()

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

# Helper: visually highlight positions for special activations (single flash)
func highlight_special_activation(positions: Array):
	if positions == null or positions.size() == 0:
		return
	var tweens = []
	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= GameManager.GRID_WIDTH or pos.y >= GameManager.GRID_HEIGHT:
			continue
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			var t = create_tween()
			t.tween_property(tile, "modulate", Color(1,1,0.7,1), 0.06)
			t.tween_property(tile, "modulate", Color.WHITE, 0.12)
			tweens.append(t)

	if tweens.size() > 0:
		await tweens[0].finished

# Destroy arbitrary tiles at given positions with animation and cleanup
func animate_destroy_tiles(positions: Array):
	if positions == null or positions.size() == 0:
		return

	var destroy_tweens = []
	var tiles_to_free = []
	var destroyed_positions = []

	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= GameManager.GRID_WIDTH or pos.y >= GameManager.GRID_HEIGHT:
			continue
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			# prefer tile.animate_destroy() if provided
			if tile.has_method("animate_destroy"):
				var tw = tile.animate_destroy()
				if tw:
					destroy_tweens.append(tw)
			else:
				# fallback: simple fade out
				var tw2 = create_tween()
				tw2.tween_property(tile, "modulate", Color(1,1,1,0), 0.15)
				destroy_tweens.append(tw2)
			tiles_to_free.append(tile)
			destroyed_positions.append(pos)

	# Await tweens to finish (or short timeout)
	if destroy_tweens.size() > 0:
		for tw in destroy_tweens:
			if tw != null:
				await tw.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.15).timeout

	# Clear grid entries and free nodes
	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			# Only clear visual cell if it still points to the same instance
			if tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles[int(pos.x)][int(pos.y)] = null
			# Update GameManager grid if not blocked
			if not GameManager.is_cell_blocked(int(pos.x), int(pos.y)):
				GameManager.grid[int(pos.x)][int(pos.y)] = 0
			# Safely free the tile
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()

	print("animate_destroy_tiles: destroyed ", tiles_to_free.size(), " tiles")

func animate_destroy_matches(matches: Array):
	if matches == null or matches.size() == 0:
		return
	await animate_destroy_tiles(matches)

func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	if matches == null or matches.size() == 0:
		return
	var to_destroy = []
	for m in matches:
		var pos = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			pos = Vector2(float(m["x"]), float(m["y"]))
		if pos == skip_pos:
			continue
		to_destroy.append(pos)
	if to_destroy.size() > 0:
		await animate_destroy_tiles(to_destroy)

func animate_gravity():
	var moved = GameManager.apply_gravity()
	print("animate_gravity: apply_gravity returned -> ", moved)

	var gravity_tweens = []
	for x in range(GameManager.GRID_WIDTH):
		var column_tiles = []
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if not GameManager.is_cell_blocked(x, y) and tiles[x][y] != null:
				column_tiles.append(tiles[x][y])

		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.grid[x][y] == 0:
				tiles[x][y] = null

		var tile_index = 0
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if GameManager.is_cell_blocked(x, y):
				continue
			var tile_type = GameManager.get_tile_at(Vector2(x, y))
			if tile_type > 0 and tile_index < column_tiles.size():
				var tile = column_tiles[tile_index]
				tiles[x][y] = tile
				tile.grid_position = Vector2(x, y)
				tile.update_type(tile_type)
				var target_pos = grid_to_world_position(Vector2(x, y))
				if tile.position.distance_to(target_pos) > 1:
					gravity_tweens.append(tile.animate_to_position(target_pos))
				tile_index += 1

	if gravity_tweens.size() > 0:
		for tween in gravity_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.01).timeout
	print("animate_gravity: done")

func animate_refill():
	var new_tile_positions = GameManager.fill_empty_spaces()
	var spawn_tweens = []
	var scale_factor = tile_size / 64.0
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

	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y) and GameManager.grid[x][y] > 0:
				if tiles[x][y] == null:
					var tile = tile_scene.instantiate()
					var ttype = GameManager.grid[x][y]
					tile.setup(ttype, Vector2(x, y), scale_factor)
					tile.position = grid_to_world_position(Vector2(x, -1))
					tile.connect("tile_clicked", _on_tile_clicked)
					tile.connect("tile_swiped", _on_tile_swiped)
					add_child(tile)
					tiles[x][y] = tile
					var target_pos = grid_to_world_position(Vector2(x, y))
					spawn_tweens.append(tile.animate_to_position(target_pos))
					spawn_tweens.append(tile.animate_spawn())

	if spawn_tweens.size() > 0:
		await spawn_tweens[0].finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.3).timeout

	print("GameManager.grid after refill:")
	for y in range(GameManager.GRID_HEIGHT):
		var row = []
		for x in range(GameManager.GRID_WIDTH):
			row.append(GameManager.grid[x][y])
		print(row)

func _on_game_over():
	print("[GameBoard] Game Over")
	# Cleanup or final actions on game over
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles[x][y]
			if tile:
				tile.set_process_input(false)  # Disable input processing for tiles

func _on_level_complete():
	print("[GameBoard] Level Complete")
	# Actions to perform on level completion, e.g. showing a summary, transitioning to next level, etc.

func _on_level_loaded():
	print("[GameBoard] Level Loaded")
	# Reset or initialize anything specific to the new level
	calculate_responsive_layout()
	setup_background()

	# Recreate the visual grid for the new level
	create_visual_grid()
	draw_board_borders()

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

	# Check if a booster is active
	var game_ui = get_node_or_null("../GameUI")
	# Only access GameUI-specific properties if the node is actually the GameUI scripted object
	if game_ui and game_ui is GameUI:
		if game_ui.booster_mode_active:
			var booster_type = game_ui.active_booster_type

			if booster_type == "shuffle":
				# Shuffle doesn't need tile selection - handled in button press
				pass
			elif booster_type == "swap":
				# Swap needs 2 tiles
				if game_ui.swap_first_tile == null:
					# First tile selected
					game_ui.swap_first_tile = tile.grid_position
					tile.set_selected(true)
					print("[GameBoard] Swap first tile selected: ", tile.grid_position, " - select second tile")
					return  # Don't reset booster mode yet
				else:
					# Second tile selected
					var first_pos = game_ui.swap_first_tile
					var second_pos = tile.grid_position

					# Deselect first tile
					var first_tile = tiles[int(first_pos.x)][int(first_pos.y)]
					if first_tile:
						first_tile.set_selected(false)

					await activate_swap_booster(int(first_pos.x), int(first_pos.y),
										int(second_pos.x), int(second_pos.y))
					game_ui.swap_first_tile = null
			elif booster_type == "hammer":
				await activate_hammer_booster(int(tile.grid_position.x), int(tile.grid_position.y))
			elif booster_type == "chain_reaction":
				await activate_chain_reaction_booster(int(tile.grid_position.x), int(tile.grid_position.y))
			elif booster_type == "bomb_3x3":
				await activate_bomb_3x3_booster(int(tile.grid_position.x), int(tile.grid_position.y))
			elif booster_type == "line_blast":
				await activate_line_blast_booster(game_ui.line_blast_direction,
										int(tile.grid_position.x), int(tile.grid_position.y))
			elif booster_type == "tile_squasher":
				await activate_tile_squasher_booster(int(tile.grid_position.x), int(tile.grid_position.y))
			elif booster_type == "row_clear":
				await activate_row_clear_booster(int(tile.grid_position.y))
			elif booster_type == "column_clear":
				await activate_column_clear_booster(int(tile.grid_position.x))

			# Reset booster mode (unless swap waiting for second tile)
			if not (booster_type == "swap" and game_ui.swap_first_tile != null):
				game_ui.booster_mode_active = false
				game_ui.active_booster_type = ""
				game_ui.update_booster_ui()

				# Reset all button colors
				var all_buttons = [game_ui.hammer_button, game_ui.shuffle_button, game_ui.swap_button,
									   game_ui.chain_reaction_button, game_ui.bomb_3x3_button, game_ui.line_blast_button,
									   game_ui.tile_squasher_button, game_ui.row_clear_button, game_ui.column_clear_button]
				for btn in all_buttons:
					if btn:
						btn.modulate = Color.WHITE
			# Return after handling booster action
			return

	# Check if clicked tile is a special tile (7, 8, or 9)
	var tile_type = GameManager.get_tile_at(tile.grid_position)
	if tile_type >= 7 and tile_type <= 9:
		print("Special tile activated at ", tile.grid_position, " type: ", tile_type)
		# Clear any existing selection
		if selected_tile:
			selected_tile.set_selected(false)
			selected_tile = null
		# Activate the special tile with full visuals and cascades
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

func _on_tile_swiped(tile, direction: Vector2):
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

func perform_swap(tile1, tile2):
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

	# Play swap sound effect
	AudioManager.play_sfx("tile_swap")

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

		# Award points for the first match
		var points = GameManager.calculate_points(matches.size())
		GameManager.add_score(points)

		# Determine which swapped position is part of the match
		var swap_pos_in_match = Vector2(-1, -1)
		if pos1 in matches:
			swap_pos_in_match = pos1
		elif pos2 in matches:
			swap_pos_in_match = pos2
		else:
			# If neither swapped tile is in the matches, check for a 4+ / T/L match and use that position
			var fallback_pos = find_special_tile_position_in_matches(matches)
			if fallback_pos.x >= 0 and fallback_pos.y >= 0:
				swap_pos_in_match = fallback_pos

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
			else:
				# If swapped tile wasn't in the 4+/T but the overall matches include one,
				# choose a fallback position from the matches so a special tile is created.
				var fallback = find_special_tile_position_in_matches(matches)
				if fallback.x >= 0 and fallback.y >= 0:
					will_create_special = true
					special_tile_pos = fallback
					print("First-match fallback: creating special at ", special_tile_pos)

			print("First match - Row: ", matches_on_same_row, " Col: ", matches_on_same_col,
				  " T/L: ", is_t_or_l_shape, " Long: ", is_long_line, " Special: ", will_create_special)

			is_first_match = false
		else:
			# For cascade matches, detect T/L shapes or 4+ lines anywhere in the matches
			special_tile_pos = find_special_tile_position_in_matches(matches)
			will_create_special = special_tile_pos != null

			if will_create_special:
				print("Cascade match - Special tile will be created at: ", special_tile_pos)

		# Play match sound effect (combo sound for cascades after first match)
		if cascade_depth > 1:
			AudioManager.play_sfx("combo")
		else:
			AudioManager.play_sfx("match")

		if will_create_special and special_tile_pos.x >= 0 and special_tile_pos.y >= 0:
			await animate_destroy_matches_except(matches, special_tile_pos)
			GameManager.remove_matches(matches, special_tile_pos)
		else:
			print("Destroying ", matches.size(), " matched tiles")
			await animate_destroy_matches(matches)
			GameManager.remove_matches(matches)

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
			# Pick the middle tile from this row for the special tile
			print("Found 4+ horizontal line at row ", row_y, " with ", row_matches.size(), " tiles")
			var mid = int(row_matches.size() / 2)
			return row_matches[mid]

	# Group by columns
	var cols_dict = {}
	for match_pos in matches:
		if not cols_dict.has(match_pos.x):
			cols_dict[match_pos.x] = []
		cols_dict[match_pos.x].append(match_pos)
	for col_x in cols_dict:
		var col_matches = cols_dict[col_x]
		if col_matches.size() >= 4:
			# Pick the middle tile from this column for the special tile
			print("Found 4+ vertical line at col ", col_x, " with ", col_matches.size(), " tiles")
			var midc = int(col_matches.size() / 2)
			return col_matches[midc]
	return Vector2(-1, -1)  # No special tile pattern found

func highlight_matches(matches: Array):
	var highlight_tweens = []
	for match_pos in matches:
		var tile = tiles[int(match_pos.x)][int(match_pos.y)]
		if tile:
			var tween = tile.animate_match_highlight()
			if tween != null:
				highlight_tweens.append(tween)

	# Await all highlight tweens to finish
	for tw in highlight_tweens:
		if tw != null:
			await tw.finished

# ============================================
# Booster Activation Functions
# ============================================

func activate_shuffle_booster():
	"""Activate shuffle booster - reorganizes entire board"""
	if not RewardManager.use_booster("shuffle"):
		print("[GameBoard] No shuffle boosters available!")
		return

	print("[GameBoard] Activating shuffle booster")
	GameManager.processing_moves = true

	# Play shuffle booster sound
	AudioManager.play_sfx("booster_shuffle")

	# Shuffle until valid moves found
	if GameManager.shuffle_until_moves_available():
		await animate_shuffle()

	GameManager.processing_moves = false
	print("[GameBoard] Shuffle booster complete")

func activate_swap_booster(x1: int, y1: int, x2: int, y2: int):
	"""Activate swap booster - swap any two tiles without adjacency requirement"""
	if not RewardManager.use_booster("swap"):
		print("[GameBoard] No swap boosters available!")
		return

	print("[GameBoard] Activating swap booster: (", x1, ",", y1, ") <-> (", x2, ",", y2, ")")
	GameManager.processing_moves = true

	# Play swap booster sound
	AudioManager.play_sfx("booster_swap")

	# Check valid tiles
	if GameManager.is_cell_blocked(x1, y1) or GameManager.is_cell_blocked(x2, y2):
		print("[GameBoard] Cannot swap blocked tiles!")
		GameManager.processing_moves = false
		return

	# Get tile references
	var tile1 = tiles[x1][y1]
	var tile2 = tiles[x2][y2]

	if not tile1 or not tile2:
		print("[GameBoard] Invalid tiles for swap!")
		GameManager.processing_moves = false
		return

	# Swap in GameManager grid
	var temp = GameManager.grid[x1][y1]
	GameManager.grid[x1][y1] = GameManager.grid[x2][y2]
	GameManager.grid[x2][y2] = temp

	# Animate swap
	var pos1 = grid_to_world_position(Vector2(x1, y1))
	var pos2 = grid_to_world_position(Vector2(x2, y2))

	var tween1 = tile1.animate_swap_to(pos2)
	var tween2 = tile2.animate_swap_to(pos1)

	# Update grid references
	tiles[x1][y1] = tile2
	tiles[x2][y2] = tile1
	tile1.grid_position = Vector2(x2, y2)
	tile2.grid_position = Vector2(x1, y1)

	# Update tile types
	tile1.update_type(GameManager.grid[x2][y2])
	tile2.update_type(GameManager.grid[x1][y1])

	if tween1:
		await tween1.finished
	if tween2:
		await tween2.finished

	# Check for matches after swap
	var matches = GameManager.find_matches()
	if matches.size() > 0:
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Swap booster complete")

func activate_chain_reaction_booster(x: int, y: int):
	"""Activate chain reaction booster - spreading explosion from selected tile"""
	if not RewardManager.use_booster("chain_reaction"):
		print("[GameBoard] No chain reaction boosters available!")
		return

	print("[GameBoard] Activating chain reaction booster at (", x, ",", y, ")")
	GameManager.processing_moves = true

	# Play chain reaction booster sound
	AudioManager.play_sfx("booster_chain")

	if GameManager.is_cell_blocked(x, y):
		print("[GameBoard] Cannot use chain reaction on blocked tile!")
		GameManager.processing_moves = false
		return

	# Wave 1: Center tile
	var wave1 = [Vector2(x, y)]
	await highlight_special_activation(wave1)
	await animate_destroy_tiles(wave1)
	for pos in wave1:
		GameManager.grid[int(pos.x)][int(pos.y)] = 0

	await get_tree().create_timer(0.3).timeout

	# Wave 2: Adjacent tiles (4 directions)
	var wave2 = []
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	for dir in directions:
		var nx = x + int(dir.x)
		var ny = y + int(dir.y)
		if nx >= 0 and nx < GameManager.GRID_WIDTH and ny >= 0 and ny < GameManager.GRID_HEIGHT:
			if not GameManager.is_cell_blocked(nx, ny) and GameManager.grid[nx][ny] > 0:
				wave2.append(Vector2(nx, ny))

	# Declare wave3 here so it's in scope for the total calculation later
	var wave3 = []

	if wave2.size() > 0:
		await highlight_special_activation(wave2)
		await animate_destroy_tiles(wave2)
		for pos in wave2:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		await get_tree().create_timer(0.3).timeout

		# Wave 3: Their adjacent tiles
		for pos in wave2:
			for dir in directions:
				var nx = int(pos.x) + int(dir.x)
				var ny = int(pos.y) + int(dir.y)
				if nx >= 0 and nx < GameManager.GRID_WIDTH and ny >= 0 and ny < GameManager.GRID_HEIGHT:
					if not GameManager.is_cell_blocked(nx, ny) and GameManager.grid[nx][ny] > 0:
						var vec = Vector2(nx, ny)
						if not wave3.has(vec):
							wave3.append(vec)

		if wave3.size() > 0:
			await highlight_special_activation(wave3)
			await animate_destroy_tiles(wave3)
			for pos in wave3:
				GameManager.grid[int(pos.x)][int(pos.y)] = 0

	# Calculate total score
	var total_destroyed = wave1.size() + wave2.size() + wave3.size()
	var points = GameManager.calculate_points(total_destroyed)
	GameManager.add_score(points)

	await animate_gravity()
	await animate_refill()
	await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Chain reaction booster complete - destroyed ", total_destroyed, " tiles")

func activate_bomb_3x3_booster(x: int, y: int):
	"""Activate 3x3 bomb booster - destroys 3x3 area around selected tile"""
	if not RewardManager.use_booster("bomb_3x3"):
		print("[GameBoard] No 3x3 bomb boosters available!")
		return

	print("[GameBoard] Activating 3x3 bomb booster at (", x, ",", y, ")")
	GameManager.processing_moves = true

	# Play 3x3 bomb sound
	AudioManager.play_sfx("booster_bomb_3x3")

	if GameManager.is_cell_blocked(x, y):
		print("[GameBoard] Cannot use bomb on blocked tile!")
		GameManager.processing_moves = false
		return

	# Collect 3x3 area
	var positions_to_clear = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx = x + dx
			var ny = y + dy
			if nx >= 0 and nx < GameManager.GRID_WIDTH and ny >= 0 and ny < GameManager.GRID_HEIGHT:
				if not GameManager.is_cell_blocked(nx, ny):
					positions_to_clear.append(Vector2(nx, ny))

	print("[GameBoard] 3x3 Bomb will destroy ", positions_to_clear.size(), " tiles")

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] 3x3 bomb booster complete")

func activate_line_blast_booster(direction: String, center_x: int, center_y: int):
	"""Activate line blast booster - clears 3 rows or 3 columns"""
	if not RewardManager.use_booster("line_blast"):
		print("[GameBoard] No line blast boosters available!")
		return

	print("[GameBoard] Activating line blast booster: ", direction, " at (", center_x, ",", center_y, ")")
	GameManager.processing_moves = true

	# Play line blast sound
	AudioManager.play_sfx("booster_line")

	var positions_to_clear = []

	if direction == "horizontal":
		# Clear 3 rows centered on center_y
		for row_offset in range(-1, 2):
			var target_y = center_y + row_offset
			if target_y >= 0 and target_y < GameManager.GRID_HEIGHT:
				for x in range(GameManager.GRID_WIDTH):
					if not GameManager.is_cell_blocked(x, target_y):
						positions_to_clear.append(Vector2(x, target_y))

	elif direction == "vertical":
		# Clear 3 columns centered on center_x
		for col_offset in range(-1, 2):
			var target_x = center_x + col_offset
			if target_x >= 0 and target_x < GameManager.GRID_WIDTH:
				for y in range(GameManager.GRID_HEIGHT):
					if not GameManager.is_cell_blocked(target_x, y):
						positions_to_clear.append(Vector2(target_x, y))

	print("[GameBoard] Line blast will destroy ", positions_to_clear.size(), " tiles")

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Line blast booster complete")

func activate_hammer_booster(x: int, y: int):
	"""Activate hammer booster on a single tile"""
	if not RewardManager.use_booster("hammer"):
		print("[GameBoard] No hammer boosters available!")
		return

	print("[GameBoard] Activating hammer booster on tile (", x, ",", y, ")")
	GameManager.processing_moves = true

	# Play hammer sound
	AudioManager.play_sfx("booster_hammer")

	# Check if it's a valid tile (not blocked)
	if GameManager.is_cell_blocked(x, y):
		print("[GameBoard] Cannot use hammer on blocked tile!")
		GameManager.processing_moves = false
		return

	var positions_to_clear = [Vector2(x, y)]

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Hammer booster complete")

func activate_tile_squasher_booster(x: int, y: int):
	"""Activate tile squasher booster - removes all tiles of the same type as selected"""
	if not RewardManager.use_booster("tile_squasher"):
		print("[GameBoard] No tile squasher boosters available!")
		return

	print("[GameBoard] Activating tile squasher booster on tile (", x, ",", y, ")")
	GameManager.processing_moves = true

	# Play tile squasher sound
	AudioManager.play_sfx("booster_tile_squasher")

	# Check if it's a valid tile (not blocked)
	if GameManager.is_cell_blocked(x, y):
		print("[GameBoard] Cannot use tile squasher on blocked tile!")
		GameManager.processing_moves = false
		return

	# Get the tile type at the selected position
	var target_type = GameManager.get_tile_at(Vector2(x, y))

	# Skip special tiles (types 7, 8, 9)
	if target_type >= 7:
		print("[GameBoard] Cannot use tile squasher on special tiles!")
		GameManager.processing_moves = false
		return

	# Find all tiles of the same type
	var positions_to_clear = []
	for grid_x in range(GameManager.GRID_WIDTH):
		for grid_y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(grid_x, grid_y):
				var tile_type = GameManager.get_tile_at(Vector2(grid_x, grid_y))
				if tile_type == target_type:
					positions_to_clear.append(Vector2(grid_x, grid_y))

	print("[GameBoard] Tile squasher will destroy ", positions_to_clear.size(), " tiles of type ", target_type)

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		# Use animate_destroy_tiles for arbitrary positions (matches var was incorrect)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Tile squasher booster complete")

func activate_row_clear_booster(row: int):
	"""Activate row clear booster on specified row"""
	if not RewardManager.use_booster("row_clear"):
		print("[GameBoard] No row clear boosters available!")
		return

	print("[GameBoard] Activating row clear booster on row ", row)
	GameManager.processing_moves = true

	# Play row clear sound
	AudioManager.play_sfx("booster_row_clear")

	var positions_to_clear = []
	for x in range(GameManager.GRID_WIDTH):
		if not GameManager.is_cell_blocked(x, row):
			positions_to_clear.append(Vector2(x, row))

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Row clear booster complete")

func activate_column_clear_booster(column: int):
	"""Activate column clear booster on specified column"""
	if not RewardManager.use_booster("column_clear"):
		print("[GameBoard] No column clear boosters available!")
		return

	print("[GameBoard] Activating column clear booster on column ", column)
	GameManager.processing_moves = true

	# Play column clear sound
	AudioManager.play_sfx("booster_column_clear")

	var positions_to_clear = []
	for y in range(GameManager.GRID_HEIGHT):
		if not GameManager.is_cell_blocked(column, y):
			positions_to_clear.append(Vector2(column, y))

	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0

		var points = GameManager.calculate_points(positions_to_clear.size())
		GameManager.add_score(points)

		await animate_gravity()
		await animate_refill()
		await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Column clear booster complete")

# Activate a special tile with visuals and chain activations
func activate_special_tile(pos: Vector2):
	print("activate_special_tile: start at ", pos)
	var tile_type = GameManager.get_tile_at(pos)
	print("Tile type at ", pos, " is ", tile_type)
	GameManager.processing_moves = true
	print("activate_special_tile: processing_moves = true")

	# Play general special activation sound
	AudioManager.play_sfx("special_activate")

	# Collect positions to clear based on tile type
	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
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
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	# Highlight and destroy visually
	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)

	# Clear tiles in GameManager grid
	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	# Use a move for activating special tile
	if GameManager.has_method("use_move"):
		GameManager.use_move()

	# Add points for cleared tiles
	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	# Activate any special tiles that were hit (chain reaction)
	if special_tiles_to_activate.size() > 0:
		for special_tile_info in special_tiles_to_activate:
			AudioManager.play_sfx("booster_chain")
			await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

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

# Activate special tile as part of a chain reaction
func activate_special_tile_chain(pos: Vector2, tile_type: int):
	print("Chain-activating special tile type ", tile_type, " at ", pos)

	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				positions_to_clear.append(Vector2(x, pos.y))
	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				positions_to_clear.append(Vector2(pos.x, y))
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				if not positions_to_clear.has(Vector2(pos.x, y)):
					positions_to_clear.append(Vector2(pos.x, y))

	var special_tiles_to_activate = []
	for clear_pos in positions_to_clear:
		if clear_pos == pos:
			continue

		var check_tile_type = GameManager.get_tile_at(clear_pos)
		if check_tile_type >= 7 and check_tile_type <= 9:
			special_tiles_to_activate.append({"pos": clear_pos, "type": check_tile_type})

	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)

	for clear_pos in positions_to_clear:
		GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0

	var points = GameManager.calculate_points(positions_to_clear.size())
	GameManager.add_score(points)

	if special_tiles_to_activate.size() > 0:
		for special_tile_info in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

	return

# Draw embossed borders around the active play area
func draw_board_borders():
	# Clear existing borders
	if border_container:
		for child in border_container.get_children():
			child.queue_free()

	# Simply draw borders around each edge of active tiles
	draw_simple_borders()

	print("[Border] Drew borders with ", border_container.get_child_count(), " elements")

# Draw simple borders by checking each tile's edges
func draw_simple_borders():
	var corner_radius = BORDER_WIDTH * 6.0  # Large radius for very pronounced rounded corners

	# For each active tile, check which edges need borders and draw them
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.is_cell_blocked(x, y):
				continue

			# Calculate tile edges in world coordinates
			var left = x * tile_size + grid_offset.x
			var right = (x + 1) * tile_size + grid_offset.x
			var top = y * tile_size + grid_offset.y
			var bottom = (y + 1) * tile_size + grid_offset.y

			# Check which edges need borders
			var has_top = (y == 0 or GameManager.is_cell_blocked(x, y - 1))
			var has_bottom = (y == GameManager.GRID_HEIGHT - 1 or GameManager.is_cell_blocked(x, y + 1))
			var has_left = (x == 0 or GameManager.is_cell_blocked(x - 1, y))
			var has_right = (x == GameManager.GRID_WIDTH - 1 or GameManager.is_cell_blocked(x + 1, y))

			# Draw top border (shortened at corners)
			if has_top:
				var start_x = left + (corner_radius if has_left else 0)
				var end_x = right - (corner_radius if has_right else 0)
				if end_x > start_x:  # Only draw if there's space
					draw_border_edge(Vector2(start_x, top), Vector2(end_x, top))

			# Draw bottom border (shortened at corners)
			if has_bottom:
				var start_x = left + (corner_radius if has_left else 0)
				var end_x = right - (corner_radius if has_right else 0)
				if end_x > start_x:
					draw_border_edge(Vector2(start_x, bottom), Vector2(end_x, bottom))

			# Draw left border (shortened at corners)
			if has_left:
				var start_y = top + (corner_radius if has_top else 0)
				var end_y = bottom - (corner_radius if has_bottom else 0)
				if end_y > start_y:
					draw_border_edge(Vector2(left, start_y), Vector2(left, end_y))

			# Draw right border (shortened at corners)
			if has_right:
				var start_y = top + (corner_radius if has_top else 0)
				var end_y = bottom - (corner_radius if has_bottom else 0)
				if end_y > start_y:
					draw_border_edge(Vector2(right, start_y), Vector2(right, end_y))

			# Draw quarter-circle arcs at corners
			if has_top and has_left:
				draw_corner_arc(Vector2(left, top), "top_left", corner_radius)
			if has_top and has_right:
				draw_corner_arc(Vector2(right, top), "top_right", corner_radius)
			if has_bottom and has_left:
				draw_corner_arc(Vector2(left, bottom), "bottom_left", corner_radius)
			if has_bottom and has_right:
				draw_corner_arc(Vector2(right, bottom), "bottom_right", corner_radius)

# Draw a single border edge
func draw_border_edge(start: Vector2, end: Vector2):
	var line = Line2D.new()
	line.add_point(start)
	line.add_point(end)
	line.width = BORDER_WIDTH
	line.default_color = border_color  # Use configurable color
	line.antialiased = true
	border_container.add_child(line)

# Draw a quarter-circle arc at a corner
func draw_corner_arc(corner_pos: Vector2, corner_type: String, radius: float):
	var line = Line2D.new()
	var num_segments = 8

	# Determine the arc based on corner type
	var start_angle = 0.0
	var end_angle = 0.0

	match corner_type:
		"top_left":
			# Arc from left side to top side
			# Start at (corner_pos.x + radius, corner_pos.y) going to (corner_pos.x, corner_pos.y + radius)
			# Center is at (corner_pos.x + radius, corner_pos.y + radius)
			for i in range(num_segments + 1):
				var t = float(i) / float(num_segments)
				var angle = lerp(PI, PI * 1.5, t)  # 180° to 270°
				var point = corner_pos + Vector2(radius, radius) + Vector2(cos(angle), sin(angle)) * radius
				line.add_point(point)
		"top_right":
			# Arc from top side to right side
			# Center is at (corner_pos.x - radius, corner_pos.y + radius)
			for i in range(num_segments + 1):
				var t = float(i) / float(num_segments)
				var angle = lerp(PI * 1.5, PI * 2.0, t)  # 270° to 360°
				var point = corner_pos + Vector2(-radius, radius) + Vector2(cos(angle), sin(angle)) * radius
				line.add_point(point)
		"bottom_left":
			# Arc from bottom side to left side
			# Center is at (corner_pos.x + radius, corner_pos.y - radius)
			for i in range(num_segments + 1):
				var t = float(i) / float(num_segments)
				var angle = lerp(PI * 0.5, PI, t)  # 90° to 180°
				var point = corner_pos + Vector2(radius, -radius) + Vector2(cos(angle), sin(angle)) * radius
				line.add_point(point)
		"bottom_right":
			# Arc from right side to bottom side
			# Center is at (corner_pos.x - radius, corner_pos.y - radius)
			for i in range(num_segments + 1):
				var t = float(i) / float(num_segments)
				var angle = lerp(0.0, PI * 0.5, t)  # 0° to 90°
				var point = corner_pos + Vector2(-radius, -radius) + Vector2(cos(angle), sin(angle)) * radius
				line.add_point(point)

	line.width = BORDER_WIDTH
	line.default_color = border_color  # Use configurable color
	line.antialiased = true
	border_container.add_child(line)
