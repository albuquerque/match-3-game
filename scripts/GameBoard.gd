extends Node2D
class_name GameBoard

signal board_idle   ## Emitted when the board has settled: no matches, gravity done


# Safe script resource handles - avoid using load() at parse time which GDScript flags as non-constant
var VF = null
var VE = null
var ER = null
var GS = null
var BR = null
var BS = null
var MO = null  # MatchOrchestrator
var GA = null  # GravityAnimator
var BLS = null # BoardSetup
var BA = null  # BoardAnimator
var BIH = null # BoardInputHandler (Node child — loaded via script var)
var BAX = null # BoardActionExecutor
var CS = null  # CollectibleService
var SS = null  # SpreaderService



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
	if GA == null:
		GA = load("res://scripts/game/GravityAnimator.gd")
	if BLS == null:
		BLS = load("res://scripts/game/BoardSetup.gd")
	if BA == null:
		BA = load("res://scripts/game/BoardAnimator.gd")
	if BAX == null:
		BAX = load("res://scripts/game/BoardActionExecutor.gd")
	if CS == null:
		CS = load("res://scripts/game/CollectibleService.gd")
	if SS == null:
		SS = load("res://scripts/game/SpreaderService.gd")

	# Step 5: Instantiate BoardInputHandler as a child Node via loaded script
	if BIH == null:
		var bih_script = load("res://scripts/game/BoardInputHandler.gd")
		BIH = bih_script.new()
		BIH.name = "BoardInputHandler"
		add_child(BIH)
		BIH.setup(self)


	# Safely connect to GameManager signals if GameManager autoload is present
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.connect("game_over", Callable(self, "_on_game_over"))
		gm.connect("level_complete", Callable(self, "_on_level_complete"))
		gm.connect("level_loaded", Callable(self, "_on_level_loaded"))
	else:
		print("[GameBoard] WARNING: GameManager autoload not available at _ready(); will wait for level_loaded signal")

	# GameManager.level_loaded (no-arg signal) is the canonical trigger for _on_level_loaded.
	# Do NOT also connect EventBus.level_loaded — it fires in the same frame and would
	# cause on_level_loaded_setup to run twice, corrupting tile state.

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


func calculate_responsive_layout():
	# Step 3: Delegated to BoardSetup
	if BLS == null: return
	BLS.calculate_responsive_layout(self)

func setup_background():
	# Step 3: Delegated to BoardSetup
	if BLS == null: return
	BLS.setup_background(self)

func setup_tile_area_overlay():
	# Step 3: Delegated to BoardSetup
	if BLS == null: return
	BLS.setup_tile_area_overlay(self)

func setup_background_image():
	# Step 3: Delegated to BoardSetup
	if BLS == null: return
	BLS.setup_background_image(self)

func _deferred_attach_background(background_rect: Node, parent: Node) -> void:
	if not parent or not background_rect:
		return
	parent.add_child(background_rect)
	parent.move_child(background_rect, 0)
	var existing_bg = parent.get_node_or_null("Background")
	if existing_bg and existing_bg is ColorRect:
		existing_bg.visible = false


func set_border_color(color: Color):
	border_color = color
	call_deferred("_safe_draw_board_borders_deferred")

func set_background_image(image_path: String):
	background_image_path = image_path
	BLS.setup_background_image(self)

func hide_tile_overlay():
	BLS.hide_tile_overlay(self)

func show_tile_overlay():
	BLS.show_tile_overlay(self)

func hide_board_group():
	BLS.hide_board_group(self)

func show_board_group():
	BLS.show_board_group(self)

func set_board_group_visibility(is_visible: bool):
	if is_visible:
		show_board_group()
	else:
		hide_board_group()

func clear_tiles():
	# Step 4: Delegated to BoardAnimator
	BA.clear_tiles(self)

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
	# A8: Delegated to BoardVisuals.create_visual_grid
	await BoardVisuals.create_visual_grid(self, tiles)
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
	# Step 4: Delegated to BoardAnimator
	await BA.highlight_special_activation(self, tiles, positions)

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
	# Step 3: Layout/setup delegated to BoardSetup
	if BLS == null:
		push_error("[GameBoard] _on_level_loaded: BLS (BoardSetup) not loaded yet — skipping setup")
		return
	if creating_visual_grid:
		print("[GameBoard] _on_level_loaded: skipping — visual grid creation already in progress")
		return
	BLS.on_level_loaded_setup(self)



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
	# Step 3: Delegated to BoardSetup
	BLS.show_skip_bonus_hint(self)

func hide_skip_bonus_hint():
	# Step 3: Delegated to BoardSetup
	BLS.hide_skip_bonus_hint(self)

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
	# Step 5: Delegated to BoardInputHandler
	print("[GameBoard] _on_tile_clicked: BIH=", BIH, " valid=", is_instance_valid(BIH) if BIH else false)
	if BIH and is_instance_valid(BIH):
		await BIH.handle_tile_clicked(tile)

func _on_tile_swiped(tile, direction: Vector2):
	# Step 5: Delegated to BoardInputHandler
	print("[GameBoard] _on_tile_swiped: BIH=", BIH, " valid=", is_instance_valid(BIH) if BIH else false)
	if BIH and is_instance_valid(BIH):
		await BIH.handle_tile_swiped(tile, direction)

func perform_swap(tile1, tile2):
	# Step 5: Delegated to BoardInputHandler
	if BIH:
		await BIH.perform_swap(tile1, tile2)

# ============================================
# Match destruction and animation functions
# ============================================


func animate_destroy_tiles(positions: Array):
	# Step 4: Delegated to BoardAnimator
	await BA.animate_destroy_tiles(self, tiles, positions)

func animate_destroy_matches(matches: Array):
	# Step 4: Delegated to BoardAnimator
	await BA.animate_destroy_matches(self, tiles, matches)

func animate_destroy_matches_except(matches: Array, skip_pos: Vector2):
	# Step 4: Delegated to BoardAnimator
	await BA.animate_destroy_matches_except(self, tiles, matches, skip_pos)

# ============================================
# Gravity and refill
# ============================================

func animate_gravity() -> void:
	# A2: Delegated to GravityAnimator.animate_gravity (via GA loaded script var)
	if GA != null:
		await GA.animate_gravity(GameManager, self, tiles)
	else:
		push_error("[GameBoard] GravityAnimator not loaded")

func animate_refill() -> Array:
	# A2: Delegated to GravityAnimator.animate_refill (via GA loaded script var)
	if GA != null:
		return await GA.animate_refill(GameManager, self, tiles)
	push_error("[GameBoard] GravityAnimator not loaded")
	return []

func _check_collectibles_at_bottom():
	# Step 7: Delegated to CollectibleService
	await CS.check_collectibles_at_bottom(self, tiles)

func _spawn_level_collectibles():
	# Step 7: Delegated to CollectibleService
	CS.spawn_level_collectibles()

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
	# Step 4: Delegated to BoardAnimator
	await BA.animate_shuffle(self, tiles)

func find_special_tile_position_in_matches(matches: Array) -> Vector2:
	# Step 4: Delegated to BoardAnimator
	return BA.find_special_tile_position_in_matches(matches)

func highlight_matches(matches: Array):
	# Step 4: Delegated to BoardAnimator
	await BA.highlight_matches(self, tiles, matches)

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
	await BAX.activate_shuffle_booster(self)

func activate_swap_booster(x1: int, y1: int, x2: int, y2: int):
	await BAX.activate_swap_booster(self, tiles, x1, y1, x2, y2)

func activate_chain_reaction_booster(x: int, y: int):
	await BAX.activate_chain_reaction_booster(self, BS, x, y)

func activate_bomb_3x3_booster(x: int, y: int):
	await BAX.activate_bomb_3x3_booster(self, BS, x, y)

func activate_line_blast_booster(direction: String, center_x: int, center_y: int):
	await BAX.activate_line_blast_booster(self, BS, direction, center_x, center_y)

func activate_hammer_booster(x: int, y: int):
	await BAX.activate_hammer_booster(self, x, y)

func activate_tile_squasher_booster(x: int, y: int):
	await BAX.activate_tile_squasher_booster(self, BS, x, y)

func activate_row_clear_booster(row: int):
	await BAX.activate_row_clear_booster(self, BS, tiles, row)

func activate_column_clear_booster(column: int):
	await BAX.activate_column_clear_booster(self, BS, tiles, column)

# ============================================
# Special tile activation
# ============================================

func activate_special_tile(pos: Vector2):
	# Step 6: Delegated to BoardActionExecutor
	await BAX.activate_special_tile(self, pos)

func activate_special_tile_chain(pos: Vector2, tile_type: int):
	# Step 6: Delegated to BoardActionExecutor
	await BAX.activate_special_tile_chain(self, pos, tile_type)

func _destroy_tiles_immediately(positions: Array):
	# Step 6: Delegated to BoardActionExecutor
	await BAX.destroy_tiles_immediately(self, positions)

# ============================================
# Visual effect helpers (thin wrappers over EffectsRenderer)
# ============================================


# ============================================
# Adjacent unmovable damage
# ============================================

func _damage_adjacent_unmovables(matched_positions: Array) -> void:
	# Step 8: Delegated to SpreaderService
	if SS != null:
		SS.call("damage_adjacent_unmovables", self, tiles, matched_positions)

# ============================================
# Adjacent spreader damage & visual spread
# ============================================

func _damage_adjacent_spreaders(matched_positions: Array) -> void:
	# Step 8: Delegated to SpreaderService
	if SS != null:
		SS.call("damage_adjacent_spreaders", self, tiles, matched_positions)

func _apply_spreader_visuals(new_positions: Array) -> void:
	# Step 8: Delegated to SpreaderService
	if SS != null:
		SS.call("apply_spreader_visuals", self, tiles, new_positions)

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


