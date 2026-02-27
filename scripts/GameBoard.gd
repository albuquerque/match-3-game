extends Node2D
class_name GameBoard

signal move_completed
signal board_idle

signal request_remove_matches(matches, swapped_pos)
signal request_apply_gravity()
signal request_fill_empty()
signal request_special_creation(pos, special_type)

# Safe script resource handles - avoid using load() at parse time which GDScript flags as non-constant
var VF = null
var VE = null
var ER = null
var GS = null
var BR = null
var BS = null
var MO = null  # MatchOrchestrator

# Backwards-compatibility aliases (will be assigned in _ready)
var VisualFactory = null
var VisualEffects = null
var EffectsRenderer = null
var GravityService = null
var BoosterService = null
var BorderRenderer = null
var MatchOrchestrator = null

# Helper: await multiple tweens with timeout to avoid hanging if a tween never finishes
func _await_tweens_with_timeout(tweens: Array, timeout: float = 2.0) -> void:
	if tweens == null or tweens.size() == 0:
		return

	var finished_map = {}
	for tween in tweens:
		if tween == null:
			continue
		finished_map[tween] = false
		# Connect to a helper method instead of using a standalone lambda (lambdas are restricted)
		# Bind the tween and finished_map so the helper has the context it needs
		tween.finished.connect(Callable(self, "_mark_tween_finished").bind(tween, finished_map))

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

# Helper to mark a tween finished; separate method so we can bind context safely
func _mark_tween_finished(tween, finished_map):
	if finished_map == null:
		return
	finished_map[tween] = true
	return

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
	# Lazy-load helper modules to avoid parse-time non-constant assignment errors
	if VF == null:
		VF = load("res://scripts/game/VisualFactory.gd")
	if VE == null:
		VE = load("res://scripts/game/VisualEffects.gd")
	if ER == null:
		ER = load("res://scripts/game/EffectsRenderer.gd")
	if GS == null:
		GS = load("res://scripts/game/GravityService.gd")
	if BR == null:
		BR = load("res://scripts/game/BorderRenderer.gd")
	if BS == null:
		BS = load("res://scripts/game/BoosterService.gd")
	if MO == null:
		MO = load("res://scripts/game/MatchOrchestrator.gd")

	# Backwards-compatibility aliases point to loaded resources
	VisualFactory = VF
	VisualEffects = VE
	EffectsRenderer = ER
	GravityService = GS
	BoosterService = BS
	BorderRenderer = BR
	MatchOrchestrator = MO

	# Safely connect to GameManager signals if GameManager autoload is present
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.connect("game_over", Callable(self, "_on_game_over"))
		gm.connect("level_complete", Callable(self, "_on_level_complete"))
		gm.connect("level_loaded", Callable(self, "_on_level_loaded"))
	else:
		print("[GameBoard] WARNING: GameManager autoload not available at _ready(); will wait for level_loaded signal")

	# Also listen to EventBus.level_loaded to be robust against load-order timing
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("level_loaded"):
		eb.level_loaded.connect(Callable(self, "_on_eventbus_level_loaded"))
		print("[GameBoard] Connected to EventBus.level_loaded for robustness")

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

	# Register this board with GameManager so it can connect to request signals
	if typeof(GameManager) != TYPE_NIL and GameManager != null and GameManager.has_method("register_board"):
		GameManager.register_board(self)

	# Defer a short-check in case level was loaded before we connected
	call_deferred("_deferred_check_initialization")

func _deferred_check_initialization():
	# Called deferred from _ready to handle cases where level was loaded earlier or registration missed
	if typeof(GameManager) != TYPE_NIL and GameManager != null:
		# If game manager already initialized a level, create visuals immediately
		if GameManager.initialized and has_method("create_visual_grid"):
			call_deferred("create_visual_grid")
			call_deferred("_safe_draw_board_borders_deferred")
			print("[GameBoard] _deferred_check_initialization: detected initialized GameManager, created visuals")
		return
	# Otherwise, nothing to do - wait for level_loaded signal
	print("[GameBoard] _deferred_check_initialization: GameManager not initialized yet or not present")
	return

func calculate_responsive_layout():
	var viewport = get_viewport()
	var screen_size = viewport.get_visible_rect().size

	var ui_top_space = 180.0
	var ui_bottom_space = 100.0
	var available_width = screen_size.x - (board_margin * 2)
	var available_height = screen_size.y - ui_top_space - ui_bottom_space - (board_margin * 2)

	var max_tile_size_width = available_width / GameManager.GRID_WIDTH
	var max_tile_size_height = available_height / GameManager.GRID_HEIGHT
	tile_size = min(max_tile_size_width, max_tile_size_height)
	tile_size = max(tile_size, 50.0)

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
	if background:
		background.visible = false

	var board_size = Vector2(
		GameManager.GRID_WIDTH * tile_size + 20,
		GameManager.GRID_HEIGHT * tile_size + 20
	)

	background.color = BOARD_BACKGROUND_COLOR
	background.size = board_size
	background.position = Vector2(
		grid_offset.x - 10,
		grid_offset.y - 10
	)

	setup_tile_area_overlay()

func setup_tile_area_overlay():
	if tile_area_overlay and is_instance_valid(tile_area_overlay):
		var parent_node = tile_area_overlay.get_parent()
		if parent_node:
			parent_node.remove_child(tile_area_overlay)
		tile_area_overlay.queue_free()
		tile_area_overlay = null

	var parent = get_parent()
	if parent:
		var old_overlays = []
		for child in parent.get_children():
			if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
				old_overlays.append(child)
				print("[GameBoard] Found orphaned TileAreaOverlay in parent - removing")
		for old_overlay in old_overlays:
			if is_instance_valid(old_overlay):
				parent.remove_child(old_overlay)
				old_overlay.queue_free()

	var local_old_overlays = []
	for child in get_children():
		if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
			local_old_overlays.append(child)
			print("[GameBoard] Found orphaned TileAreaOverlay as direct child - removing")
	for old_overlay in local_old_overlays:
		if is_instance_valid(old_overlay):
			remove_child(old_overlay)
			old_overlay.queue_free()

	tile_area_overlay = Control.new()
	tile_area_overlay.name = "TileAreaOverlay"
	tile_area_overlay.z_index = -50
	tile_area_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y):
				var tile_overlay = ColorRect.new()
				tile_overlay.color = Color(0.1, 0.15, 0.25, 0.5)
				tile_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				var left = x * tile_size + grid_offset.x
				var top = y * tile_size + grid_offset.y
				tile_overlay.position = Vector2(left, top)
				tile_overlay.size = Vector2(tile_size, tile_size)
				tile_area_overlay.add_child(tile_overlay)

	var attach_parent = get_parent()
	if attach_parent:
		attach_parent.call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created with %d ColorRects, added to parent (deferred) (%s)" % [tile_area_overlay.get_child_count(), attach_parent.name])
	else:
		call_deferred("add_child", tile_area_overlay)
		print("[GameBoard] Tile area overlay created with %d ColorRects (added to self, deferred)" % tile_area_overlay.get_child_count())

func setup_background_image():
	print("[GameBoard] setup_background_image called with path: ", background_image_path)

	if background_sprite:
		background_sprite.queue_free()
		background_sprite = null

	if background_image_path == "":
		print("[GameBoard] No background image path set")
		return

	if not ResourceLoader.exists(background_image_path):
		print("[GameBoard] ERROR: Background image not found at: ", background_image_path)
		return

	var background_rect = TextureRect.new()
	background_rect.name = "BackgroundImage"
	var texture = load(background_image_path)
	if not texture:
		print("[GameBoard] ERROR: Failed to load texture from: ", background_image_path)
		return
	background_rect.texture = texture
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var viewport = get_viewport()
	if not viewport:
		print("[GameBoard] ERROR: No viewport available")
		return
	var screen_size = viewport.get_visible_rect().size
	background_rect.size = screen_size
	background_rect.position = Vector2.ZERO
	background_rect.z_index = -100
	background_sprite = background_rect
	var parent = get_parent()
	if parent:
		call_deferred("_deferred_attach_background", background_rect, parent)
		print("[GameBoard] Background will be attached to parent (deferred): ", parent.name)
	else:
		call_deferred("add_child", background_rect)
		call_deferred("move_child", background_rect, 0)
		print("[GameBoard] Background will be added to self (deferred, no parent found)")

func _deferred_attach_background(background_rect: Node, parent: Node) -> void:
	if not parent or not background_rect:
		print("[GameBoard] _deferred_attach_background: missing parent or background_rect")
		return
	parent.add_child(background_rect)
	parent.move_child(background_rect, 0)
	var existing_bg = parent.get_node_or_null("Background")
	if existing_bg and existing_bg is ColorRect:
		existing_bg.visible = false
		print("[GameBoard] Hidden existing MainGame background to show image (deferred)")


func set_border_color(color: Color):
	"""Set the color for the board borders"""
	border_color = color
	# Redraw borders with new color - use deferred safe call to avoid parser/static lookup issues
	# replaced direct deferred call with safe wrapper
	call_deferred("_safe_draw_board_borders_deferred")

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
	var tiles_to_remove = []

	if board_container and is_instance_valid(board_container):
		print("[CLEAR_TILES] Checking board_container for tiles...")
		for child in board_container.get_children():
			if child and is_instance_valid(child) and child.name != "BorderContainer" and child.has_method("setup"):
				tiles_to_remove.append(child)
				print("[CLEAR_TILES]   Found tile in board_container: ", child.name)

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

func _safe_draw_board_borders_deferred():
	# Delegate to the inline draw_board_borders
	draw_board_borders()

func instantiate_tile_visual(tile_type: int, grid_pos: Vector2, scale_factor: float, unmovable_meta = null) -> Node:
	var tile: Node = tile_scene.instantiate()
	if tile != null and tile.has_method("setup"):
		if unmovable_meta != null:
			tile.setup(0, grid_pos, scale_factor, true)
		else:
			tile.setup(tile_type, grid_pos, scale_factor)

	if unmovable_meta != null and tile != null:
		if tile.has_method("configure_unmovable_hard"):
			var textures_arr = []
			var reveals = {}
			if unmovable_meta.has("textures"):
				textures_arr = unmovable_meta["textures"]
			if unmovable_meta.has("reveals"):
				reveals = unmovable_meta["reveals"]
			if typeof(textures_arr) != TYPE_ARRAY:
				textures_arr = []
			if typeof(reveals) != TYPE_DICTIONARY:
				reveals = {}
			tile.configure_unmovable_hard(unmovable_meta.get("hits", 1), unmovable_meta.get("type", GameManager.unmovable_type), textures_arr, reveals)

	if tile != null:
		tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
		tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
		if board_container:
			board_container.add_child(tile)
		else:
			add_child(tile)

	return tile


func create_visual_grid():
	# Guard against concurrent execution
	if creating_visual_grid:
		print("[GameBoard] ⚠️  create_visual_grid already in progress - skipping duplicate call")
		return

	creating_visual_grid = true
	print("[GameBoard] create_visual_grid: Starting (flag set)")

	clear_tiles()

	await get_tree().process_frame

	tiles.clear()

	print("[GameBoard] Creating visual grid for ", GameManager.GRID_WIDTH, "x", GameManager.GRID_HEIGHT, " board")

	if GameManager.grid.size() == 0:
		print("[GameBoard] ERROR: GameManager.grid is empty! Cannot create tiles.")
		creating_visual_grid = false
		return

	var scale_factor = tile_size / 64.0

	var tiles_created = 0
	for x in range(GameManager.GRID_WIDTH):
		tiles.append([])
		for y in range(GameManager.GRID_HEIGHT):
			var tile_type = GameManager.get_tile_at(Vector2(x, y))

			# Skip blocked cells (-1)
			if tile_type == -1:
				tiles[x].append(null)
				continue

			var tile = null

			# Check if this position has a hard unmovable in GameManager.unmovable_map
			var key = str(x) + "," + str(y)
			if GameManager.unmovable_map.has(key) and typeof(GameManager.unmovable_map[key]) == TYPE_DICTIONARY:
				# This is a hard unmovable position - create unmovable tile with placeholder visual via direct instantiation
				tile = tile_scene.instantiate()
				if tile and tile.has_method("setup"):
					tile.setup(0, Vector2(x, y), scale_factor, true)
					# configure_unmovable_hard handled below
			else:
				# Normal tile (not unmovable) - prefer VisualFactory via VF
				if VF != null and VF.has_method("create_tile_instance"):
					tile = VF.create_tile_instance(tile_scene, tile_type, Vector2(x, y), scale_factor)
				else:
					# Fallback
					tile = tile_scene.instantiate()
					if tile and tile.has_method("setup"):
						tile.setup(tile_type, Vector2(x, y), scale_factor)

			if not tile:
				tiles[x].append(null)
				continue

			# Configure unmovable if necessary
			if GameManager.unmovable_map.has(key) and typeof(GameManager.unmovable_map[key]) == TYPE_DICTIONARY:
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
						if typeof(textures_arr) != TYPE_ARRAY:
							textures_arr = []
						if typeof(reveals) != TYPE_DICTIONARY:
							reveals = {}
					tile.configure_unmovable_hard(hits, htype, textures_arr, reveals)
					print("[GameBoard] Configured hard unmovable tile at (", x, ",", y, ") hits=", hits, " type=", htype)
				else:
					print("[GameBoard] WARNING: Tile missing configure_unmovable_hard method at (", x, ",", y, ")")
			else:
				# Normal tile wiring - collectible and spreader configuration
				# (signal connections handled unconditionally below)

				# Check if this is a collectible tile (type 10)
				if tile_type == GameManager.COLLECTIBLE:
					if tile.has_method("configure_collectible"):
						tile.configure_collectible(GameManager.collectible_type)
						print("[GameBoard] Configured tile at (", x, ",", y, ") as collectible: ", GameManager.collectible_type)

				# Check if this is a spreader tile (type 12)
				if tile_type == GameManager.SPREADER:
					if tile.has_method("configure_spreader"):
						var textures = []
						if GameManager.spreader_textures_map.has(GameManager.spreader_type):
							textures = GameManager.spreader_textures_map[GameManager.spreader_type]
						tile.configure_spreader(GameManager.spreader_grace_default, GameManager.spreader_type, textures)
						print("[GameBoard] Configured tile at (", x, ",", y, ") as spreader type '", GameManager.spreader_type, "' with grace: ", GameManager.spreader_grace_default, " textures: ", textures.size())

			# Add tile to board_container instead of directly to GameBoard
			if board_container:
				board_container.add_child(tile)
			else:
				add_child(tile)  # Fallback if container not created

			# CRITICAL: Set world position so tile renders in the correct cell
			tile.position = grid_to_world_position(Vector2(x, y))

			# Always connect input signals (including unmovable tiles, which may have interactions)
			if not tile.is_connected("tile_clicked", Callable(self, "_on_tile_clicked")):
				tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
			if not tile.is_connected("tile_swiped", Callable(self, "_on_tile_swiped")):
				tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))

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

	# Run deferred debug auto-swap to validate swap flow (only active when DEBUG_AUTO_TEST_SWAP=true)
	call_deferred("_deferred_debug_auto_swap")

	return

# Collectible spawning and handling
func spawn_collectible_visual(x: int, y: int, coll_type: String = "coin"):
	if x < 0 or x >= GameManager.GRID_WIDTH or y < 0 or y >= GameManager.GRID_HEIGHT:
		return

	var existing_tile = tiles[x][y] if x < tiles.size() and y < tiles[x].size() else null
	if existing_tile:
		if existing_tile.has_method("configure_collectible"):
			existing_tile.configure_collectible(coll_type)
			print("[GameBoard] Configured existing tile at (", x, ",", y, ") as collectible:", coll_type)
	else:
		# Create new collectible tile using VisualFactory (VF) if available
		var scale_factor = tile_size / 64.0
		var tile = null
		if VF != null and VF.has_method("create_collectible_tile"):
			tile = VF.create_collectible_tile(tile_scene, coll_type, Vector2(x, y), scale_factor)
		else:
			# Fallback
			tile = tile_scene.instantiate()
			if tile and tile.has_method("setup"):
				tile.setup(0, Vector2(x, y), scale_factor)
			if tile and tile.has_method("configure_collectible"):
				tile.configure_collectible(coll_type)

		if tile:
			tile.position = grid_to_world_position(Vector2(x, y))
			tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
			tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
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
	BoardEffects.create_special_activation_particles(self, world_pos)

func _create_impact_particles(pos: Vector2, color: Color = Color(1,1,1,1)):
	BoardEffects.create_impact_particles(self, pos, color)

func _create_lightning_beam_horizontal(row: int, color: Color = Color.YELLOW):
	# A6: Delegated to EffectsRenderer
	if ER != null:
		return ER.create_lightning_beam_horizontal(self, row, color, tile_size)
	return null

func _create_lightning_beam_vertical(col: int, color: Color = Color.CYAN):
	# A6: Delegated to EffectsRenderer
	if ER != null:
		return ER.create_lightning_beam_vertical(self, col, color, tile_size)
	return null

func _show_combo_text(match_count: int, positions: Array, combo_multiplier: int = 1):
	BoardEffects.show_combo_text(self, match_count, positions, combo_multiplier)

func _apply_screen_shake(duration: float, intensity: float):
	BoardEffects.apply_screen_shake(self, duration, intensity)


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

	# DEBUG: Log computed layout values to help diagnose tile placement
	print("[GameBoard][DEBUG] tile_size=", tile_size, " grid_offset=", grid_offset)
	if board_container:
		print("[GameBoard][DEBUG] board_container position=", board_container.position, " global_position=", board_container.global_position)
	else:
		print("[GameBoard][DEBUG] board_container is null")

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

	# Run debug auto-swap after visuals are created (works regardless of BoardVisuals or fallback path)
	call_deferred("_deferred_debug_auto_swap")

	# Use safe deferred border drawer to avoid 'Method not found' errors
	call_deferred("_safe_draw_board_borders_deferred")

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
		GameManager.call("spawn_collectibles_for_targets")
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
	tween.set_loops(-1)
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
			if GameManager.has_method("skip_bonus_animation"):
				GameManager.skip_bonus_animation()
			hide_skip_bonus_hint()
			# Consume the event to prevent it from propagating to other input handlers
			get_viewport().set_input_as_handled()


func _on_tile_clicked(tile):
	if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
		return
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
				if game_ui.has_method("deactivate_booster"):
					game_ui.deactivate_booster()
				game_ui.update_booster_ui()
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
	# Ignore stale tile nodes that are queued for deletion but haven't been freed yet
	if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
		return

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

# ============================================
# Match destruction and animation functions
# ============================================

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

		if not tiles or gx >= tiles.size() or not tiles[gx] or gy >= tiles[gx].size():
			print("[ANIMATE_DESTROY] WARNING: Invalid tiles array access at (", gx, ",", gy, ")")
			continue

		var tile = tiles[gx][gy]
		if not tile or not is_instance_valid(tile):
			print("[ANIMATE_DESTROY] No valid tile at (", gx, ",", gy, ")")
			continue

		var is_hard = tile.is_unmovable_hard if "is_unmovable_hard" in tile else false
		print("[ANIMATE_DESTROY] Checking tile at (", gx, ",", gy, ") is_unmovable_hard=", is_hard)
		if is_hard:
			print("[GameBoard] ✓✓✓ Skipping visual destruction of hard unmovable at (", gx, ",", gy, ") ✓✓✓")
			continue

		if tile.has_method("animate_destroy"):
			var tw = tile.animate_destroy()
			if tw:
				destroy_tweens.append(tw)
		else:
			var tw2 = create_tween()
			tw2.tween_property(tile, "modulate", Color(1,1,1,0), 0.15)
			destroy_tweens.append(tw2)
		# Disable input immediately so this tile can't ghost-fire during its death animation
		tile.set_process_input(false)
		tiles_to_free.append(tile)
		destroyed_positions.append(pos)

	if destroy_tweens.size() > 0:
		for tw in destroy_tweens:
			if tw != null:
				await tw.finished
	else:
		if get_tree() != null:
			await get_tree().create_timer(0.15).timeout

	for i in range(tiles_to_free.size()):
		var pos = destroyed_positions[i]
		if pos.x >= 0 and pos.y >= 0:
			if tiles[int(pos.x)][int(pos.y)] == tiles_to_free[i]:
				tiles[int(pos.x)][int(pos.y)] = null
			if not tiles_to_free[i].is_queued_for_deletion():
				tiles_to_free[i].queue_free()

	print("animate_destroy_tiles: destroyed ", tiles_to_free.size(), " visual tiles")

func animate_destroy_matches(matches: Array):
	if matches == null or matches.size() == 0:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_match_time > COMBO_TIMEOUT:
		combo_chain_count = 0

	combo_chain_count += 1
	last_match_time = current_time

	print("[GameBoard] Match! Size: ", matches.size(), ", Combo chain: ", combo_chain_count)

	var should_show_combo = true
	var combo_multiplier = combo_chain_count

	if matches.size() == 3 and combo_chain_count == 1:
		should_show_combo = false

	if should_show_combo:
		_show_combo_text(matches.size(), matches, combo_multiplier)

	if matches.size() >= 5 or combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, combo_chain_count * 3)
		_apply_screen_shake(0.15, shake_intensity)

	await animate_destroy_tiles(matches)

func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	if matches == null or matches.size() == 0:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_match_time > COMBO_TIMEOUT:
		combo_chain_count = 0

	combo_chain_count += 1
	last_match_time = current_time

	print("[GameBoard] Match (creating special)! Size: ", matches.size(), ", Combo chain: ", combo_chain_count)

	var should_show_combo = true
	var combo_multiplier = combo_chain_count

	if should_show_combo:
		_show_combo_text(matches.size(), matches, combo_multiplier)

	if matches.size() >= 5 or combo_chain_count >= 3:
		var shake_intensity = max(matches.size() * 2, combo_chain_count * 3)
		_apply_screen_shake(0.15, shake_intensity)

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

# ============================================
# Gravity and refill
# ============================================

func animate_gravity() -> void:
	var moved = GameManager.apply_gravity()
	print("[GRAVITY] apply_gravity returned -> ", moved)

	var gravity_tweens = []

	for x in range(GameManager.GRID_WIDTH):
		# Determine which rows are "barriers" — inactive (-1) or hard unmovable tiles.
		# Barriers divide the column into independent gravity segments.
		var is_barrier: Array = []
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles[x][y] if x < tiles.size() and y < tiles[x].size() else null
			var blocked = GameManager.is_cell_blocked(x, y)
			var unmovable = tile != null and not tile.is_queued_for_deletion() and \
				"is_unmovable_hard" in tile and tile.is_unmovable_hard
			# Spreaders are stationary — treat as barriers so gravity doesn't move them
			var is_spreader_cell = GameManager.get_tile_at(Vector2(x, y)) == GameManager.SPREADER
			is_barrier.append(blocked or unmovable or is_spreader_cell)

		# Step 1: Find the start row of each segment (top-to-bottom order).
		# A segment is a contiguous run of non-barrier rows.
		# segment_tiles[i] will hold the visual tiles for the i-th segment
		# from the top, collected bottom-to-top within that segment.
		var segment_tiles: Array = []   # Array of Arrays, top-to-bottom order

		var seg_start := -1
		for y in range(GameManager.GRID_HEIGHT):
			if is_barrier[y]:
				if seg_start >= 0:
					# Collect tiles top-to-bottom within this segment and clear slots.
					# Top-to-bottom order means seg[0] = topmost tile, so during
					# reassignment (also top-to-bottom) tiles animate downward — never upward.
					var seg: Array = []
					for sy in range(seg_start, y):
						var tile = tiles[x][sy]
						if tile != null and not tile.is_queued_for_deletion():
							seg.append(tile)
						tiles[x][sy] = null   # clear for reassignment
					segment_tiles.append(seg)
					seg_start = -1
			else:
				if seg_start < 0:
					seg_start = y
		# Handle the last segment if it runs to the bottom
		if seg_start >= 0:
			var seg: Array = []
			for sy in range(seg_start, GameManager.GRID_HEIGHT):
				var tile = tiles[x][sy]
				if tile != null and not tile.is_queued_for_deletion():
					seg.append(tile)
				tiles[x][sy] = null
			segment_tiles.append(seg)

		# Step 2: Reassign tiles top-to-bottom.
		# Advance the segment pool only on the FIRST barrier row of each barrier run
		# (transition from non-barrier → barrier).  Consecutive barrier rows (e.g. a
		# cluster of unmovables) must NOT each trigger an extra segment advance.
		var seg_index := 0
		var tile_index := 0
		var current_seg: Array = segment_tiles[0] if segment_tiles.size() > 0 else []
		var prev_was_barrier := true   # treat start-of-column as barrier so we don't pre-advance

		for y in range(GameManager.GRID_HEIGHT):
			if is_barrier[y]:
				if not prev_was_barrier:
					# First barrier after a non-barrier run — flush current segment and advance
					if tile_index < current_seg.size():
						print("[GRAVITY] Column ", x, " segment has ", current_seg.size() - tile_index, " extra tiles - freeing them")
						for i in range(tile_index, current_seg.size()):
							var extra = current_seg[i]
							if extra and not extra.is_queued_for_deletion():
								extra.queue_free()
					seg_index += 1
					tile_index = 0
					current_seg = segment_tiles[seg_index] if seg_index < segment_tiles.size() else []
				prev_was_barrier = true
				continue
			prev_was_barrier = false

			var tile_type = GameManager.get_tile_at(Vector2(x, y))
			if tile_type > 0:
				if tile_index < current_seg.size():
					var tile = current_seg[tile_index]
					tiles[x][y] = tile
					tile.grid_position = Vector2(x, y)
					tile.update_type(tile_type)
					var target_pos = grid_to_world_position(Vector2(x, y))
					if tile.position.distance_to(target_pos) > 1:
						gravity_tweens.append(tile.animate_to_position(target_pos))
					tile_index += 1
				else:
					print("[GRAVITY] Position (", x, ",", y, ") needs tile type ", tile_type, " but no visual tile available")

		# Free any remaining unused tiles in the last segment
		if tile_index < current_seg.size():
			print("[GRAVITY] Column ", x, " last segment has ", current_seg.size() - tile_index, " extra tiles - freeing them")
			for i in range(tile_index, current_seg.size()):
				var extra = current_seg[i]
				if extra and not extra.is_queued_for_deletion():
					extra.queue_free()

	if gravity_tweens.size() > 0:
		for tween in gravity_tweens:
			if tween != null:
				await tween.finished
	else:
		await get_tree().create_timer(0.01).timeout

	_check_collectibles_at_bottom()
	print("Gravity complete")

func animate_refill() -> Array:
	var new_tile_positions = GameManager.fill_empty_spaces()
	var spawn_tweens = []
	var scale_factor = tile_size / 64.0

	# Also find any positions with grid values but missing visual tiles.
	# Skip inactive cells AND positions occupied by hard unmovable tiles.
	var positions_needing_tiles = []
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if GameManager.is_cell_blocked(x, y):
				continue
			# Skip hard unmovable positions — they already have their own visual tile
			var existing = tiles[x][y] if x < tiles.size() and y < tiles[x].size() else null
			if existing != null and not existing.is_queued_for_deletion() and \
					"is_unmovable_hard" in existing and existing.is_unmovable_hard:
				continue
			var grid_value = GameManager.get_tile_at(Vector2(x, y))
			if grid_value > 0:
				var has_visual = existing != null and is_instance_valid(existing)
				if not has_visual:
					var pos_vec = Vector2(x, y)
					if not new_tile_positions.has(pos_vec):
						print("[REFILL] Position (", x, ",", y, ") has grid value ", grid_value, " but no visual tile - adding to spawn list")
						positions_needing_tiles.append(pos_vec)
	for pos in positions_needing_tiles:
		if not new_tile_positions.has(pos):
			new_tile_positions.append(pos)

	for pos in new_tile_positions:
		var x = int(pos.x)
		var y = int(pos.y)
		if GameManager.is_cell_blocked(x, y):
			continue
		# Never overwrite a hard unmovable tile
		var cur = tiles[x][y] if x < tiles.size() and y < tiles[x].size() else null
		if cur != null and not cur.is_queued_for_deletion() and \
				"is_unmovable_hard" in cur and cur.is_unmovable_hard:
			print("[REFILL] Skipping unmovable at (", x, ",", y, ") - not replacing")
			continue
		if cur != null:
			if cur and not cur.is_queued_for_deletion():
				print("[GameBoard] WARNING: Tile already exists at (", x, ",", y, ") - freeing old tile")
				cur.queue_free()
			tiles[x][y] = null

		var tile_type = GameManager.get_tile_at(pos)
		var tile = tile_scene.instantiate()
		if tile_type == GameManager.COLLECTIBLE:
			tile.setup(0, pos, scale_factor)
			if tile.has_method("configure_collectible"):
				tile.configure_collectible(GameManager.collectible_type)
		else:
			tile.setup(tile_type, pos, scale_factor)

		# Find the top of this tile's segment so it spawns from just above its own
		# barrier. Use the visual tiles array to detect intact unmovable barriers —
		# the data-level unmovable_map is already cleared for destroyed ones so we
		# cannot rely on _is_unmovable_cell() for barriers that are still intact.
		var segment_top_row: int = y
		for sy in range(y - 1, -1, -1):
			if GameManager.is_cell_blocked(x, sy):
				break
			var st: Node = tiles[x][sy] if x < tiles.size() and sy < tiles[x].size() else null
			if st != null and not st.is_queued_for_deletion():
				if ("is_unmovable_hard" in st and st.is_unmovable_hard) or \
						("is_spreader" in st and st.is_spreader):
					break
			segment_top_row = sy
		tile.position = grid_to_world_position(Vector2(x, segment_top_row - 1))
		tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
		tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
		if board_container:
			board_container.add_child(tile)
		else:
			add_child(tile)
		tiles[x][y] = tile
		var target_pos = grid_to_world_position(pos)
		var pos_tween = tile.animate_to_position(target_pos)
		var spawn_tween = tile.animate_spawn()
		if pos_tween:
			spawn_tweens.append(pos_tween)
		if spawn_tween:
			spawn_tweens.append(spawn_tween)

	var valid_tweens = spawn_tweens.filter(func(tw): return tw != null)
	if valid_tweens.size() > 0:
		await valid_tweens[0].finished
	else:
		await get_tree().create_timer(0.3).timeout

	print("Refill complete")
	return new_tile_positions

func _check_collectibles_at_bottom():
	"""Check if any collectibles have reached the bottom-most active cell in their column and collect them"""
	var collectibles_to_remove = []

	for x in range(GameManager.GRID_WIDTH):
		var last_active_row = -1
		for y in range(GameManager.GRID_HEIGHT - 1, -1, -1):
			if not GameManager.is_cell_blocked(x, y):
				last_active_row = y
				break

		if last_active_row == -1:
			continue

		if x >= tiles.size() or last_active_row >= tiles[x].size():
			continue

		var tile = tiles[x][last_active_row]
		if tile and tile.is_collectible and not tile.collectible_collected_flag:
			print("[GameBoard] Collectible reached bottom-most active cell at (", x, ",", last_active_row, ")")
			collectibles_to_remove.append({"tile": tile, "pos": Vector2(x, last_active_row)})

	if collectibles_to_remove.size() == 0:
		return

	for item in collectibles_to_remove:
		var tile = item["tile"]
		var pos = item["pos"]
		var collectible_type = tile.collectible_type if tile else "coin"

		if tile and tile.has_method("mark_collected"):
			tile.mark_collected()

		if AudioManager and AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("coin_collect")

		var particles = CPUParticles2D.new()
		particles.name = "CollectionParticles"
		particles.position = tile.position if tile else grid_to_world_position(pos)
		particles.emitting = true
		particles.one_shot = true
		particles.amount = 30
		particles.lifetime = 0.8
		particles.explosiveness = 1.0
		add_child(particles)

		if tile and is_instance_valid(tile):
			var viewport = get_viewport()
			var screen_size = viewport.get_visible_rect().size if viewport else Vector2(720, 1280)
			var target_pos = Vector2(screen_size.x - 100, 100)
			var tween = create_tween()
			tween.set_parallel(true)
			tween.tween_property(tile, "global_position", target_pos, 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
			tween.tween_property(tile, "scale", Vector2(0.5, 0.5), 0.6)
			tween.tween_property(tile, "modulate:a", 0.0, 0.4).set_delay(0.2)
			get_tree().create_timer(1.0).timeout.connect(particles.queue_free)
			await tween.finished
		else:
			await get_tree().create_timer(0.6).timeout
			particles.queue_free()

		tiles[int(pos.x)][int(pos.y)] = null
		GameManager.grid[int(pos.x)][int(pos.y)] = 0

		if tile and is_instance_valid(tile):
			tile.queue_free()

		if GameManager.has_method("collectible_landed_at"):
			GameManager.collectible_landed_at(pos, collectible_type)

		print("[GameBoard] Collected collectible with animation")

	if GameManager.pending_level_complete or GameManager.level_transitioning:
		print("[GameBoard] Level completion pending/transitioning - skipping post-collection cascade")
		return

	print("[GameBoard] Applying gravity after collectible collection")
	await animate_gravity()
	await animate_refill()

	var new_matches = GameManager.find_matches() if GameManager.has_method("find_matches") else []
	if new_matches.size() > 0:
		await process_cascade()

# ============================================
# Cascade, shuffle, and special detection
# ============================================

func process_cascade(initial_swap_pos: Vector2 = Vector2(-1, -1)):
	# A1: Delegated to MatchOrchestrator
	if MO != null:
		await MO.process_cascade(self, GameManager, initial_swap_pos)
	else:
		print("[GameBoard] ERROR: MatchOrchestrator not loaded")

func perform_auto_shuffle():
	"""Perform an automatic board shuffle with visual feedback"""
	print("Performing auto-shuffle animation...")
	if GameManager.shuffle_until_moves_available():
		await animate_shuffle()
		print("Board shuffled successfully with valid moves")
	else:
		print("ERROR: Could not find valid board configuration")

func animate_shuffle():
	"""Animate the tiles shuffling on screen"""
	var shuffle_tweens = []
	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			var tile = tiles[x][y]
			if tile and not GameManager.is_cell_blocked(x, y):
				var new_type = GameManager.get_tile_at(Vector2(x, y))
				tile.update_type(new_type)
				var original_pos = tile.position
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(tile, "position", original_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.1)
				tween.tween_property(tile, "rotation", randf_range(-0.2, 0.2), 0.1)
				tween.set_parallel(false)
				tween.tween_property(tile, "position", original_pos, 0.2)
				tween.tween_property(tile, "rotation", 0.0, 0.1)
				shuffle_tweens.append(tween)

	if shuffle_tweens.size() > 0:
		await shuffle_tweens[0].finished
	else:
		await get_tree().create_timer(0.3).timeout

func find_special_tile_position_in_matches(matches: Array) -> Vector2:
	"""Find if there's a T/L shape or 4+ line match in the matches, return the position for the special tile"""
	if matches.size() < 4:
		return Vector2(-1, -1)

	for test_pos in matches:
		var matches_on_same_row = 0
		var matches_on_same_col = 0
		for match_pos in matches:
			if match_pos.y == test_pos.y:
				matches_on_same_row += 1
			if match_pos.x == test_pos.x:
				matches_on_same_col += 1
		if matches_on_same_row >= 3 and matches_on_same_col >= 3:
			print("Found T/L shape at ", test_pos, " - Row: ", matches_on_same_row, " Col: ", matches_on_same_col)
			return test_pos

	var rows_dict = {}
	for match_pos in matches:
		if not rows_dict.has(match_pos.y):
			rows_dict[match_pos.y] = []
		rows_dict[match_pos.y].append(match_pos)
	for row_y in rows_dict:
		var row_matches = rows_dict[row_y]
		if row_matches.size() >= 4:
			print("Found 4+ horizontal line at row ", row_y, " with ", row_matches.size(), " tiles")
			var mid = int(row_matches.size() / 2)
			return row_matches[mid]

	var cols_dict = {}
	for match_pos in matches:
		if not cols_dict.has(match_pos.x):
			cols_dict[match_pos.x] = []
		cols_dict[match_pos.x].append(match_pos)
	for col_x in cols_dict:
		var col_matches = cols_dict[col_x]
		if col_matches.size() >= 4:
			print("Found 4+ vertical line at col ", col_x, " with ", col_matches.size(), " tiles")
			var midc = int(col_matches.size() / 2)
			return col_matches[midc]
	return Vector2(-1, -1)

func highlight_matches(matches: Array):
	var highlight_tweens = []
	for match_pos in matches:
		var tile = tiles[int(match_pos.x)][int(match_pos.y)]
		if tile:
			var tween = tile.animate_match_highlight()
			if tween != null:
				highlight_tweens.append(tween)
	for tw in highlight_tweens:
		if tw != null:
			await tw.finished

# ============================================
# Deferred gravity + refill helper
# ============================================

func deferred_gravity_then_refill() -> void:
	_task_deferred_gravity_then_refill()

func _task_deferred_gravity_then_refill() -> void:
	print("[GameBoard] deferred_gravity_then_refill started")
	if GameManager.pending_level_complete or GameManager.level_transitioning:
		print("[GameBoard] deferred_gravity_then_refill aborted: level transition pending")
		return

	await animate_gravity()
	await animate_refill()

	var new_matches = GameManager.find_matches() if GameManager.has_method("find_matches") else []
	if new_matches and new_matches.size() > 0:
		print("[GameBoard] deferred_gravity_then_refill: new matches found, processing cascade")
		await process_cascade()
	else:
		print("[GameBoard] deferred_gravity_then_refill: no matches found, emitting board_idle")
		emit_signal("board_idle")

	print("[GameBoard] deferred_gravity_then_refill completed")

# ============================================
# Booster Activation Functions
# A4: Position computation delegated to BoosterService static helpers.
# Visual orchestration (animation, gravity, cascade) stays in GameBoard.
# ============================================

func activate_shuffle_booster():
	if not RewardManager.use_booster("shuffle"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_shuffle")
	if GameManager.shuffle_until_moves_available():
		await animate_shuffle()
	GameManager.processing_moves = false

func activate_swap_booster(x1: int, y1: int, x2: int, y2: int):
	if not RewardManager.use_booster("swap"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_swap")
	if GameManager.is_cell_blocked(x1, y1) or GameManager.is_cell_blocked(x2, y2):
		GameManager.processing_moves = false
		return
	var tile1 = tiles[x1][y1]
	var tile2 = tiles[x2][y2]
	if not tile1 or not tile2:
		GameManager.processing_moves = false
		return
	var temp = GameManager.grid[x1][y1]
	GameManager.grid[x1][y1] = GameManager.grid[x2][y2]
	GameManager.grid[x2][y2] = temp
	var tween1 = tile1.animate_swap_to(grid_to_world_position(Vector2(x2, y2)))
	var tween2 = tile2.animate_swap_to(grid_to_world_position(Vector2(x1, y1)))
	tiles[x1][y1] = tile2
	tiles[x2][y2] = tile1
	tile1.grid_position = Vector2(x2, y2)
	tile2.grid_position = Vector2(x1, y1)
	if tween1: await tween1.finished
	if tween2: await tween2.finished
	_check_collectibles_at_bottom()
	if GameManager.find_matches().size() > 0:
		await process_cascade()
	GameManager.processing_moves = false

func activate_chain_reaction_booster(x: int, y: int):
	if not RewardManager.use_booster("chain_reaction"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_chain")
	if GameManager.is_cell_blocked(x, y) or GameManager.get_tile_at(Vector2(x, y)) == GameManager.COLLECTIBLE:
		GameManager.processing_moves = false
		return
	# Use BoosterService to get the 3 waves of positions
	var waves: Array = BS.chain_reaction_waves(x, y, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else [[Vector2(x, y)], [], []]
	var total_scoring = 0
	for wave in waves:
		if wave.size() == 0:
			continue
		var valid = wave.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) > 0 and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
		if valid.size() == 0:
			continue
		await highlight_special_activation(valid)
		await animate_destroy_tiles(valid)
		for pos in valid:
			GameManager.grid[int(pos.x)][int(pos.y)] = 0
			total_scoring += 1
		await get_tree().create_timer(0.3).timeout
	var pts = GameManager.calculate_points(total_scoring)
	if pts > 0: GameManager.add_score(pts)
	await animate_gravity()
	await animate_refill()
	await process_cascade()
	GameManager.processing_moves = false

func activate_bomb_3x3_booster(x: int, y: int):
	if not RewardManager.use_booster("bomb_3x3"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_bomb_3x3")
	if GameManager.is_cell_blocked(x, y):
		GameManager.processing_moves = false
		return
	# Use BoosterService for position computation
	var all_pos: Array = BS.bomb_3x3_positions(x, y, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else []
	var positions_to_clear = all_pos.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)
		var pts = GameManager.calculate_points(positions_to_clear.size())
		for pos in positions_to_clear: GameManager.grid[int(pos.x)][int(pos.y)] = 0
		if pts > 0: GameManager.add_score(pts)
		await animate_gravity()
		await animate_refill()
		await process_cascade()
	GameManager.processing_moves = false

func activate_line_blast_booster(direction: String, center_x: int, center_y: int):
	if not RewardManager.use_booster("line_blast"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_line")
	# Use BoosterService for position computation
	var all_pos: Array = BS.line_blast_positions(direction, center_x, center_y, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else []
	var positions_to_clear = all_pos.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
	if positions_to_clear.size() > 0:
		# Lightning effect per row/col
		for offset in range(-1, 2):
			if direction == "horizontal":
				var ty = center_y + offset
				if ty >= 0 and ty < GameManager.GRID_HEIGHT:
					_create_lightning_beam_horizontal(ty, Color(1.0, 0.9, 0.2))
					await get_tree().create_timer(0.05).timeout
			else:
				var tx = center_x + offset
				if tx >= 0 and tx < GameManager.GRID_WIDTH:
					_create_lightning_beam_vertical(tx, Color(0.4, 0.9, 1.0))
					await get_tree().create_timer(0.05).timeout
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)
		var pts = GameManager.calculate_points(positions_to_clear.size())
		for pos in positions_to_clear: GameManager.grid[int(pos.x)][int(pos.y)] = 0
		if pts > 0: GameManager.add_score(pts)
		await animate_gravity()
		await animate_refill()
		await process_cascade()
	GameManager.processing_moves = false

func activate_hammer_booster(x: int, y: int):
	if not RewardManager.use_booster("hammer"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_hammer")
	if GameManager.is_cell_blocked(x, y) or GameManager.get_tile_at(Vector2(x, y)) == GameManager.COLLECTIBLE:
		GameManager.processing_moves = false
		return
	var positions_to_clear = [Vector2(x, y)]
	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)
	GameManager.grid[x][y] = 0
	var pts = GameManager.calculate_points(1)
	if pts > 0: GameManager.add_score(pts)
	await animate_gravity()
	await animate_refill()
	await process_cascade()
	GameManager.processing_moves = false

func activate_tile_squasher_booster(x: int, y: int):
	if not RewardManager.use_booster("tile_squasher"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_tile_squasher")
	var target_type = GameManager.get_tile_at(Vector2(x, y))
	if GameManager.is_cell_blocked(x, y) or target_type == GameManager.COLLECTIBLE or target_type >= 7:
		GameManager.processing_moves = false
		return
	# Use BoosterService for position computation
	var positions_to_clear: Array = BS.tile_squasher_positions(target_type, GameManager.grid, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else []
	positions_to_clear = positions_to_clear.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)))
	if positions_to_clear.size() > 0:
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)
		var pts = GameManager.calculate_points(positions_to_clear.size())
		for pos in positions_to_clear: GameManager.grid[int(pos.x)][int(pos.y)] = 0
		if pts > 0: GameManager.add_score(pts)
		await animate_gravity()
		await animate_refill()
		await process_cascade()
	GameManager.processing_moves = false

func activate_row_clear_booster(row: int):
	if not RewardManager.use_booster("row_clear"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_row_clear")
	var all_pos: Array = BS.row_clear_positions(row, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else []
	var positions_to_clear = all_pos.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
	if positions_to_clear.size() > 0:
		await _create_row_clear_effect(row)
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)
		var scoring_count = 0
		for pos in positions_to_clear:
			var gx = int(pos.x)
			var gy = int(pos.y)
			var tile_instance = tiles[gx][gy] if gx < tiles.size() and gy < tiles[gx].size() else null
			if tile_instance and tile_instance.is_unmovable_hard:
				var destroyed = tile_instance.take_hit(1)
				if destroyed:
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles[gx][gy] = null
					scoring_count += 1
			else:
				GameManager.grid[gx][gy] = 0
				scoring_count += 1
		var pts = GameManager.calculate_points(scoring_count)
		if pts > 0: GameManager.add_score(pts)
		await animate_gravity()
		await animate_refill()
		await process_cascade()
	GameManager.processing_moves = false

func activate_column_clear_booster(column: int):
	if not RewardManager.use_booster("column_clear"):
		return
	GameManager.processing_moves = true
	AudioManager.play_sfx("booster_column_clear")
	var all_pos: Array = BS.column_clear_positions(column, GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT) if BS != null else []
	var positions_to_clear = all_pos.filter(func(p): return not GameManager.is_cell_blocked(int(p.x), int(p.y)) and GameManager.get_tile_at(p) != GameManager.COLLECTIBLE)
	if positions_to_clear.size() > 0:
		await _create_column_clear_effect(column)
		await highlight_special_activation(positions_to_clear)
		await animate_destroy_tiles(positions_to_clear)
		var scoring_count = 0
		for pos in positions_to_clear:
			var gx = int(pos.x)
			var gy = int(pos.y)
			var tile_instance = tiles[gx][gy] if gx < tiles.size() and gy < tiles[gx].size() else null
			if tile_instance and tile_instance.is_unmovable_hard:
				var destroyed = tile_instance.take_hit(1)
				if destroyed:
					GameManager.grid[gx][gy] = 0
					if not tile_instance.is_queued_for_deletion(): tile_instance.queue_free()
					tiles[gx][gy] = null
					scoring_count += 1
			else:
				GameManager.grid[gx][gy] = 0
				scoring_count += 1
		var pts = GameManager.calculate_points(scoring_count)
		if pts > 0: GameManager.add_score(pts)
		await animate_gravity()
		await animate_refill()
		await process_cascade()
	GameManager.processing_moves = false

# ============================================
# Special tile activation
# ============================================

func activate_special_tile(pos: Vector2):
	# A5: Position computation delegated to SpecialActivationService
	print("activate_special_tile: start at ", pos)
	var tile_type = GameManager.get_tile_at(pos)
	print("Tile type at ", pos, " is ", tile_type)
	GameManager.processing_moves = true

	AudioManager.play_sfx("special_activate")

	EventBus.emit_special_tile_activated("tile_%d_%d" % [int(pos.x), int(pos.y)], {
		"position": pos,
		"tile_type": tile_type,
		"level": GameManager.level
	})

	# Delegate position computation to SpecialActivationService
	var activation_result = {}
	if BS != null and BS.has_method("compute_activation"):
		# Use BoosterService? No — use SpecialActivationService
		pass
	var sas = load("res://scripts/game/SpecialActivationService.gd")
	if sas != null:
		activation_result = sas.compute_activation(pos, tile_type, GameManager.grid,
			GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT, GameManager.COLLECTIBLE)

	var positions_to_clear: Array = activation_result.get("positions", [])
	var special_tiles_to_activate: Array = activation_result.get("specials", [])

	# Play type-specific audio and lightning effects, then destroy
	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		print("[GameBoard] Creating lightning for horizontal arrow at row ", int(pos.y))
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await _destroy_tiles_immediately(positions_to_clear)

	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		print("[GameBoard] Creating lightning for vertical arrow at column ", int(pos.x))
		_create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await _destroy_tiles_immediately(positions_to_clear)

	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		print("[GameBoard] Creating cross lightning for four-way arrow at ", pos)
		# Split into horizontal and vertical for staged visual effect
		var horizontal_positions = positions_to_clear.filter(func(p): return p.y == pos.y)
		var vertical_positions = positions_to_clear.filter(func(p): return p.x == pos.x and p.y != pos.y)
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		await _destroy_tiles_immediately(horizontal_positions)
		await get_tree().create_timer(0.05).timeout
		_create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))
		await _destroy_tiles_immediately(vertical_positions)

	print("Cleared ", positions_to_clear.size(), " tiles total, found ", special_tiles_to_activate.size(), " special tiles to chain")

	if GameManager.has_method("use_move") and not GameManager.in_bonus_conversion:
		GameManager.use_move()
	elif GameManager.in_bonus_conversion:
		print("[GameBoard] activate_special_tile: skipping use_move() because in_bonus_conversion=true")

	for special_tile_info in special_tiles_to_activate:
		AudioManager.play_sfx("booster_chain")
		await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])

	await animate_gravity()
	await animate_refill()
	await process_cascade()
	print("activate_special_tile: complete")

func activate_special_tile_chain(pos: Vector2, tile_type: int):
	# A5: Position computation delegated to SpecialActivationService
	print("Chain-activating special tile type ", tile_type, " at ", pos)

	var sas = load("res://scripts/game/SpecialActivationService.gd")
	var chain_result = {}
	if sas != null:
		chain_result = sas.compute_chain_activation(pos, tile_type, GameManager.grid,
			GameManager.GRID_WIDTH, GameManager.GRID_HEIGHT, GameManager.COLLECTIBLE)

	var positions_to_clear: Array = chain_result.get("positions", [])
	var chained_specials: Array = chain_result.get("specials", [])

	# Lightning visuals by type
	if tile_type == GameManager.HORIZTONAL_ARROW:
		AudioManager.play_sfx("special_horiz")
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.9, 0.3))
		await get_tree().create_timer(0.1).timeout
	elif tile_type == GameManager.VERTICAL_ARROW:
		AudioManager.play_sfx("special_vert")
		_create_lightning_beam_vertical(int(pos.x), Color(0.4, 0.9, 1.0))
		await get_tree().create_timer(0.1).timeout
	elif tile_type == GameManager.FOUR_WAY_ARROW:
		AudioManager.play_sfx("special_fourway")
		_create_lightning_beam_horizontal(int(pos.y), Color(1.0, 0.5, 1.0))
		await get_tree().create_timer(0.05).timeout
		_create_lightning_beam_vertical(int(pos.x), Color(1.0, 0.5, 1.0))
		await get_tree().create_timer(0.1).timeout

	await highlight_special_activation(positions_to_clear)
	await animate_destroy_tiles(positions_to_clear)

	var scoring_count = 0
	for clear_pos in positions_to_clear:
		var t = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		if not tiles or gx >= tiles.size():
			continue
		if not tiles[gx] or gy >= tiles[gx].size():
			continue

		var tile_instance = tiles[gx][gy]

		if tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)
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
					scoring_count += 1
		else:
			if t == GameManager.SPREADER:
				GameManager.spreader_count -= 1
				GameManager.spreader_positions.erase(clear_pos)
			GameManager.grid[gx][gy] = 0
			scoring_count += 1

	var pts = GameManager.calculate_points(scoring_count)
	if pts > 0:
		GameManager.add_score(pts)

	for special_tile_info in chained_specials:
		await activate_special_tile_chain(special_tile_info["pos"], special_tile_info["type"])


# ============================================
# Immediate tile destruction (for special tiles)
# ============================================

func _destroy_tiles_immediately(positions: Array):
	"""Destroy tiles immediately after lightning beam - handles unmovables properly"""
	if positions.size() == 0:
		return

	print("[GameBoard] _destroy_tiles_immediately: processing ", positions.size(), " positions")

	await highlight_special_activation(positions)

	var scoring_count = 0
	for clear_pos in positions:
		var t = GameManager.get_tile_at(clear_pos)
		if t > 0 and t != GameManager.COLLECTIBLE:
			scoring_count += 1

	print("[GameBoard] Pre-counted ", scoring_count, " tiles for scoring")

	await animate_destroy_tiles(positions)

	for clear_pos in positions:
		var t = GameManager.get_tile_at(clear_pos)
		var gx = int(clear_pos.x)
		var gy = int(clear_pos.y)

		print("[DESTROY_IMMEDIATE] Processing position (", gx, ",", gy, ") - grid value before: ", t)

		var tile_instance = null
		if tiles and gx < tiles.size() and tiles[gx] and gy < tiles[gx].size():
			tile_instance = tiles[gx][gy]

		if not tile_instance or not is_instance_valid(tile_instance):
			print("[DESTROY_IMMEDIATE] No valid tile instance at (", gx, ",", gy, ") - clearing grid anyway")

			if t == GameManager.SPREADER:
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)

			GameManager.grid[gx][gy] = 0
			print("[DESTROY_IMMEDIATE] Grid cleared (no instance) - now value: ", GameManager.grid[gx][gy])
			continue

		if "is_unmovable_hard" in tile_instance and tile_instance.is_unmovable_hard:
			var destroyed = tile_instance.take_hit(1)
			if destroyed:
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(clear_pos, true)
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
			if t == GameManager.SPREADER:
				if GameManager.has_method("report_spreader_destroyed"):
					GameManager.report_spreader_destroyed(clear_pos)
				else:
					GameManager.spreader_count -= 1
					GameManager.spreader_positions.erase(clear_pos)
			print("[DESTROY_IMMEDIATE] Clearing grid at (", gx, ",", gy, ") - was type ", t)
			GameManager.grid[gx][gy] = 0
			# Free the visual tile so it doesn't linger in the scene or get
			# picked up by animate_gravity / animate_refill.
			if tile_instance and not tile_instance.is_queued_for_deletion():
				tile_instance.queue_free()
			tiles[gx][gy] = null

	if GameManager.use_spreader_objective:
		GameManager.emit_signal("spreaders_changed", GameManager.spreader_count)
		if GameManager.spreader_count == 0:
			if not GameManager.pending_level_complete and not GameManager.level_transitioning:
				GameManager._attempt_level_complete()

	if scoring_count > 0:
		var points = GameManager.calculate_points(scoring_count)
		if points > 0:
			GameManager.add_score(points)

	print("[GameBoard] _destroy_tiles_immediately: complete, scored ", scoring_count, " tiles")

# ============================================
# Visual effect helpers
# ============================================

func _create_row_clear_effect(row: int):
	"""Create visual effect for clearing an entire row"""
	print("[GameBoard] Creating row clear lightning effect for row ", row)
	_create_lightning_beam_horizontal(row, Color(1.0, 1.0, 0.3))
	await get_tree().create_timer(0.02).timeout
	_create_lightning_beam_horizontal(row, Color(1.0, 0.8, 0.0))
	for x in range(GameManager.GRID_WIDTH):
		if not GameManager.is_cell_blocked(x, row):
			var pos = grid_to_world_position(Vector2(x, row))
			_create_impact_particles(pos, Color.YELLOW)

func _create_column_clear_effect(col: int):
	"""Create visual effect for clearing an entire column"""
	print("[GameBoard] Creating column clear lightning effect for column ", col)
	_create_lightning_beam_vertical(col, Color(0.3, 0.8, 1.0))
	await get_tree().create_timer(0.02).timeout
	_create_lightning_beam_vertical(col, Color(0.5, 1.0, 1.0))
	for y in range(GameManager.GRID_HEIGHT):
		if not GameManager.is_cell_blocked(col, y):
			var pos = grid_to_world_position(Vector2(col, y))
			_create_impact_particles(pos, Color.CYAN)

# ============================================
# Adjacent unmovable damage
# ============================================

func _damage_adjacent_unmovables(matched_positions: Array) -> void:
	## After a match is removed, deal 1 hit to every hard unmovable tile that is
	## orthogonally adjacent to any matched position.  Each unmovable is only hit
	## once per match event even if multiple matched tiles border it.
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var already_hit: Dictionary = {}  # key "x,y" -> true

	for pos in matched_positions:
		for dir in directions:
			var nx = int(pos.x) + int(dir.x)
			var ny = int(pos.y) + int(dir.y)
			if nx < 0 or nx >= GameManager.GRID_WIDTH or ny < 0 or ny >= GameManager.GRID_HEIGHT:
				continue
			var key = str(nx) + "," + str(ny)
			if already_hit.has(key):
				continue
			# Must be an unmovable cell
			if not GameManager._is_unmovable_cell(nx, ny):
				continue
			already_hit[key] = true

			# Get the visual tile
			if nx >= tiles.size() or ny >= tiles[nx].size():
				continue
			var tile = tiles[nx][ny]
			if not tile or not is_instance_valid(tile) or tile.is_queued_for_deletion():
				continue
			if not ("is_unmovable_hard" in tile) or not tile.is_unmovable_hard:
				continue

			print("[GameBoard] Adjacent hit on unmovable at (", nx, ",", ny, ")")
			var destroyed = tile.take_hit(1)
			if destroyed:
				print("[GameBoard] Unmovable at (", nx, ",", ny, ") destroyed by adjacent match")
				# Report destruction and update data
				var ukey = str(nx) + "," + str(ny)
				# Handle reveal: if tile transformed to a regular tile or collectible
				var revealed_type = tile.tile_type if "tile_type" in tile else 0
				var is_coll = tile.is_collectible if "is_collectible" in tile else false
				if is_coll:
					GameManager.grid[nx][ny] = GameManager.COLLECTIBLE
					# Keep tile in tiles array — it is now a collectible
				elif revealed_type > 0:
					GameManager.grid[nx][ny] = revealed_type
					# Keep tile in tiles array — it revealed a regular tile
				else:
					# Truly destroyed — clear data and free visual
					GameManager.grid[nx][ny] = 0
					tiles[nx][ny] = null
					if not tile.is_queued_for_deletion():
						tile.queue_free()
				# Notify GameManager / ObjectiveManager
				if GameManager.has_method("report_unmovable_destroyed"):
					GameManager.report_unmovable_destroyed(ukey, revealed_type > 0 or is_coll)
				elif GameManager.unmovable_map.has(ukey):
					GameManager.unmovable_map.erase(ukey)
					GameManager.unmovables_cleared += 1
					if GameManager.objective_manager_ref != null:
						GameManager.objective_manager_ref.report_unmovable_cleared(1)


# ============================================
# Adjacent spreader damage & visual spread
# ============================================

func _damage_adjacent_spreaders(matched_positions: Array) -> void:
	## Destroy any spreader tile that is orthogonally adjacent to a matched position.
	## Each spreader is only hit once per match event.
	var directions = [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]
	var already_hit: Dictionary = {}

	for pos in matched_positions:
		for dir in directions:
			var nx = int(pos.x) + int(dir.x)
			var ny = int(pos.y) + int(dir.y)
			if nx < 0 or nx >= GameManager.GRID_WIDTH or ny < 0 or ny >= GameManager.GRID_HEIGHT:
				continue
			var key = str(nx) + "," + str(ny)
			if already_hit.has(key):
				continue
			if GameManager.get_tile_at(Vector2(nx, ny)) != GameManager.SPREADER:
				continue
			already_hit[key] = true

			print("[GameBoard] Adjacent match destroying spreader at (", nx, ",", ny, ")")
			# Clear data
			GameManager.grid[nx][ny] = 0
			GameManager.report_spreader_destroyed(Vector2(nx, ny))
			# Destroy visual
			if nx < tiles.size() and ny < tiles[nx].size():
				var tile = tiles[nx][ny]
				if tile and is_instance_valid(tile) and not tile.is_queued_for_deletion():
					if tile.has_method("animate_destroy"):
						var dtw = tile.animate_destroy()
						# Disable input immediately so this dying tile can't ghost-fire
						# _input events during its ~0.3s death animation.
						tile.set_process_input(false)
						if dtw != null:
							dtw.connect("finished", tile.queue_free.bind(), CONNECT_ONE_SHOT)
						else:
							tile.queue_free()
					else:
						tile.queue_free()
				tiles[nx][ny] = null

func _apply_spreader_visuals(new_positions: Array) -> void:
	## Called after check_and_spread_tiles() returns newly infected positions.
	## Reconfigures the existing visual tile at each position to show spreader appearance.
	var scale_factor = tile_size / 64.0
	var textures: Array = []
	if GameManager.spreader_textures_map.has(GameManager.spreader_type):
		textures = GameManager.spreader_textures_map[GameManager.spreader_type]

	for pos in new_positions:
		var x = int(pos.x)
		var y = int(pos.y)
		if x >= tiles.size() or y >= tiles[x].size():
			continue

		var tile = tiles[x][y]
		if tile == null or not is_instance_valid(tile) or tile.is_queued_for_deletion():
			# No existing visual — spawn a fresh one
			var new_tile = tile_scene.instantiate()
			new_tile.setup(GameManager.SPREADER, pos, scale_factor)
			if new_tile.has_method("configure_spreader"):
				new_tile.configure_spreader(GameManager.spreader_grace_default, GameManager.spreader_type, textures)
			new_tile.position = grid_to_world_position(pos)
			new_tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
			new_tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
			if board_container:
				board_container.add_child(new_tile)
			else:
				add_child(new_tile)
			tiles[x][y] = new_tile
			print("[GameBoard] Spawned new spreader visual at (", x, ",", y, ")")
		else:
			# Reconfigure the existing tile in place — it keeps its position/tween state
			if tile.has_method("configure_spreader"):
				tile.configure_spreader(GameManager.spreader_grace_default, GameManager.spreader_type, textures)
			else:
				tile.update_type(GameManager.SPREADER)
			print("[GameBoard] Reconfigured tile at (", x, ",", y, ") as spreader")

func draw_board_borders():
	# A3: Delegated to BorderRenderer
	if typeof(GameManager) == TYPE_NIL:
		return
	if not GameManager.initialized or GameManager.grid == null or GameManager.grid.size() == 0:
		return
	if border_container == null:
		border_container = Node2D.new()
		border_container.name = "BorderContainer"
		if board_container:
			board_container.add_child(border_container)
		else:
			add_child(border_container)
	if BR != null:
		border_container = BR.draw_board_borders(self, border_container, GameManager, grid_offset, tile_size, border_color, BORDER_WIDTH)
	else:
		print("[GameBoard] BorderRenderer not loaded, skipping border draw")

# ============================================
# Debug auto-swap (disabled by default)
# ============================================

const DEBUG_AUTO_TEST_SWAP: bool = false  # Set true temporarily to auto-run a swap for debugging

func _debug_auto_swap() -> void:
	if not DEBUG_AUTO_TEST_SWAP:
		return
	var p1 = Vector2(0, 0)
	var p2 = Vector2(1, 0)
	print("[GameBoard][DEBUG] Auto-swap triggered: ", p1, " <-> ", p2)
	if tiles.size() == 0:
		print("[GameBoard][DEBUG] No tiles present for auto-swap")
		return
	var node_a = null
	var node_b = null
	if p1.x < tiles.size() and p1.y < tiles[int(p1.x)].size():
		node_a = tiles[int(p1.x)][int(p1.y)]
	if p2.x < tiles.size() and p2.y < tiles[int(p2.x)].size():
		node_b = tiles[int(p2.x)][int(p2.y)]
	if node_a and node_b:
		await perform_swap(node_a, node_b)
	print("[GameBoard][DEBUG] Auto-swap complete")

func _deferred_debug_auto_swap() -> void:
	if not DEBUG_AUTO_TEST_SWAP:
		return
	if get_tree():
		await get_tree().create_timer(0.25).timeout
	call_deferred("_debug_auto_swap")

