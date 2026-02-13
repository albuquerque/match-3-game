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
		# Create a callable that sets the finished flag - use bind to avoid capture
		var set_finished = func(t): finished_map[t] = true
		tween.finished.connect(set_finished.bind(tween))

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

# Combo tracking
var combo_chain_count: int = 0  # Tracks consecutive matches in a cascade
var last_match_time: float = 0.0

# Skip bonus hint
var skip_bonus_label: Label = null
var skip_bonus_active: bool = false
const COMBO_TIMEOUT: float = 2.0  # Reset combo if no match for 2 seconds

# Board appearance configuration
const BOARD_BACKGROUND_COLOR = Color(0.2, 0.2, 0.3, 0.7)  # Slightly translucent
var border_color: Color = Color(0.9, 0.9, 1.0, 0.9)  # Configurable border color
const BORDER_WIDTH = 3.0

# Background image
var background_image_path: String = ""  # Set this to enable background image
var background_sprite = null  # TextureRect for the background image

# Guard against concurrent visual grid creation
var creating_visual_grid: bool = false

@onready var background = $Background
var border_container: Node2D  # Container for all border lines
var tile_area_overlay: Control = null  # Container for semi-transparent overlay pieces over tiles
var board_container: Node2D = null  # Master container for ALL board visual elements (tiles, borders, overlays)

func _ready():
	# Safely connect to GameManager signals if GameManager autoload is present
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.connect("game_over", Callable(self, "_on_game_over"))
		gm.connect("level_complete", Callable(self, "_on_level_complete"))
		gm.connect("level_loaded", Callable(self, "_on_level_loaded"))
	else:
		print("[GameBoard] WARNING: GameManager autoload not available at _ready(); will wait for level_loaded signal")

	# Create master board container to hold ALL visual elements
	# This allows hiding/showing the entire board area with one call
	board_container = Node2D.new()
	board_container.name = "BoardContainer"
	board_container.z_index = 0  # Standard game layer
	add_child(board_container)
	print("[GameBoard] Created BoardContainer to group all visual elements")

	# Create border container (will be added to board_container)
	border_container = Node2D.new()
	border_container.name = "BorderContainer"
	board_container.add_child(border_container)
	print("[GameBoard] BorderContainer added to BoardContainer")

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
	var gm2 = get_node_or_null("/root/GameManager")
	if gm2 and gm2.initialized:
		create_visual_grid()
		# Borders will be drawn when level_loaded triggers _on_level_loaded
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
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		print("[GameBoard] Removing existing tile_area_overlay")
		var parent_node = tile_area_overlay.get_parent()
		if parent_node:
			parent_node.remove_child(tile_area_overlay)
		tile_area_overlay.queue_free()
		tile_area_overlay = null

	# CRITICAL: Also check parent for any old TileAreaOverlay nodes
	# These can accumulate if cleanup didn't work properly
	var parent = get_parent()
	if parent:
		var old_overlays = []
		for child in parent.get_children():
			if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
				old_overlays.append(child)
				print("[GameBoard] Found orphaned TileAreaOverlay in parent - removing")

		# Remove all old overlays immediately
		for old_overlay in old_overlays:
			if is_instance_valid(old_overlay):
				parent.remove_child(old_overlay)
				old_overlay.queue_free()

	# ALSO check this node for any old TileAreaOverlay children
	var local_old_overlays = []
	for child in get_children():
		if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
			local_old_overlays.append(child)
			print("[GameBoard] Found orphaned TileAreaOverlay as direct child - removing")

	for old_overlay in local_old_overlays:
		if is_instance_valid(old_overlay):
			remove_child(old_overlay)
			old_overlay.queue_free()

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

	# Add to parent (MainGame) - use deferred to avoid "parent busy" error during _ready()
	if parent:
		parent.call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created with %d ColorRects, added to parent (deferred) (%s)" % [tile_area_overlay.get_child_count(), parent.name])
	else:
		call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created with %d ColorRects (added to self, deferred)" % tile_area_overlay.get_child_count())

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
	# Redraw borders with new color - use deferred safe call to avoid parser/static lookup issues
	if has_method("draw_board_borders"):
		call_deferred("draw_board_borders")
	else:
		print("[GameBoard] draw_board_borders() not defined yet; will be drawn when available")

func set_background_image(image_path: String):
	"""Set a background image for the game board screen"""
	background_image_path = image_path
	setup_background_image()

func hide_tile_overlay():
	"""Hide the tile area overlay"""
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		tile_area_overlay.visible = false
		print("[GameBoard] Tile overlay hidden")

	# Also hide the background ColorRect
	if background:
		background.visible = false
		print("[GameBoard] Background ColorRect hidden")

func show_tile_overlay():
	"""Show the tile area overlay"""
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		tile_area_overlay.visible = true
		print("[GameBoard] Tile overlay shown")

	# Keep the background ColorRect hidden as it's not needed with the image background
	# Only show if we don't have a background image
	if background and background_image_path == "":
		background.visible = false  # Keep hidden - we use tile overlays instead
		print("[GameBoard] Background ColorRect remains hidden (using tile overlays)")

func hide_board_group():
	"""Hide the entire board visual group (tiles, borders, overlay)
	This is the master control for hiding all middle zone game board elements"""
	print("[GameBoard] Hiding entire board group")

	# Hide the board container (contains tiles and borders)
	if board_container and is_instance_valid(board_container):
		board_container.visible = false
		print("[GameBoard]   - BoardContainer hidden (tiles + borders)")

	# Hide the tile area overlay (semi-transparent backgrounds)
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		tile_area_overlay.visible = false
		print("[GameBoard]   - TileAreaOverlay hidden (translucent backgrounds)")

	print("[GameBoard] ✓ All board visual elements hidden")

func show_board_group():
	"""Show the entire board visual group (tiles, borders, overlay)
	This is the master control for showing all middle zone game board elements"""
	print("[GameBoard] Showing entire board group")

	# Show the board container (contains tiles and borders)
	if board_container and is_instance_valid(board_container):
		board_container.visible = true
		print("[GameBoard]   - BoardContainer shown (tiles + borders)")

	# Show the tile area overlay (semi-transparent backgrounds)
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		tile_area_overlay.visible = true
		print("[GameBoard]   - TileAreaOverlay shown (translucent backgrounds)")

	print("[GameBoard] ✓ All board visual elements shown")

func set_board_group_visibility(is_visible: bool):
	"""Convenience method to show or hide the entire board group
	Args:
		is_visible: true to show, false to hide"""
	if is_visible:
		show_board_group()
	else:
		hide_board_group()

func clear_tiles():
	print("[CLEAR_TILES] Starting tile cleanup")
	# Remove all Tile instances created by this board
	# We need to collect them first to avoid modifying the array while iterating
	var tiles_to_remove = []

	# IMPORTANT: Check BOTH locations to handle all cases:
	# 1. New tiles in board_container (after grouping feature)
	# 2. Old tiles as direct children (before grouping feature or during transition)

	# Check board_container (where new tiles are added)
	if board_container and is_instance_valid(board_container):
		print("[CLEAR_TILES] Checking board_container for tiles...")
		for child in board_container.get_children():
			# Skip BorderContainer - only remove actual tiles
			if child and is_instance_valid(child) and child.name != "BorderContainer" and child.has_method("setup"):
				tiles_to_remove.append(child)
				print("[CLEAR_TILES]   Found tile in board_container: ", child.name)

	# ALSO check direct children (legacy tiles or stragglers)
	print("[CLEAR_TILES] Checking direct children for tiles...")
	for child in get_children():
		# Skip known non-tile children
		if child and is_instance_valid(child) and not (child.name in ["Background", "BorderContainer", "BoardContainer", "TileAreaOverlay"]) and child.has_method("setup"):
			tiles_to_remove.append(child)
			print("[CLEAR_TILES]   Found tile in direct children: ", child.name)

	# Now remove them all
	print("[CLEAR_TILES] Removing ", tiles_to_remove.size(), " tiles...")
	for tile in tiles_to_remove:
		if tile and is_instance_valid(tile):
			var parent = tile.get_parent()
			if parent and is_instance_valid(parent):
				parent.remove_child(tile)
			tile.queue_free()

	print("[CLEAR_TILES] ✓ Cleared ", tiles_to_remove.size(), " tiles from scene")

func create_visual_grid():
	# Guard against concurrent execution
	if creating_visual_grid:
		print("[GameBoard] ⚠️  create_visual_grid already in progress - skipping duplicate call")
		return

	creating_visual_grid = true
	print("[GameBoard] create_visual_grid: Starting (flag set)")

	clear_tiles()

	# CRITICAL: Wait one frame for queue_free() to actually process
	# This ensures old tiles are COMPLETELY removed before creating new ones
	await get_tree().process_frame

	tiles.clear()

	print("[GameBoard] Creating visual grid for ", GameManager.GRID_WIDTH, "x", GameManager.GRID_HEIGHT, " board")

	if GameManager.grid.size() == 0:
		print("[GameBoard] ERROR: GameManager.grid is empty! Cannot create tiles.")
		creating_visual_grid = false  # Reset flag
		return

	# Calculate scale factor for tiles based on dynamic tile size
	var scale_factor = tile_size / 64.0  # 64 is the base tile size

	var tiles_created = 0
	for x in range(GameManager.GRID_WIDTH):
		tiles.append([])
		for y in range(GameManager.GRID_HEIGHT):
			var tile_type = GameManager.get_tile_at(Vector2(x, y))

			# Skip blocked cells (-1)
			if tile_type == -1:
				tiles[x].append(null)
				continue

			var tile = tile_scene.instantiate()

			# Check if this position has a hard unmovable in GameManager.unmovable_map
			var key = str(x) + "," + str(y)
			if GameManager.unmovable_map.has(key) and typeof(GameManager.unmovable_map[key]) == TYPE_DICTIONARY:
				# This is a hard unmovable position - create unmovable tile with placeholder visual
				tile.setup(0, Vector2(x, y), scale_factor, true)

				var meta = GameManager.unmovable_map[key]
				var hits = 1
				var htype = GameManager.unmovable_type
				if meta.has("hits"):
					hits = int(meta["hits"])
				if meta.has("type"):
					htype = str(meta["type"])

				if tile.has_method("configure_unmovable_hard"):
					var textures_arr = []
					var reveals = {}
					if typeof(meta) == TYPE_DICTIONARY:
						if meta.has("textures"):
							textures_arr = meta["textures"]
						if meta.has("reveals"):
							reveals = meta["reveals"]
						# ensure types
						if typeof(textures_arr) != TYPE_ARRAY:
							textures_arr = []
						if typeof(reveals) != TYPE_DICTIONARY:
							reveals = {}
					# call configure with textures and reveals
					tile.configure_unmovable_hard(hits, htype, textures_arr, reveals)
					print("[GameBoard] Configured hard unmovable tile at (", x, ",", y, ") hits=", hits, " type=", htype)
				else:
					print("[GameBoard] WARNING: Tile missing configure_unmovable_hard method at (", x, ",", y, ")")
			else:
				# Normal tile (not unmovable)
				tile.setup(tile_type, Vector2(x, y), scale_factor)
			tile.position = grid_to_world_position(Vector2(x, y))
			tile.connect("tile_clicked", _on_tile_clicked)
			tile.connect("tile_swiped", _on_tile_swiped)

			# Check if this is a collectible tile (type 10)
			if tile_type == GameManager.COLLECTIBLE:
				if tile.has_method("configure_collectible"):
					tile.configure_collectible(GameManager.collectible_type)
					print("[GameBoard] Configured tile at (", x, ",", y, ") as collectible: ", GameManager.collectible_type)

			# Check if this is a spreader tile (type 12)
			if tile_type == GameManager.SPREADER:
				if tile.has_method("configure_spreader"):
					# Get textures for this spreader type from GameManager's spreader_textures_map
					var textures = []
					if GameManager.spreader_textures_map.has(GameManager.spreader_type):
						textures = GameManager.spreader_textures_map[GameManager.spreader_type]
					tile.configure_spreader(GameManager.spreader_grace_default, GameManager.spreader_type, textures)
					print("[GameBoard] Configured tile at (", x, ",", y, ") as spreader type '", GameManager.spreader_type, "' with grace: ", GameManager.spreader_grace_default, " textures: ", textures.size())

			# Add tile to board_container instead of directly to GameBoard
			# This keeps all visual elements grouped together
			if board_container:
				board_container.add_child(tile)
			else:
				add_child(tile)  # Fallback if container not created
			tiles[x].append(tile)
			tiles_created += 1

	print("[GameBoard] Created ", tiles_created, " tiles on the board")
	creating_visual_grid = false  # Reset flag
	print("[GameBoard] create_visual_grid: Complete (flag reset)")

	# Show entire board group now that tiles are created (prevents blank screen flash)
	show_board_group()
	print("[GameBoard] Board group made visible after tiles created")

	# CRITICAL: Also show UI elements now that level is ready
	var game_ui = get_node_or_null("../GameUI")
	if game_ui and game_ui.has_method("show_gameplay_ui"):
		game_ui.show_gameplay_ui()
		print("[GameBoard] UI elements shown - level ready")

# Collectible spawning and handling
func spawn_collectible_visual(x: int, y: int, coll_type: String = "coin"):
	"""Spawn a visual collectible at the given grid position"""
	if x < 0 or x >= GameManager.GRID_WIDTH or y < 0 or y >= GameManager.GRID_HEIGHT:
		return

	# Check if there's already a tile at this position
	var existing_tile = tiles[x][y] if x < tiles.size() and y < tiles[x].size() else null
	if existing_tile:
		# Configure existing tile as collectible
		if existing_tile.has_method("configure_collectible"):
			existing_tile.configure_collectible(coll_type)
			print("[GameBoard] Configured existing tile at (", x, ",", y, ") as collectible:", coll_type)
	else:
		# Create new collectible tile
		var scale_factor = tile_size / 64.0
		var tile = tile_scene.instantiate()
		tile.setup(0, Vector2(x, y), scale_factor)  # Use type 0 for collectible
		tile.position = grid_to_world_position(Vector2(x, y))
		tile.connect("tile_clicked", _on_tile_clicked)
		tile.connect("tile_swiped", _on_tile_swiped)

		# Configure as collectible
		if tile.has_method("configure_collectible"):
			tile.configure_collectible(coll_type)

		add_child(tile)

		# Update tiles array
		while tiles.size() <= x:
			tiles.append([])
		while tiles[x].size() <= y:
			tiles[x].append(null)
		tiles[x][y] = tile

		print("[GameBoard] Spawned new collectible at (", x, ",", y, ") type:", coll_type)

# Helper: visually highlight positions for special activations (single flash)
func highlight_special_activation(positions: Array):
	if positions == null or positions.size() == 0:
		return

	# Play special tile sound
	if positions.size() > 3:
		AudioManager.play_sfx("special_tile")

	var tweens = []
	for pos in positions:
		if pos.x < 0 or pos.y < 0:
			continue
		if pos.x >= GameManager.GRID_WIDTH or pos.y >= GameManager.GRID_HEIGHT:
			continue
		var tile = tiles[int(pos.x)][int(pos.y)]
		if tile:
			# Flash animation
			var t = create_tween()
			t.tween_property(tile, "modulate", Color(2, 2, 1, 1), 0.06)
			t.tween_property(tile, "modulate", Color.WHITE, 0.12)
			tweens.append(t)

			# Add radial particle burst for special tiles
			_create_special_activation_particles(grid_to_world_position(pos))

	if tweens.size() > 0:
		await tweens[0].finished

func _create_special_activation_particles(world_pos: Vector2):
	"""Create radial particle burst for special tile activation"""
	var particles = CPUParticles2D.new()
	particles.name = "SpecialActivationParticles"
	particles.position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 40  # Doubled from 20
	particles.lifetime = 1.2  # Longer lifetime
	particles.explosiveness = 1.0
	particles.speed_scale = 2.0  # Faster

	# Radial burst
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 10.0  # Larger emission area
	particles.direction = Vector2(0, 0)
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 150.0  # Faster burst
	particles.initial_velocity_max = 350.0
	particles.angular_velocity_min = -360  # More rotation
	particles.angular_velocity_max = 360
	particles.radial_accel_min = 80  # Stronger radial acceleration
	particles.radial_accel_max = 150

	# Larger, star-like particles
	particles.scale_amount_min = 1.5  # Much larger
	particles.scale_amount_max = 3.5

	# Bright golden/white color with glow
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.5, 1.5, 0.8, 1))  # Bright golden start
	gradient.add_point(0.3, Color(1.3, 1.3, 1.0, 1.0))  # Bright white
	gradient.add_point(0.6, Color(1.0, 1.0, 0.8, 0.8))
	gradient.add_point(1.0, Color(1, 1, 1, 0))  # Fade out
	particles.color_ramp = gradient

	# Add scale curve for more dynamic effect
	var scale_curve = Curve.new()
	scale_curve.add_point(Vector2(0, 1.3))  # Start big
	scale_curve.add_point(Vector2(0.4, 1.0))
	scale_curve.add_point(Vector2(0.8, 0.5))
	scale_curve.add_point(Vector2(1, 0))
	particles.scale_amount_curve = scale_curve

	add_child(particles)

	# Cleanup - use call_deferred to avoid lambda capture issues
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)

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

		var gx = int(pos.x)
		var gy = int(pos.y)

		# Safety check for tiles array
		if not tiles or gx >= tiles.size() or not tiles[gx] or gy >= tiles[gx].size():
			print("[ANIMATE_DESTROY] WARNING: Invalid tiles array access at (", gx, ",", gy, ")")
			continue

		var tile = tiles[gx][gy]
		if not tile or not is_instance_valid(tile):
			print("[ANIMATE_DESTROY] No valid tile at (", gx, ",", gy, ")")
			continue

		# CRITICAL FIX: Don't destroy hard unmovable tiles here!
		# They need to be preserved so take_hit() can process them and handle reveals
		var is_hard = tile.is_unmovable_hard if "is_unmovable_hard" in tile else false
		print("[ANIMATE_DESTROY] Checking tile at (", gx, ",", gy, ") is_unmovable_hard=", is_hard)
		if is_hard:
			print("[GameBoard] ✓✓✓ Skipping visual destruction of hard unmovable at (", gx, ",", gy, ") ✓✓✓")
			continue

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

	# Clear visual tiles and free nodes
	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			# Only clear visual cell if it still points to the same instance
			if tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles[int(pos.x)][int(pos.y)] = null
			# NOTE: Do NOT clear GameManager.grid here! That's done by GameManager.remove_matches()
			# The animation should only handle visual destruction, not game logic
			# Safely free the tile
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()

	print("animate_destroy_tiles: destroyed ", tiles_to_free.size(), " visual tiles")

func animate_destroy_matches(matches: Array):
	if matches == null or matches.size() == 0:
		return

	# Track combo chain
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_match_time > COMBO_TIMEOUT:
		combo_chain_count = 0  # Reset combo if too much time passed

	combo_chain_count += 1
	last_match_time = current_time

	print("[GameBoard] Match! Size: ", matches.size(), ", Combo chain: ", combo_chain_count)

	# Show combo text for most matches (only skip plain 3-tile first matches)
	var should_show_combo = true
	var combo_multiplier = combo_chain_count

	# Only skip basic 3-tile matches on first move
	if matches.size() == 3 and combo_chain_count == 1:
		should_show_combo = false  # Skip plain 3-tile matches

	# Always show for:
	# - 4+ tile matches
	# - Any cascade (combo_chain > 1)
	# - Special tile activations

	if should_show_combo:
		_show_combo_text(matches.size(), matches, combo_multiplier)

	# Screen shake for large matches or high combo chains
	if matches.size() >= 5 or combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, combo_chain_count * 3)
		_apply_screen_shake(0.15, shake_intensity)

	await animate_destroy_tiles(matches)

func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	if matches == null or matches.size() == 0:
		return

	# Track combo chain (same as animate_destroy_matches)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_match_time > COMBO_TIMEOUT:
		combo_chain_count = 0  # Reset combo if too much time passed

	combo_chain_count += 1
	last_match_time = current_time

	print("[GameBoard] Match (creating special)! Size: ", matches.size(), ", Combo chain: ", combo_chain_count)

	# Show combo text for this match (we're creating a special tile, that's impressive!)
	var should_show_combo = true
	var combo_multiplier = combo_chain_count

	# Always show combo text when creating special tiles (it's always 4+ tiles)
	if should_show_combo:
		_show_combo_text(matches.size(), matches, combo_multiplier)

	# Screen shake for large matches or high combo chains
	if matches.size() >= 5 or combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, combo_chain_count * 3)
		_apply_screen_shake(0.15, shake_intensity)

	# Destroy tiles except the skip position
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
	print("[GRAVITY] apply_gravity returned -> ", moved)


	var gravity_tweens = []

	# After apply_gravity, the grid values have been rearranged
	# We need to match visual tiles to the new grid positions

	for x in range(GameManager.GRID_WIDTH):
		# Step 1: Collect all non-null visual tiles from this column
		# IMPORTANT: Collect from BOTTOM to TOP to match assignment order
		# CRITICAL: Skip unmovable tiles - they don't move with gravity!
		# COLLECTIBLES DO MOVE - they should fall until they reach the bottom
		var visual_tiles_in_column = []
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):  # Bottom to top
			var tile = tiles[x][y]
			if tile != null and not tile.is_queued_for_deletion():
				# Skip hard unmovables - check tile instance property
				if "is_unmovable_hard" in tile and tile.is_unmovable_hard:
					print("[GRAVITY] Skipping hard unmovable tile at (", x, ",", y, ")")
					continue

				# COLLECTIBLES SHOULD FALL - include them in visual_tiles_in_column
				visual_tiles_in_column.append(tile)

		# Step 2: Clear the tiles array for this column (except hard unmovables)
		# COLLECTIBLES GET CLEARED so they can be reassigned by gravity
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles[x][y]

			# Skip hard unmovables - check tile instance
			if tile and "is_unmovable_hard" in tile and tile.is_unmovable_hard:
				print("[GRAVITY] Keeping hard unmovable tile at (", x, ",", y, ") in tiles array")
				continue

			# Clear collectibles too - they will be reassigned by gravity
			tiles[x][y] = null

		# Step 3: Match visual tiles to grid positions that need them
		# Scan from bottom to top, matching tiles to positions with grid values > 0
		var tile_index = 0
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if GameManager.is_cell_blocked(x, y):
				continue

			var tile_type = GameManager.get_tile_at(Vector2(x, y))


			# Skip hard unmovable positions - check if there's already a hard unmovable tile there
			var existing_tile = tiles[x][y]
			if existing_tile and "is_unmovable_hard" in existing_tile and existing_tile.is_unmovable_hard:
				print("[GRAVITY] Position (", x, ",", y, ") has hard unmovable - skipping")
				continue

			# COLLECTIBLES SHOULD BE ASSIGNED - they need to animate falling

			if tile_type > 0:
				# This position needs a tile (including collectibles)
				if tile_index < visual_tiles_in_column.size():
					# We have a tile to assign
					var tile = visual_tiles_in_column[tile_index]
					tiles[x][y] = tile
					tile.grid_position = Vector2(x, y)
					tile.update_type(tile_type)

					var target_pos = grid_to_world_position(Vector2(x, y))

					# Only animate if tile actually needs to move
					# And make sure it's not a hard unmovable being incorrectly animated
					var should_animate = tile.position.distance_to(target_pos) > 1
					if should_animate and not ("is_unmovable_hard" in tile and tile.is_unmovable_hard):
						gravity_tweens.append(tile.animate_to_position(target_pos))
					elif should_animate:
						# Safety: Hard unmovable shouldn't be animated but would have been
						print("[GRAVITY] WARNING: Almost animated hard unmovable at (", x, ",", y, ") - fixing position instantly")
						tile.position = target_pos

					tile_index += 1
				else:
					# No tile available - refill will create it
					print("[GRAVITY] Position (", x, ",", y, ") needs tile type ", tile_type, " but no visual tile available")
			# else position should be empty (0 or blocked) - leave tiles[x][y] as null

		# Step 4: Free any tiles that weren't reassigned (shouldn't happen in normal cases)
		if tile_index < visual_tiles_in_column.size():
			print("[GRAVITY] Column ", x, " has ", visual_tiles_in_column.size() - tile_index, " extra tiles - freeing them")
			for i in range(tile_index, visual_tiles_in_column.size()):
				var extra_tile = visual_tiles_in_column[i]
				if extra_tile and not extra_tile.is_queued_for_deletion():
					extra_tile.queue_free()

	if gravity_tweens.size() > 0:
		for tween in gravity_tweens:
			if tween != null:
				await tween.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.01).timeout

	# Check if any collectibles reached the bottom row
	_check_collectibles_at_bottom()

	print("[GRAVITY] done")

func _check_collectibles_at_bottom():
	"""Check if any collectibles have reached the bottom-most active cell in their column and collect them"""
	# For each column, determine the bottom-most active row (the last non-blocked cell)
	var collectibles_to_remove = []

	for x in range(GameManager.GRID_WIDTH):
		# Find the bottom-most active row for this column
		var last_active_row = -1
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if not GameManager.is_cell_blocked(x, y):
				last_active_row = y
				break

		# If no active cell in this column, skip
		if last_active_row == -1:
			continue

		# If there's no tile array entry for this column/row, skip
		if x >= tiles.size() or last_active_row >= tiles[x].size():
			continue

		var tile = tiles[x][last_active_row]
		# If tile exists and it's a collectible (and not already collected), gather it
		if tile and tile.is_collectible and not tile.collectible_collected_flag:
			print("[GameBoard] Collectible reached bottom-most active cell at (", x, ",", last_active_row, ")")
			collectibles_to_remove.append({"tile": tile, "pos": Vector2(x, last_active_row)})

	# If no collectibles to collect, return immediately
	if collectibles_to_remove.size() == 0:
		return

	# Collect each collectible with animation
	for item in collectibles_to_remove:
		var tile = item["tile"]
		var pos = item["pos"]

		# Store collectible type before we potentially free the tile
		var collectible_type = tile.collectible_type if tile else "coin"

		# Mark as collected
		if tile and tile.has_method("mark_collected"):
			tile.mark_collected()

		# Play collection sound
		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("coin_collect")

		# Create collection particles
		var particles = CPUParticles2D.new()
		particles.name = "CollectionParticles"
		particles.position = tile.position if tile else grid_to_world_position(pos)
		particles.emitting = true
		particles.one_shot = true
		particles.amount = 30
		particles.lifetime = 0.8
		particles.explosiveness = 1.0

		# Star burst effect
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.emission_sphere_radius = 10.0
		particles.direction = Vector2(0, -1)
		particles.spread = 180
		particles.gravity = Vector2(0, 200)
		particles.initial_velocity_min = 100.0
		particles.initial_velocity_max = 250.0
		particles.scale_amount_min = 2.0
		particles.scale_amount_max = 4.0

		# Golden color
		var gradient = Gradient.new()
		gradient.add_point(0.0, Color(1.0, 0.9, 0.2, 1))
		gradient.add_point(0.5, Color(1.0, 0.8, 0.0, 1))
		gradient.add_point(1.0, Color(1, 1, 1, 0))
		particles.color_ramp = gradient

		add_child(particles)

		# Animate tile flying to UI (top-right corner where collectible counter would be)
		if tile and is_instance_valid(tile):
			var viewport = get_viewport()
			var screen_size = viewport.get_visible_rect().size if viewport else Vector2(720, 1280)
			var target_pos = Vector2(screen_size.x - 100, 100)  # Top-right corner

			var tween = create_tween()
			tween.set_parallel(true)
			# Fly to target with bounce
			tween.tween_property(tile, "global_position", target_pos, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "scale", Vector2(0.5, 0.5), 0.6)
			tween.tween_property(tile, "modulate:a", 0.0, 0.4).set_delay(0.2)

			# Cleanup particles after animation
			get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

			await tween.finished
		else:
			# If tile was already freed, just wait a bit for particles
			await get_tree().create_timer(0.6).timeout
			particles.queue_free()

		# Remove from grid immediately
		tiles[int(pos.x)][int(pos.y)] = null
		GameManager.grid[int(pos.x)][int(pos.y)] = 0

		# Only free the tile if it's still valid (might have been freed elsewhere)
		if tile and is_instance_valid(tile):
			tile.queue_free()
		else:
			print("[GameBoard] Tile already freed at (", pos.x, ",", pos.y, ")")

		# Notify GameManager (without waiting for its gravity)
		if GameManager.has_method("collectible_landed_at"):
			# Don't await - we'll handle gravity ourselves
			GameManager.collectible_landed_at(pos, collectible_type)

		print("[GameBoard] Collected collectible with animation")

	# After all collectibles are collected, apply gravity and refill immediately
	# BUT: If level completion is pending, skip this to avoid race conditions
	if GameManager.pending_level_complete or GameManager.level_transitioning:
		print("[GameBoard] Level completion pending/transitioning - skipping post-collection cascade")
		return

	print("[GameBoard] Applying gravity after collectible collection")
	await animate_gravity()
	await animate_refill()

	# Check for new matches after refill
	var new_matches = GameManager.find_matches() if GameManager.has_method("find_matches") else []
	if new_matches.size() > 0:
		await process_cascade()



func animate_refill():
	var new_tile_positions = GameManager.fill_empty_spaces()
	var spawn_tweens = []
	var scale_factor = tile_size / 64.0

	# IMPORTANT: Also check for positions that have grid values but no visual tiles
	# This can happen during bonus moves when tiles are destroyed rapidly
	var positions_needing_tiles = []
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.is_cell_blocked(x, y):
				continue
			var grid_value = GameManager.get_tile_at(Vector2(x, y))
			if grid_value > 0:  # Position has a tile in the grid
				# Check if there's a visual tile
				var has_visual_tile = false
				if x < tiles.size() and tiles[x] and y < tiles[x].size():
					if tiles[x][y] != null and is_instance_valid(tiles[x][y]):
						has_visual_tile = true

				if not has_visual_tile:
					# Grid has a value but no visual tile - need to create one
					var pos_vec = Vector2(x, y)
					if not new_tile_positions.has(pos_vec):
						print("[REFILL] Position (", x, ",", y, ") has grid value ", grid_value, " but no visual tile - adding to spawn list")
						positions_needing_tiles.append(pos_vec)

	# Combine both lists
	for pos in positions_needing_tiles:
		if not new_tile_positions.has(pos):
			new_tile_positions.append(pos)

	# Create tiles ONLY for the new positions returned by fill_empty_spaces
	for pos in new_tile_positions:
		var x = int(pos.x)
		var y = int(pos.y)

		if GameManager.is_cell_blocked(x, y):
			continue

		# If there's already a tile at this position, free it first
		if tiles[x][y] != null:
			var old_tile = tiles[x][y]
			if old_tile and not old_tile.is_queued_for_deletion():
				print("[GameBoard] WARNING: Tile already exists at (", x, ",", y, ") - freeing old tile")
				old_tile.queue_free()
			tiles[x][y] = null

		# Now create the new tile
		var tile = tile_scene.instantiate()
		var tile_type = GameManager.get_tile_at(pos)

		# Check if this is a collectible tile
		var is_collectible = (tile_type == GameManager.COLLECTIBLE)

		if is_collectible:
			# Setup as collectible - use type 0 for visual (collectibles don't match)
			tile.setup(0, pos, scale_factor)
			# Configure as collectible after setup
			if tile.has_method("configure_collectible"):
				tile.configure_collectible(GameManager.collectible_type)
				print("[GameBoard] Spawned collectible at (", pos.x, ",", pos.y, ") type: ", GameManager.collectible_type)
		else:
			# Regular tile setup
			tile.setup(tile_type, pos, scale_factor)

		tile.position = grid_to_world_position(Vector2(x, -1))
		tile.connect("tile_clicked", _on_tile_clicked)
		tile.connect("tile_swiped", _on_tile_swiped)
		add_child(tile)
		tiles[x][y] = tile
		var target_pos = grid_to_world_position(pos)
		var pos_tween = tile.animate_to_position(target_pos)
		var spawn_tween = tile.animate_spawn()
		# Only add tweens that are not null (tile might be queued for deletion)
		if pos_tween:
			spawn_tweens.append(pos_tween)
		if spawn_tween:
			spawn_tweens.append(spawn_tween)

	# Wait for animations to complete - filter out any null tweens
	var valid_tweens = []
	for tw in spawn_tweens:
		if tw != null:
			valid_tweens.append(tw)

	if valid_tweens.size() > 0:
		await valid_tweens[0].finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.3).timeout

	print("GameManager.grid after refill:")
	for y in range(GameManager.GRID_HEIGHT):
		var row = []
		for x in range(GameManager.GRID_WIDTH):
			row.append(GameManager.grid[x][y])
		print(row)

# -----------------------------------------------------------------------------
# Deferred helper invoked by GameManager.call_deferred("deferred_gravity_then_refill")
# Ensures we run gravity+refill and then process any cascade matches safely.
# -----------------------------------------------------------------------------
func deferred_gravity_then_refill() -> void:
	# This method is intentionally not `async` so it can be called_deferred safely.
	# We create an async task and detach to avoid blocking the caller.
	_task_deferred_gravity_then_refill()

# Internal async worker
func _task_deferred_gravity_then_refill() -> void:
	print("[GameBoard] deferred_gravity_then_refill started")
	# If GameManager signals level transition, skip
	if GameManager.pending_level_complete or GameManager.level_transitioning:
		print("[GameBoard] deferred_gravity_then_refill aborted: level transition pending")
		return

	# Apply gravity visuals
	await animate_gravity()

	# Refill newly empty spaces
	await animate_refill()

	# After refill, check for new matches and process cascade if found
	var new_matches = GameManager.find_matches() if GameManager.has_method("find_matches") else []
	if new_matches and new_matches.size() > 0:
		print("[GameBoard] deferred_gravity_then_refill: new matches found, processing cascade")
		await process_cascade()
	else:
		# No matches - emit board_idle so other systems can continue
		print("[GameBoard] deferred_gravity_then_refill: no matches found, emitting board_idle")
		emit_signal("board_idle")

	print("[GameBoard] deferred_gravity_then_refill completed")

func _show_combo_text(match_count: int, positions: Array, combo_multiplier: int = 1):
	"""Show floating combo text for impressive matches"""
	if positions.size() == 0:
		return

	# Get screen/viewport center for positioning
	var viewport = get_viewport()
	if not viewport:
		return

	var screen_size = viewport.get_visible_rect().size
	var screen_center = screen_size / 2.0

	# Offset slightly up from center for better visibility
	var text_position = screen_center - Vector2(0, 100)

	# Create combo label
	var combo_label = Label.new()
	combo_label.z_index = 100
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# Determine combo message based on match size AND combo chain
	var combo_text = ""
	var combo_color = Color.WHITE

	# High combo chains get priority
	if combo_multiplier >= 5:
		combo_text = "INCREDIBLE!"
		combo_color = Color(1.0, 0.0, 1.0)  # Bright magenta
	elif combo_multiplier >= 4:
		combo_text = "AMAZING!"
		combo_color = Color(1.0, 0.2, 1.0)  # Magenta
	elif combo_multiplier >= 3:
		combo_text = "SUPER!"
		combo_color = Color(1.0, 0.5, 0.0)  # Orange
	elif combo_multiplier >= 2:
		combo_text = "COMBO!"
		combo_color = Color(0.2, 1.0, 0.2)  # Green
	# Otherwise, base on match size
	elif match_count >= 7:
		combo_text = "AMAZING!"
		combo_color = Color(1.0, 0.2, 1.0)  # Magenta
	elif match_count >= 6:
		combo_text = "SUPER!"
		combo_color = Color(1.0, 0.5, 0.0)  # Orange
	elif match_count >= 5:
		combo_text = "GREAT!"
		combo_color = Color(0.2, 1.0, 0.2)  # Green
	elif match_count >= 4:
		combo_text = "GOOD!"
		combo_color = Color(0.3, 0.7, 1.0)  # Blue
	else:
		combo_text = "NICE!"
		combo_color = Color(0.5, 0.5, 1.0)  # Light blue

	# Add combo multiplier to text if > 1
	if combo_multiplier > 1:
		combo_text = combo_text + " x" + str(combo_multiplier)

	combo_label.text = combo_text

	# Load and apply custom Bangers font for impactful display
	ThemeManager.apply_bangers_font(combo_label, 72)

	# Main text color
	combo_label.add_theme_color_override("font_color", combo_color)

	# Add black outline for contrast
	combo_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	combo_label.add_theme_constant_override("outline_size", 8)

	# Add glow/shadow effect using shadow color
	# Shadow is offset to create depth, with color matching the combo type
	var shadow_color = combo_color
	shadow_color.a = 0.6  # Semi-transparent for glow effect
	combo_label.add_theme_color_override("font_shadow_color", shadow_color)
	combo_label.add_theme_constant_override("shadow_offset_x", 0)
	combo_label.add_theme_constant_override("shadow_offset_y", 0)
	combo_label.add_theme_constant_override("shadow_outline_size", 20)  # Large shadow = glow

	combo_label.modulate = Color(1, 1, 1, 0)

	# Set fixed size for the label
	var label_width = 600.0
	var label_height = 100.0
	combo_label.size = Vector2(label_width, label_height)
	combo_label.custom_minimum_size = Vector2(label_width, label_height)

	# Position at screen center (horizontally centered, vertically at text_position.y)
	var centered_x = (screen_size.x - label_width) / 2.0
	combo_label.position = Vector2(centered_x, text_position.y)

	# Set pivot for scaling animation (center of label)
	combo_label.pivot_offset = Vector2(label_width / 2.0, label_height / 2.0)

	add_child(combo_label)

	# Enhanced animation - dramatic pop-in with bounce and glow pulse
	var tween = create_tween()

	# Phase 1: Pop in (parallel - fade + scale + slight rotation)
	tween.set_parallel(true)
	tween.tween_property(combo_label, "modulate", Color.WHITE, 0.2)
	tween.tween_property(combo_label, "scale", Vector2(1.4, 1.4), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(combo_label, "rotation_degrees", 5, 0.1)

	# Phase 2: Settle down (sequential)
	tween.set_parallel(false)
	tween.tween_property(combo_label, "rotation_degrees", -3, 0.08)
	tween.tween_property(combo_label, "rotation_degrees", 0, 0.08)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Phase 3: Hold with subtle pulse (parallel)
	tween.set_parallel(true)
	var pulse_tween = tween.tween_property(combo_label, "scale", Vector2(1.05, 1.05), 0.3)
	pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Phase 4: Fade out with slight upward movement
	tween.set_parallel(false)
	tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.2).set_delay(0.2)
	tween.set_parallel(true)
	tween.tween_property(combo_label, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(combo_label, "position:y", combo_label.position.y - 30, 0.3)
	tween.tween_property(combo_label, "scale", Vector2(1.2, 1.2), 0.3)

	# Cleanup after animation
	tween.finished.connect(combo_label.queue_free)

func _apply_screen_shake(duration: float, intensity: float):
	"""Apply screen shake effect for dramatic moments"""
	var original_position = position
	var shake_timer = 0.0
	var shake_amount = intensity

	while shake_timer < duration:
		position = original_position + Vector2(
			randf_range(-shake_amount, shake_amount),
			randf_range(-shake_amount, shake_amount)
		)
		shake_timer += get_process_delta_time()
		await get_tree().process_frame

	# Reset to original position
	position = original_position

func _create_lightning_beam_horizontal(row: int, color: Color = Color.YELLOW):
	"""Create a horizontal lightning beam effect across a row"""
	print("[GameBoard] Creating horizontal lightning beam for row ", row, " with color ", color)

	var beam = Line2D.new()
	beam.name = "LightningBeamH"
	beam.z_index = 100  # Increased from 50 to ensure it's on top
	beam.visible = true  # Explicitly set visible

	# Calculate start and end positions
	var start_pos = grid_to_world_position(Vector2(0, row))
	var end_pos = grid_to_world_position(Vector2(GameManager.GRID_WIDTH - 1, row))

	print("[GameBoard] Beam start pos: ", start_pos, " end pos: ", end_pos)

	# Add points for the lightning path
	beam.add_point(Vector2(start_pos.x - tile_size/2, start_pos.y))

	# Add zigzag points for lightning effect
	var num_segments = 8
	var segment_length = (end_pos.x - start_pos.x) / num_segments
	for i in range(1, num_segments):
		var x = start_pos.x + (i * segment_length)
		var y = start_pos.y + randf_range(-tile_size * 0.3, tile_size * 0.3)
		beam.add_point(Vector2(x, y))

	beam.add_point(Vector2(end_pos.x + tile_size/2, end_pos.y))

	print("[GameBoard] Beam has ", beam.get_point_count(), " points")

	# Beam appearance - sleeker and thinner
	beam.width = 12  # Reduced from 25
	beam.default_color = color
	beam.modulate = Color(1, 1, 1, 0)
	beam.antialiased = true
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.joint_mode = Line2D.LINE_JOINT_ROUND

	add_child(beam)
	print("[GameBoard] Beam added as child, parent: ", get_path())

	# Animate the beam
	var tween = create_tween()
	tween.set_parallel(true)

	# Flash in bright and wider
	tween.tween_property(beam, "modulate", Color(3, 3, 3, 1), 0.05)  # Even brighter
	tween.tween_property(beam, "width", 20, 0.05)  # Reduced from 40

	tween.set_parallel(false)

	# Pulse effect - moderate width
	tween.tween_property(beam, "width", 15, 0.1)  # Reduced from 30
	tween.tween_property(beam, "width", 18, 0.1)  # Reduced from 35

	# Fade out
	tween.tween_property(beam, "modulate", Color(1, 1, 1, 0), 0.2)

	# Cleanup - connect directly to queue_free
	tween.finished.connect(beam.queue_free)

	return tween

func _create_lightning_beam_vertical(col: int, color: Color = Color.CYAN):
	"""Create a vertical lightning beam effect down a column"""
	print("[GameBoard] Creating vertical lightning beam for column ", col, " with color ", color)

	var beam = Line2D.new()
	beam.name = "LightningBeamV"
	beam.z_index = 100  # Increased from 50 to ensure it's on top
	beam.visible = true  # Explicitly set visible

	# Calculate start and end positions
	var start_pos = grid_to_world_position(Vector2(col, 0))
	var end_pos = grid_to_world_position(Vector2(col, GameManager.GRID_HEIGHT - 1))

	print("[GameBoard] Beam start pos: ", start_pos, " end pos: ", end_pos)

	# Add points for the lightning path
	beam.add_point(Vector2(start_pos.x, start_pos.y - tile_size/2))

	# Add zigzag points for lightning effect
	var num_segments = 8
	var segment_length = (end_pos.y - start_pos.y) / num_segments
	for i in range(1, num_segments):
		var x = start_pos.x + randf_range(-tile_size * 0.3, tile_size * 0.3)
		var y = start_pos.y + (i * segment_length)
		beam.add_point(Vector2(x, y))

	beam.add_point(Vector2(end_pos.x, end_pos.y + tile_size/2))

	print("[GameBoard] Beam has ", beam.get_point_count(), " points")

	# Beam appearance - sleeker and thinner
	beam.width = 12  # Reduced from 25
	beam.default_color = color
	beam.modulate = Color(1, 1, 1, 0)
	beam.antialiased = true
	beam.begin_cap_mode = Line2D.LINE_CAP_ROUND
	beam.end_cap_mode = Line2D.LINE_CAP_ROUND
	beam.joint_mode = Line2D.LINE_JOINT_ROUND

	add_child(beam)
	print("[GameBoard] Beam added as child, parent: ", get_path())

	# Animate the beam
	var tween = create_tween()
	tween.set_parallel(true)

	# Flash in bright and wider
	tween.tween_property(beam, "modulate", Color(3, 3, 3, 1), 0.05)  # Even brighter
	tween.tween_property(beam, "width", 20, 0.05)  # Reduced from 40

	tween.set_parallel(false)

	# Pulse effect - moderate width
	tween.tween_property(beam, "width", 15, 0.1)  # Reduced from 30
	tween.tween_property(beam, "width", 18, 0.1)  # Reduced from 35

	# Fade out
	tween.tween_property(beam, "modulate", Color(1, 1, 1, 0), 0.2)

	# Cleanup - connect directly to queue_free
	tween.finished.connect(beam.queue_free)

	return tween

func _destroy_tiles_immediately(positions: Array):
	"""Destroy tiles immediately after lightning beam - handles unmovables properly"""
	if positions.size() == 0:
		return

	print("[GameBoard] _destroy_tiles_immediately: processing ", positions.size(), " positions")

	# Highlight briefly
	await highlight_special_activation(positions)

	# Count tiles for scoring BEFORE processing/animating
	# This ensures we count them even if instances become invalid during animation
	var scoring_count = 0
	for clear_pos in positions:
		var t = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		# Count any non-empty, non-blocked tile for scoring
		# Special tiles (7-9), regular tiles (1-6), and spreaders (12) all count
		# Collectibles (10) don't count (they're handled separately)
		# Unmovables have grid value 0 but we'll count them if they get destroyed
		if t > 0 and t != GameManager.COLLECTIBLE:
			scoring_count += 1
			print("[SCORING] Will score tile at (", gx, ",", gy, ") type ", t)

	print("[GameBoard] Pre-counted ", scoring_count, " tiles for scoring")

	# Animate destruction (skips hard unmovables automatically)
	await animate_destroy_tiles(positions)

	# Process each position for game logic (grid clearing, unmovable hits, spreader tracking)
	for clear_pos in positions:
		var t = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		print("[DESTROY_IMMEDIATE] Processing position (", gx, ",", gy, ") - grid value before: ", t)

		# Get tile instance
		var tile_instance = null
		if tiles and gx < tiles.size() and tiles[gx] and gy < tiles[gx].size():
			tile_instance = tiles[gx][gy]

		# Validate instance
		if not tile_instance or not is_instance_valid(tile_instance):
			# Handle missing instance - this can happen if the tile was already freed during animate_destroy_tiles
			# We should still clear the grid value to 0
			print("[DESTROY_IMMEDIATE] No valid tile instance at (", gx, ",", gy, ") - clearing grid anyway")

			# If the missing instance was a spreader, make sure we still report it
			if t == GameManager.SPREADER:
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)
					print("[SPREADER] Missing-instance spreader destroyed at (", gx, ",", gy, ") - Remaining: ", GameManager.spreader_count)

			if tile_instance and "is_unmovable_hard" in tile_instance and tile_instance.is_unmovable_hard:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)

			# Always clear the grid, regardless of whether it was an unmovable or not
			GameManager.grid[gx][gy] = 0
			print("[DESTROY_IMMEDIATE] Grid cleared (no instance) - now value: ", GameManager.grid[gx][gy])
			continue

		# Check if hard unmovable
		if "is_unmovable_hard" in tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)

				# Handle reveals
				var is_coll = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_check = tile_instance.tile_type if "tile_type" in tile_instance else 0
				if is_coll:
					GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
					tiles[gx][gy] = tile_instance
				elif tile_type_check > 0:
					GameManager.grid[gx][gy] = tile_type_check
					tiles[gx][gy] = tile_instance
				else:
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion():
						tile_instance.queue_free()
					tiles[gx][gy] = null
		else:
			# Regular tile or spreader or SPECIAL TILE
			if t == GameManager.SPREADER:
				# Report via central method so all side-effects (signals, EventBus) are handled
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)
					print("[SPREADER] Special-destroyed spreader at (", gx, ",", gy, ") - Remaining: ", GameManager.spreader_count)
			print("[DESTROY_IMMEDIATE] Clearing grid at (", gx, ",", gy, ") - was type ", t)
			GameManager.grid[gx][gy] = 0
			print("[DESTROY_IMMEDIATE] Grid cleared - now value: ", GameManager.grid[gx][gy])

	# Check spreader objectives
	if GameManager.use_spreader_objective:
		GameManager.emit_signal("spreaders_changed", GameManager.spreader_count)
		if GameManager.spreader_count == 0:
			if not GameManager.pending_level_complete and not GameManager.level_transitioning:
				GameManager.last_level_won = true
				GameManager.last_level_score = GameManager.score
				GameManager.last_level_target = 0
				GameManager.last_level_number = GameManager.level
				GameManager.last_level_moves_left = GameManager.moves_left
				GameManager.pending_level_complete = true
				GameManager._attempt_level_complete()

	# Add score for cleared tiles
	if scoring_count > 0:
		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
			GameManager.add_score(points)

	print("[GameBoard] _destroy_tiles_immediately: complete, scored ", scoring_count, " tiles")

func _create_row_clear_effect(row: int):
	"""Create visual effect for clearing an entire row"""
	print("[GameBoard] Creating row clear lightning effect for row ", row)

	# Create multiple lightning beams with slight offset for more impact
	_create_lightning_beam_horizontal(row, Color(1.0, 1.0, 0.3))  # Yellow
	await get_tree().create_timer(0.02).timeout
	_create_lightning_beam_horizontal(row, Color(1.0, 0.8, 0.0))  # Orange-yellow

	# Add particles along the row
	for x in range(GameManager.GRID_WIDTH):
		if not GameManager.is_cell_blocked(x, row):
			var pos = grid_to_world_position(Vector2(x, row))
			_create_impact_particles(pos, Color.YELLOW)

func _create_column_clear_effect(col: int):
	"""Create visual effect for clearing an entire column"""
	print("[GameBoard] Creating column clear lightning effect for column ", col)

	# Create multiple lightning beams with slight offset for more impact
	_create_lightning_beam_vertical(col, Color(0.3, 0.8, 1.0))  # Cyan
	await get_tree().create_timer(0.02).timeout
	_create_lightning_beam_vertical(col, Color(0.5, 1.0, 1.0))  # Bright cyan

	# Add particles along the column
	for y in range(GameManager.GRID_HEIGHT):
		if not GameManager.is_cell_blocked(col, y):
			var pos = grid_to_world_position(Vector2(col, y))
			_create_impact_particles(pos, Color.CYAN)

func _create_impact_particles(pos: Vector2, color: Color):
	"""Create small impact particles at a position"""
	var particles = CPUParticles2D.new()
	particles.position = pos
	particles.emitting = true
	particles.one_shot = true
	particles.amount = 8
	particles.lifetime = 0.4
	particles.explosiveness = 1.0
	particles.spread = 180
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 0.8
	particles.scale_amount_max = 1.5
	particles.color = color

	add_child(particles)

	# Cleanup - connect directly to queue_free
	get_tree().create_timer(0.6).timeout.connect(particles.queue_free)

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

	# CRITICAL: Hide board immediately to prevent old overlay from showing during transition
	# The transition screen should show cleanly without the game board visible
	hide_board_group()
	print("[GameBoard] Board group hidden for clean transition to next level")

	# CRITICAL: Also hide UI elements (booster panel, HUD) to prevent showing old level state
	var game_ui = get_node_or_null("../GameUI")
	if game_ui and game_ui.has_method("hide_gameplay_ui"):
		game_ui.hide_gameplay_ui()
		print("[GameBoard] UI elements hidden for clean transition")

	# Actions to perform on level completion, e.g. showing a summary, transitioning to next level, etc.

func _on_level_loaded():
	print("[GameBoard] _on_level_loaded called - initializing visuals")

	# Hide entire board group (tiles, borders, AND overlay) immediately to prevent blank screen flash
	hide_board_group()
	print("[GameBoard] Board group hidden - will be shown after tiles are created")

	# Safety: clear any lingering processing/transition flags so board is interactive
	if typeof(GameManager) != TYPE_NIL:
		# Defensive resets - only change flags if they exist
		GameManager.processing_moves = false
		GameManager.level_transitioning = false
		GameManager.pending_level_complete = false
		GameManager.pending_level_failed = false
		GameManager.in_bonus_conversion = false
		GameManager.reset_combo()
		print("[GameBoard] Safety reset: processing_moves/level_transitioning/pending flags cleared")

	# CRITICAL: Clean up old tile area overlay from previous level
	# This prevents visual artifacts from old theme showing through
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		print("[GameBoard] Cleaning up old tile area overlay from previous level")
		tile_area_overlay.queue_free()
		tile_area_overlay = null

	# Recalculate layout and setup visuals immediately (we rely on create_visual_grid/draw_board_borders guards)
	calculate_responsive_layout()
	setup_background()

	# CRITICAL: Hide the newly created tile_area_overlay immediately
	# setup_background() calls setup_tile_area_overlay() which creates it visible by default
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		tile_area_overlay.visible = false
		print("[GameBoard] Hid newly created tile_area_overlay to prevent flash")

	setup_background_image()

	# Create visual grid and draw borders (deferred to avoid parent busy errors)
	if has_method("create_visual_grid"):
		call_deferred("create_visual_grid")
	else:
		print("[GameBoard] Warning: create_visual_grid() method not found")

	call_deferred("draw_board_borders")

	# Ensure tile overlay is visible (if created)
	if tile_area_overlay:
		tile_area_overlay.visible = true

	# Hide skip hint if shown
	if skip_bonus_label:
		hide_skip_bonus_hint()

	# Clear any selected tile
	if selected_tile:
		selected_tile.set_selected(false)
		selected_tile = null

	print("[GameBoard] _on_level_loaded completed")


func _spawn_level_collectibles():
	"""Deferred call to spawn collectibles after grid is ready"""
	if GameManager.has_method("spawn_collectibles_for_targets"):
		GameManager.spawn_collectibles_for_targets()
		print("[GameBoard] Spawned collectibles for level")

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

func update_tile_visual(grid_pos: Vector2, new_type: int):
	"""Update a tile's visual appearance to match a new type
	Used for bonus moves conversion"""
	if grid_pos.x < 0 or grid_pos.x >= GameManager.GRID_WIDTH:
		return
	if grid_pos.y < 0 or grid_pos.y >= GameManager.GRID_HEIGHT:
		return

	var tile = tiles[int(grid_pos.x)][int(grid_pos.y)]
	if not tile:
		return

	# Update the tile's texture to match the new type
	if tile.has_method("update_type"):
		tile.update_type(new_type)

		# Add a flash effect to draw attention
		var tween = create_tween()
		tween.tween_property(tile, "modulate", Color(3, 3, 1, 1), 0.1)
		tween.tween_property(tile, "modulate", Color.WHITE, 0.2)

		# Play transformation sound
		AudioManager.play_sfx("special_create")

		print("[GameBoard] Updated tile at %s to type %d (special)" % [grid_pos, new_type])

func show_skip_bonus_hint():
	"""Show 'Tap to Skip' message during bonus phase"""
	if skip_bonus_label:
		skip_bonus_label.visible = true
		skip_bonus_active = true
		return

	# Create skip hint label
	skip_bonus_label = Label.new()
	skip_bonus_label.name = "SkipBonusLabel"
	skip_bonus_label.text = "TAP TO SKIP ⏩"
	skip_bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	skip_bonus_label.add_theme_font_size_override("font_size", 32)
	skip_bonus_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))  # Yellow

	# Position below the board
	var viewport_size = get_viewport().get_visible_rect().size
	var board_bottom = grid_offset.y + (tile_size * GameManager.GRID_HEIGHT)
	skip_bonus_label.position = Vector2(viewport_size.x / 2 - 150, board_bottom + 20)
	skip_bonus_label.custom_minimum_size = Vector2(300, 60)

	add_child(skip_bonus_label)
	skip_bonus_active = true

	# Create pulsing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(skip_bonus_label, "modulate:a", 0.5, 0.5)
	tween.tween_property(skip_bonus_label, "modulate:a", 1.0, 0.5)

	print("[GameBoard] Showing skip bonus hint")

func hide_skip_bonus_hint():
	"""Hide 'Tap to Skip' message"""
	if skip_bonus_label:
		skip_bonus_label.visible = false
	skip_bonus_active = false
	print("[GameBoard] Hiding skip bonus hint")

func _input(event):
	"""Handle input for skipping bonus animation"""
	if skip_bonus_active and (event is InputEventScreenTouch or event is InputEventMouseButton):
		if event.pressed:
			print("[GameBoard] Screen tapped during bonus - requesting skip")
			GameManager.skip_bonus_animation()
			hide_skip_bonus_hint()
			# Consume the event to prevent it from propagating to other input handlers
			get_viewport().set_input_as_handled()

func _on_tile_clicked(tile):
	print("GameBoard received tile_clicked signal from tile at ", tile.grid_position)

	# Prevent selecting or swapping unmovable tiles
	if tile and tile.is_unmovable:
		print("[GameBoard] Clicked tile is unmovable, ignoring selection/swap")
		return

	if GameManager.processing_moves:
		print("GameBoard: Move processing blocked")
		return

	if GameManager.level_transitioning:
		print("GameBoard: Level transitioning, clicks blocked")
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

	# Prevent swiping unmovable tiles
	if tile and tile.is_unmovable:
		print("[GameBoard] Swiped tile is unmovable, ignoring swipe")
		return

	if GameManager.processing_moves:
		print("GameBoard: Move processing blocked")
		return

	if GameManager.level_transitioning:
		print("GameBoard: Level transitioning, swipes blocked")
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

	# Prevent swiping to unmovable tiles
	if target_tile and target_tile.is_unmovable:
		print("[GameBoard] Target tile for swipe is unmovable, ignoring swipe")
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

	# Attempt to perform swap in game logic; if disallowed, abort with feedback
	var swapped = GameManager.swap_tiles(pos1, pos2)
	if not swapped:
		print("perform_swap: GameManager.swap_tiles returned false - swap not allowed")
		# Play invalid sound and flash tiles to indicate invalid move
		AudioManager.play_sfx("invalid_move")
		var tw_bad = create_tween()
		tw_bad.tween_property(tile1, "position", tile1.position + Vector2(6,0), 0.06)
		tw_bad.tween_property(tile1, "position", tile1.position, 0.08)
		tw_bad.tween_property(tile2, "position", tile2.position + Vector2(-6,0), 0.06)
		tw_bad.tween_property(tile2, "position", tile2.position, 0.08)
		if tw_bad:
			await tw_bad.finished
		GameManager.processing_moves = false
		print("perform_swap: processing_moves = false (swap denied)")
		emit_signal("move_completed")
		return

	# Play swap sound effect
	AudioManager.play_sfx("tile_swap")

	# Animate swap
	var target_pos1 = grid_to_world_position(pos2)
	var target_pos2 = grid_to_world_position(pos1)

	var tween1 = tile1.animate_swap_to(target_pos1)
	var tween2 = tile2.animate_swap_to(target_pos2)

	# Update grid references (tiles array) — GameManager.grid already updated by swap_tiles
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

		# After all cascades complete, check if spreaders should spread
		if GameManager.has_method("check_and_spread_tiles"):
			print("[GameBoard] Cascades complete - checking spreader spreading")
			GameManager.check_and_spread_tiles()

		GameManager.processing_moves = false
		print("perform_swap: processing_moves = false (from cascade end)")
		emit_signal("move_completed")
		return
	else:
		# No matches — revert swap in data and visuals
		GameManager.swap_tiles(pos1, pos2)  # revert logical swap

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

	# After cascade loop exits, ensure no empty cells remain
	# (sometimes gravity+refill in the last iteration leaves empties that need one more pass)
	print("[CASCADE] Cascade loop exited - checking for remaining empty cells...")
	var has_empties = false
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y) and GameManager.grid[x][y] == 0:
				has_empties = true
				print("[CASCADE] Found empty cell at (", x, ",", y, ")")
				break
		if has_empties:
			break

	if has_empties:
		print("[CASCADE] Empty cells found - running final gravity+refill")
		await animate_gravity()
		await animate_refill()
		print("[CASCADE] Final refill complete")
	else:
		print("[CASCADE] No empty cells found - cascade complete")

	# Always reset processing_moves and combo, even if an error occurred
	GameManager.processing_moves = false
	GameManager.reset_combo()
	print("=== Cascade process complete, processing_moves forced to false ===")

	# Short buffer to ensure all last tweens/deferred calls have finished before marking board idle
	if get_tree() != null:
		await get_tree().create_timer(0.2).timeout

	# Safety check: If we're in bonus conversion and cascade took too long, skip remaining bonus
	if GameManager.in_bonus_conversion and cascade_depth > 15:
		print("[CASCADE] ⚠️ WARNING: Deep cascade during bonus (%d iterations) - may need to skip remaining bonus" % cascade_depth)

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
	var target_pos1 = grid_to_world_position(Vector2(x2, y2))
	var target_pos2 = grid_to_world_position(Vector2(x1, y1))

	var tween1 = tile1.animate_swap_to(target_pos1)
	var tween2 = tile2.animate_swap_to(target_pos2)

	# Update grid references
	tiles[x1][y1] = tile2
	tiles[x2][y2] = tile1
	tile1.grid_position = Vector2(x2, y2)
	tile2.grid_position = Vector2(x1, y1)

	if tween1:
		await tween1.finished
	if tween2:
		await tween2.finished

	# CRITICAL: Check if collectibles reached bottom after swap
	_check_collectibles_at_bottom()

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
	# Handle wave1 unmovable/reporting
	var scoring_count_wave1 = 0
	for pos in wave1:
		var gx = int(pos.x)
		var gy = int(pos.y)

		# Check if this is a hard unmovable
		var is_unmovable = false
		if tiles and gx < tiles.size() and tiles[gx] and gy < tiles[gx].size():
			var tile_inst = tiles[gx][gy]
			if tile_inst and "is_unmovable_hard" in tile_inst and tile_inst.is_unmovable_hard:
				is_unmovable = true

		if is_unmovable:
			GameManager.report_unmovable_destroyed(pos)
		else:
			GameManager.grid[gx][gy] = 0
			scoring_count_wave1 += 1

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
	# Ensure scoring_count variables exist in outer scope for aggregation
	var scoring_count_wave2 = 0
	var scoring_count_wave3 = 0

	if wave2.size() > 0:
		await highlight_special_activation(wave2)
		await animate_destroy_tiles(wave2)
		# Handle wave2 unmovable/reporting
		for pos in wave2:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			scoring_count_wave2 += 1

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
			# Handle wave3 unmovable/reporting
			for pos in wave3:
				GameManager.grid[int(pos.x)][int(pos.y)] = 0
				scoring_count_wave3 += 1

	# Calculate total score
	var total_scoring = scoring_count_wave1 + scoring_count_wave2 + scoring_count_wave3
	var points = GameManager.calculate_points(total_scoring)
	if points > 0:
		GameManager.add_score(points)

	await animate_gravity()
	await animate_refill()
	await process_cascade()

	GameManager.processing_moves = false
	print("[GameBoard] Chain reaction booster complete - destroyed ", total_scoring, " tiles")

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

		# Handle unmovables specially and score only regular tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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
		# Create lightning beam effects for each row or column
		if direction == "horizontal":
			for row_offset in range(-1, 2):
				var target_y = center_y + row_offset
				if target_y >= 0 and target_y < GameManager.GRID_HEIGHT:
					_create_lightning_beam_horizontal(target_y, Color(1.0, 0.9, 0.2))
					await get_tree().create_timer(0.05).timeout
		elif direction == "vertical":
			for col_offset in range(-1, 2):
				var target_x = center_x + col_offset
				if target_x >= 0 and target_x < GameManager.GRID_WIDTH:
					_create_lightning_beam_vertical(target_x, Color(0.4, 0.9, 1.0))
					await get_tree().create_timer(0.05).timeout

		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		# Handle unmovables specially and score only regular tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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

		# Handle unmovables specially and score only regular tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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

		# Clear grid positions and count scoring tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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
		# Create lightning beam effect across the row
		await _create_row_clear_effect(row)

		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		# Handle unmovables specially and score only regular tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			var t = GameManager.get_tile_at(pos)
			var gx = int(pos.x)
			var gy = int(pos.y)

			# Get the tile instance to check if it's a hard unmovable
			var tile_instance = null
			if gx < tiles.size() and gy < tiles[gx].size():
				tile_instance = tiles[gx][gy]

			# Check if this is a hard unmovable tile that needs to take a hit
			if tile_instance and tile_instance.is_unmovable_hard:
				print("[GameBoard] Row clear booster hitting hard unmovable at ", pos)
				var destroyed = tile_instance.take_hit(1)
				if destroyed:
					print("[GameBoard] Hard tile destroyed, may have revealed something")
					# If destroyed, the tile has already transformed if it had a reveal
					# Update the grid to match what the tile became
					if tile_instance.is_collectible:
						GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
						# Ensure tile is still in tiles array at this position
						tiles[gx][gy] = tile_instance
						print("[GameBoard] Revealed collectible at ", pos, " - keeping in tiles array")
					elif tile_instance.type > 0:
						GameManager.grid[gx][gy] = tile_instance.type
						# Ensure tile is still in tiles array at this position
						tiles[gx][gy] = tile_instance
						print("[GameBoard] Revealed tile type ", tile_instance.type, " at ", pos)
					else:
						# Tile was destroyed without reveal, clear it
						GameManager.grid[gx][gy] = 0
						if not tile_instance.is_queued_for_deletion():
							tile_instance.queue_free()
						tiles[gx][gy] = null
						scoring_count += 1
				else:
					print("[GameBoard] Row clear booster hitting hard unmovable at (", gx, ",", gy, ") - not destroyed")
			else:
				GameManager.grid[gx][gy] = 0
				scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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
		# Create lightning beam effect down the column
		await _create_column_clear_effect(column)

		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)

		# Handle unmovables specially and score only regular tiles
		var scoring_count = 0
		for pos in positions_to_clear:
			var t = GameManager.get_tile_at(pos)
			var gx = int(pos.x)
			var gy = int(pos.y)

			# Get the tile instance to check if it's a hard unmovable
			var tile_instance = null
			if gx < tiles.size() and gy < tiles[gx].size():
				tile_instance = tiles[gx][gy]

			# Check if this is a hard unmovable tile that needs to take a hit
			if tile_instance and tile_instance.is_unmovable_hard:
				print("[GameBoard] Column clear booster hitting hard unmovable at ", pos)
				var destroyed = tile_instance.take_hit(1)
				if destroyed:
					print("[GameBoard] Hard tile destroyed, may have revealed something")
					# If destroyed, the tile has already transformed if it had a reveal
					# Update the grid to match what the tile became
					if tile_instance.is_collectible:
						GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
						# Ensure tile is still in tiles array at this position
						tiles[gx][gy] = tile_instance
						print("[GameBoard] Revealed collectible at ", pos, " - keeping in tiles array")
					elif tile_instance.type > 0:
						GameManager.grid[gx][gy] = tile_instance.type
						# Ensure tile is still in tiles array at this position
						tiles[gx][gy] = tile_instance
						print("[GameBoard] Revealed tile type ", tile_instance.type, " at ", pos)
					else:
						# Tile was destroyed without reveal, clear it
						GameManager.grid[gx][gy] = 0
						if not tile_instance.is_queued_for_deletion():
							tile_instance.queue_free()
						tiles[gx][gy] = null
						scoring_count += 1
				else:
					print("[GameBoard] Column clear booster hitting hard unmovable at (", gx, ",", gy, ") - not destroyed")
			else:
				GameManager.grid[gx][gy] = 0
				scoring_count += 1

		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
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

	# Emit EventBus event for narrative system (DLC levels)
	EventBus.emit_special_tile_activated("tile_%d_%d" % [int(pos.x), int(pos.y)], {
		"position": pos,
		"tile_type": tile_type,
		"level": GameManager.level
	})

	# Process special tile activation with IMMEDIATE tile destruction
	# This makes lightning feel more impactful - tiles destroyed as beam hits them
	var positions_to_clear = []
	var special_tiles_to_activate = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		# Create horizontal lightning beam
		print("[GameBoard] Creating lightning for horizontal arrow at row ", int(pos.y))
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))

		# Collect positions in this row AND check for special tiles
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				var check_pos = Vector2(x, pos.y)
				var tile_at_pos = GameManager.get_tile_at(check_pos)
				if tile_at_pos != GameManager.COLLECTIBLE:
					positions_to_clear.append(check_pos)
					# Check for special tiles (before destruction)
					if check_pos != pos and tile_at_pos >= 7 and tile_at_pos <= 9:
						print("[CHAIN] Found special tile type ", tile_at_pos, " at (", x, ",", pos.y, ") - will chain activate")
						special_tiles_to_activate.append({"pos": check_pos, "type": tile_at_pos})

		# Destroy tiles IMMEDIATELY after lightning appears
		await _destroy_tiles_immediately(positions_to_clear)

	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		# Create vertical lightning beam
		print("[GameBoard] Creating lightning for vertical arrow at column ", int(pos.x))
		_create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))

		# Collect positions in this column AND check for special tiles
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				var check_pos = Vector2(pos.x, y)
				var tile_at_pos = GameManager.get_tile_at(check_pos)
				if tile_at_pos != GameManager.COLLECTIBLE:
					positions_to_clear.append(check_pos)
					# Check for special tiles (before destruction)
					if check_pos != pos and tile_at_pos >= 7 and tile_at_pos <= 9:
						print("[CHAIN] Found special tile type ", tile_at_pos, " at (", pos.x, ",", y, ") - will chain activate")
						special_tiles_to_activate.append({"pos": check_pos, "type": tile_at_pos})

		# Destroy tiles IMMEDIATELY after lightning appears
		await _destroy_tiles_immediately(positions_to_clear)

	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		print("[GameBoard] Creating cross lightning for four-way arrow at ", pos)

		# Create horizontal beam
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		var horizontal_positions = []
		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				var check_pos = Vector2(x, pos.y)
				var tile_at_pos = GameManager.get_tile_at(check_pos)
				if tile_at_pos != GameManager.COLLECTIBLE:
					horizontal_positions.append(check_pos)
					positions_to_clear.append(check_pos)
					# Check for special tiles (before destruction)
					if check_pos != pos and tile_at_pos >= 7 and tile_at_pos <= 9:
						print("[CHAIN] Found special tile type ", tile_at_pos, " at (", x, ",", pos.y, ") - will chain activate")
						special_tiles_to_activate.append({"pos": check_pos, "type": tile_at_pos})
		await _destroy_tiles_immediately(horizontal_positions)

		# Small delay before vertical beam
		await get_tree().create_timer(0.05).timeout

		# Create vertical beam
		_create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))  # Magenta
		var vertical_positions = []
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				var check_pos = Vector2(pos.x, y)
				var tile_at_pos = GameManager.get_tile_at(check_pos)
				if tile_at_pos != GameManager.COLLECTIBLE:
					if not positions_to_clear.has(check_pos):
						vertical_positions.append(check_pos)
						positions_to_clear.append(check_pos)
						# Check for special tiles (before destruction)
						if check_pos != pos and tile_at_pos >= 7 and tile_at_pos <= 9:
							print("[CHAIN] Found special tile type ", tile_at_pos, " at (", pos.x, ",", y, ") - will chain activate")
							special_tiles_to_activate.append({"pos": check_pos, "type": tile_at_pos})
		await _destroy_tiles_immediately(vertical_positions)

	print("Cleared ", positions_to_clear.size(), " tiles total, found ", special_tiles_to_activate.size(), " special tiles to chain")

	# Use a move for activating special tile (but not during bonus conversion)
	if GameManager.has_method("use_move") and not GameManager.in_bonus_conversion:
		GameManager.use_move()
		print("[GameBoard] activate_special_tile: used a move, moves_left now: ", GameManager.moves_left)
	elif GameManager.in_bonus_conversion:
		print("[GameBoard] activate_special_tile: skipping use_move() because in_bonus_conversion=true")


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

	# Note: processing_moves is reset inside process_cascade()
	print("activate_special_tile: complete (processing_moves reset by process_cascade)")

# Activate special tile as part of a chain reaction
func activate_special_tile_chain(pos: Vector2, tile_type: int):
	print("Chain-activating special tile type ", tile_type, " at ", pos)

	var positions_to_clear = []

	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		# Create horizontal lightning beam
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await get_tree().create_timer(0.1).timeout  # Brief delay for visual effect

		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				var tile_at_pos = GameManager.get_tile_at(Vector2(x, pos.y))
				# Skip collectibles - they should not be destroyed by special tiles
				if tile_at_pos != GameManager.COLLECTIBLE:
					positions_to_clear.append(Vector2(x, pos.y))

	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		# Create vertical lightning beam
		_create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await get_tree().create_timer(0.1).timeout  # Brief delay for visual effect

		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				var tile_at_pos = GameManager.get_tile_at(Vector2(pos.x, y))
				# Skip collectibles - they should not be destroyed by special tiles
				if tile_at_pos != GameManager.COLLECTIBLE:
					positions_to_clear.append(Vector2(pos.x, y))

	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		# Create both horizontal and vertical lightning beams with slight delay
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))  # Magenta
		await get_tree().create_timer(0.05).timeout
		_create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))  # Magenta
		await get_tree().create_timer(0.1).timeout  # Brief delay for visual effect

		for x in range(GameManager.GRID_WIDTH):
			if not GameManager.is_cell_blocked(x, int(pos.y)):
				var tile_at_pos = GameManager.get_tile_at(Vector2(x, pos.y))
				# Skip collectibles - they should not be destroyed by special tiles
				if tile_at_pos != GameManager.COLLECTIBLE:
					positions_to_clear.append(Vector2(x, pos.y))
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(int(pos.x), y):
				var tile_at_pos = GameManager.get_tile_at(Vector2(pos.x, y))
				# Skip collectibles - they should not be destroyed by special tiles
				if tile_at_pos != GameManager.COLLECTIBLE:
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

	# Clear tiles but handle unmovables specially
	var scoring_count = 0
	for clear_pos in positions_to_clear:
		var t = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		# Get the tile instance to check if it's a hard unmovable
		var tile_instance = null
		if not tiles or gx >= tiles.size():
			continue
		if not tiles[gx] or gy >= tiles[gx].size():
			continue

		tile_instance = tiles[gx][gy]

		# Check if this is a hard unmovable tile that needs to take a hit
		if tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				print("[GameBoard] Chain unmovable destroyed at (", gx, ",", gy, ") - calling report_unmovable_destroyed")

				# Report destruction to GameManager for counter tracking
				if GameManager.has_method("report_unmovable_destroyed"):
					# Pass skip_clear=true because we're handling the grid update here
					GameManager.report_unmovable_destroyed(clear_pos, true)

				var is_coll = tile_instance.is_collectible if "is_collectible" in tile_instance else false
				var tile_type_check = tile_instance.tile_type if "tile_type" in tile_instance else 0
				# If destroyed, the tile has already transformed if it had a reveal
				# Update the grid to match what the tile became
				if is_coll:
					GameManager.grid[gx][gy] = GameManager.COLLECTIBLE
					tiles[gx][gy] = tile_instance
				elif tile_type_check > 0:
					GameManager.grid[gx][gy] = tile_type_check
					tiles[gx][gy] = tile_instance
				else:
					# Tile was destroyed without reveal, clear it
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion():
						tile_instance.queue_free()
					tiles[gx][gy] = null
					scoring_count += 1
			else:
				print("[GameBoard] Chain unmovable at (", gx, ",", gy, ") took hit but not destroyed yet")
			# Handle soft unmovables (legacy U tokens)
			if GameManager.has_method("report_unmovable_destroyed"):
				GameManager.report_unmovable_destroyed(clear_pos)
			else:
				var key = str(int(clear_pos.x)) + "," + str(int(clear_pos.y))
				if GameManager.unmovable_map.has(key):
					GameManager.unmovable_map.erase(key)
				GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0
				GameManager.unmovables_cleared += 1
		else:
			# Regular tile or spreader
			if t == GameManager.SPREADER:
				GameManager.spreader_count -= 1
				GameManager.spreader_positions.erase(clear_pos)
				print("[SPREADER] Chain destroyed spreader at (", gx, ",", gy, ") - Remaining: ", GameManager.spreader_count)
			GameManager.grid[int(clear_pos.x)][int(clear_pos.y)] = 0
			scoring_count += 1

	var points = GameManager.calculate_points(scoring_count)
	if points > 0:
		GameManager.add_score(points)

	if special_tiles_to_activate.size() > 0:
		for special_tile_info in special_tiles_to_activate:
			await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

	return


# --------------------------- Border drawing helpers ---------------------------
func _clear_board_borders():
	"""Remove any previously created border children from the border container."""
	if border_container == null:
		return
	for child in border_container.get_children():
		if child and is_instance_valid(child):
			child.queue_free()

func _rounded_rect_points(rect_pos: Vector2, rect_size: Vector2, radius: float, segments: int = 8) -> Array:
	"""Generate an ordered list of points approximating a rounded rect (CW).
		rect_pos = top-left world position, rect_size = width/height
		radius is clamped to half of min(width,height)
		segments controls smoothness of the quarter-circle arcs.
	"""
	var pts = []
	var w = rect_size.x
	var h = rect_size.y
	var r = clamp(radius, 0.0, min(w, h) * 0.5)

	# center offsets for corners
	var tl = rect_pos + Vector2(r, r)
	var tr = rect_pos + Vector2(w - r, r)
	var br = rect_pos + Vector2(w - r, h - r)
	var bl = rect_pos + Vector2(r, h - r)

	# Define corners with start/end angles
	var corners = [
		{"center": tl, "a0": PI, "a1": PI * 1.5},
		{"center": tr, "a0": PI * 1.5, "a1": PI * 2},
		{"center": br, "a0": 0.0, "a1": PI * 0.5},
		{"center": bl, "a0": PI * 0.5, "a1": PI}
	]

	for corner in corners:
		var c = corner["center"]
		var a0 = corner["a0"]
		var a1 = corner["a1"]
		for i in range(segments + 1):
			var t = float(i) / float(segments)
			var a = lerp(a0, a1, t)
			pts.append(c + Vector2(cos(a), sin(a)) * r)

	return pts

func draw_board_borders():
	print("[GameBoard] draw_board_borders called - board visible=", visible)
	print("[GameBoard] typeof(GameManager) = ", typeof(GameManager))

	# Use typeof check instead of Engine.has_singleton() to detect autoload availability
	if typeof(GameManager) == TYPE_NIL:
		print("[GameBoard] draw_board_borders: GameManager not available (typeof==NIL) - skipping until level_loaded")
		return

	if not GameManager.initialized or GameManager.grid == null or GameManager.grid.size() == 0:
		print("[GameBoard] draw_board_borders: GameManager not initialized or empty grid - skipping until level_loaded")
		return

	# Ensure border_container exists
	if border_container == null:
		border_container = Node2D.new()
		border_container.name = "BorderContainer"
		add_child(border_container)

	# Draw borders (per-cell rounded borders)
	draw_simple_borders()

	# Set visibility of border container to match this GameBoard's visibility
	if border_container:
		border_container.visible = visible

	# Diagnostic: print summary
	var child_count = border_container.get_child_count() if border_container else 0
	print("[GameBoard] draw_board_borders completed - tile_size=", tile_size, ", grid_offset=", grid_offset, ", grid=", GameManager.GRID_WIDTH, "x", GameManager.GRID_HEIGHT, ", border_segments=", child_count)
	return


func draw_simple_borders() -> void:
	# Draw simple straight edges and quarter-circle corners around active tiles
	var corner_radius = max(4.0, BORDER_WIDTH * 4.0)
	# Guard GameManager presence and grid readiness (use typeof check)
	print("[GameBoard] draw_simple_borders: typeof(GameManager) = ", typeof(GameManager))
	if typeof(GameManager) == TYPE_NIL:
		print("[GameBoard] draw_simple_borders aborted: GameManager missing (typeof==NIL)")
		return
	if not GameManager.initialized or GameManager.grid == null or GameManager.grid.size() == 0:
		# No level data yet - nothing to draw
		print("[GameBoard] draw_simple_borders aborted: GameManager not initialized or empty grid")
		return
	# Ensure border_container exists
	if border_container == null:
		border_container = Node2D.new()
		border_container.name = "BorderContainer"
		add_child(border_container)
	# clear old children
	for c in border_container.get_children():
		c.queue_free()

	var segments_drawn = 0

	# Iterate cells and draw outer edges where neighbor is blocked/out of bounds
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.is_cell_blocked(x, y):
				continue
			var left = grid_offset.x + x * tile_size
			var right = grid_offset.x + (x + 1) * tile_size
			var top = grid_offset.y + y * tile_size
			var bottom = grid_offset.y + (y + 1) * tile_size

			var has_top = (y == 0 or GameManager.is_cell_blocked(x, y - 1))
			var has_bottom = (y == GameManager.GRID_HEIGHT - 1 or GameManager.is_cell_blocked(x, y + 1))
			var has_left = (x == 0 or GameManager.is_cell_blocked(x - 1, y))
			var has_right = (x == GameManager.GRID_WIDTH - 1 or GameManager.is_cell_blocked(x + 1, y))

			# Top border
			if has_top:
				var start_x = left
				if has_left:
					start_x += corner_radius
				var end_x = right
				if has_right:
					end_x -= corner_radius
				if end_x > start_x:
					draw_border_edge(Vector2(start_x, top), Vector2(end_x, top))
					segments_drawn += 1

			# Bottom border
			if has_bottom:
				var b_start_x = left
				if has_left:
					b_start_x += corner_radius
				var b_end_x = right
				if has_right:
					b_end_x -= corner_radius
				if b_end_x > b_start_x:
					draw_border_edge(Vector2(b_start_x, bottom), Vector2(b_end_x, bottom))
					segments_drawn += 1

			# Left border
			if has_left:
				var start_y = top
				if has_top:
					start_y += corner_radius
				var end_y = bottom
				if has_bottom:
					end_y -= corner_radius
				if end_y > start_y:
					draw_border_edge(Vector2(left, start_y), Vector2(left, end_y))
					segments_drawn += 1

			# Right border
			if has_right:
				var r_start_y = top
				if has_top:
					r_start_y += corner_radius
				var r_end_y = bottom
				if has_bottom:
					r_end_y -= corner_radius
				if r_end_y > r_start_y:
					draw_border_edge(Vector2(right, r_start_y), Vector2(right, r_end_y))
					segments_drawn += 1

			# Corner arcs
			if has_top and has_left:
				draw_corner_arc(Vector2(left, top), "top_left", corner_radius)
				segments_drawn += 1
			if has_top and has_right:
				draw_corner_arc(Vector2(right, top), "top_right", corner_radius)
				segments_drawn += 1
			if has_bottom and has_left:
				draw_corner_arc(Vector2(left, bottom), "bottom_left", corner_radius)
				segments_drawn += 1
			if has_bottom and has_right:
				draw_corner_arc(Vector2(right, bottom), "bottom_right", corner_radius)
				segments_drawn += 1

	print("[GameBoard] draw_simple_borders: drawn per-cell borders; segments_drawn=", segments_drawn)
	# Ensure border_container visibility reflects current board visibility
	if border_container:
		border_container.visible = visible

	return

func draw_border_edge(start: Vector2, end: Vector2) -> void:
	var l = Line2D.new()
	l.add_point(start)
	l.add_point(end)
	l.width = BORDER_WIDTH
	l.default_color = border_color
	l.antialiased = true
	border_container.add_child(l)

func draw_corner_arc(corner_pos: Vector2, corner_type: String, radius: float) -> void:
	var line = Line2D.new()
	var segments = 8
	match corner_type:
		"top_left":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI, PI * 1.5, t)
				line.add_point(corner_pos + Vector2(radius, radius) + Vector2(cos(ang), sin(ang)) * radius)
		"top_right":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI * 1.5, PI * 2.0, t)
				line.add_point(corner_pos + Vector2(-radius, radius) + Vector2(cos(ang), sin(ang)) * radius)
		"bottom_left":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(PI * 0.5, PI, t)
				line.add_point(corner_pos + Vector2(radius, -radius) + Vector2(cos(ang), sin(ang)) * radius)
		"bottom_right":
			for i in range(segments + 1):
				var t = float(i) / float(segments)
				var ang = lerp(0.0, PI * 0.5, t)
				line.add_point(corner_pos + Vector2(-radius, -radius) + Vector2(cos(ang), sin(ang)) * radius)
	line.width = BORDER_WIDTH
	line.default_color = border_color
	line.antialiased = true
	border_container.add_child(line)
