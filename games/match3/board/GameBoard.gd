extends Node2D

signal level_loaded_ctx(level_id: String, context: Dictionary)
signal level_loaded()
signal level_complete()
signal level_failed()
signal game_over()
signal board_idle()
signal match_cleared(match_size: int, context: Dictionary)
signal pre_refill()
signal post_refill()
signal shard_tile_collected(item_id: String)
signal score_changed(new_score: int)
signal moves_changed(moves_left: int)
signal collectibles_changed(collected: int, target: int)
signal unmovables_changed(cleared: int, target: int)
signal spreaders_changed(current_count: int)
signal collectible_landed(pos: Vector2, coll_type: String)
signal unmovable_destroyed(pos: Vector2)
signal tile_destroyed(entity_id: String, context: Dictionary)
signal special_tile_activated(entity_id: String, context: Dictionary)
signal bonus_skipped()


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
var BV = null  # BoardVisuals
var BE = null  # BoardEffects

var _MatchFinder = null
var MatchOrchestrator = null

# GameStateBridge is loaded at runtime in _ready() to avoid parse-time preload failures
var GameStateBridge = null

var tiles = []
var selected_tile = null
var tile_scene = null

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

const COLLECTIBLE_SVC = preload("res://games/match3/board/services/CollectibleService.gd")

func _ready():
	print("[GameBoard] _ready: entry")
	# Lazy-load helper modules to avoid parse-time non-constant assignment errors
	# Load lightweight script references at runtime to avoid parse-time preload cycles
	if _MatchFinder == null:
		_MatchFinder = load("res://games/match3/board/services/MatchFinder.gd")
	# Load tile scene resource at runtime
	if tile_scene == null:
		tile_scene = load("res://scenes/Tile.tscn")

	if VF == null:
		VF = load("res://games/match3/board/services/VisualFactory.gd")
	if VE == null:
		VE = load("res://games/match3/board/services/VisualEffects.gd")
	if ER == null:
		ER = load("res://games/match3/board/services/EffectsRenderer.gd")
	if GS == null:
		GS = load("res://games/match3/board/services/GravityService.gd")
	if BR == null:
		BR = load("res://games/match3/board/services/BorderRenderer.gd")
	if BS == null:
		BS = load("res://games/match3/board/services/BoosterService.gd")
	if MO == null:
		MO = load("res://games/match3/board/services/MatchOrchestrator.gd")
		# Keep both references in sync to avoid accidental use of the wrong identifier
		MatchOrchestrator = MO
		print("[GameBoard] MatchOrchestrator loaded: MO=", MO)
	if GA == null:
		GA = load("res://games/match3/board/services/GravityAnimator.gd")
	if BLS == null:
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
	if BA == null:
		BA = load("res://games/match3/board/services/BoardAnimator.gd")
	if BAX == null:
		BAX = load("res://games/match3/board/services/BoardActionExecutor.gd")
		print("[GameBoard] BoardActionExecutor loaded: BAX=", BAX)
	if CS == null:
			# Use preloaded script resource; CollectibleService exposes static API
			CS = COLLECTIBLE_SVC
			if CS != null:
				print("[GameBoard] CollectibleService script loaded: CS=", CS)
			else:
				push_error("[GameBoard] Failed to preload CollectibleService script")
	if SS == null:
		SS = load("res://games/match3/board/services/SpreaderService.gd")
	if BV == null:
		BV = load("res://games/match3/board/services/BoardVisuals.gd")
	if BE == null:
		BE = load("res://games/match3/board/services/BoardEffects.gd")
	# Load GameStateBridge runtime shim
	if GameStateBridge == null:
		GameStateBridge = load("res://games/match3/services/GameStateBridge.gd")

	# Step 5: Instantiate BoardInputHandler as a child Node via loaded script var
	if BIH == null:
		var bih_script = load("res://games/match3/board/services/BoardInputHandler.gd")
		# Avoid calling `.new()` directly on loaded script resource; instead create a Node and attach the script
		var bih_node = Node.new()
		bih_node.name = "BoardInputHandler"
		bih_node.set_script(bih_script)
		add_child(bih_node)
		BIH = bih_node
		if BIH and BIH.has_method("setup"):
			BIH.setup(self)


	if GameRunState != null and GameRunState.initialized:
		create_visual_grid()
	else:
		print("[GameBoard] Waiting for GameRunState.initialized before creating visual grid")
		call_deferred("_wait_for_state_initialized")

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

	# Expose this board via GameRunState so services can reach tiles directly
	GameRunState.board_ref = self
	print("[GameBoard] _ready: GameRunState.board_ref set to", GameRunState.board_ref)

	# Use GameRunState.initialized directly.
	if GameRunState.initialized:
		create_visual_grid()
	else:
		print("[GameBoard] Waiting for level_loaded before creating visual grid")


func calculate_responsive_layout():
	# Step 3: Delegated to BoardSetup (robustly handle Script resource vs instance)
	if BLS == null:
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
		if BLS == null:
			push_error("[GameBoard] calculate_responsive_layout: failed to load BoardSetup")
			return
	var target = BLS
	# If load returned a Script resource, instantiate a temporary helper to access methods
	if BLS is Script:
		target = BLS.new()
	if target and target.has_method("calculate_responsive_layout"):
		target.calculate_responsive_layout(self)
	else:
		push_error("[GameBoard] calculate_responsive_layout: BoardSetup missing calculate_responsive_layout")


func setup_background():
	# Step 3: Delegated to BoardSetup (robust call)
	if BLS == null:
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
		if BLS == null:
			push_error("[GameBoard] setup_background: failed to load BoardSetup")
			return
	var target = BLS
	# If load returned a Script resource, instantiate a temporary helper to access methods
	if BLS is Script:
		target = BLS.new()
	if target and target.has_method("setup_background"):
		target.setup_background(self)
	else:
		push_error("[GameBoard] setup_background: BoardSetup missing setup_background")


func setup_tile_area_overlay():
	# Step 3: Delegated to BoardSetup (robust call)
	if BLS == null:
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
		if BLS == null:
			push_error("[GameBoard] setup_tile_area_overlay: failed to load BoardSetup")
			return
	var target = BLS
	# If load returned a Script resource, instantiate a temporary helper to access methods
	if BLS is Script:
		target = BLS.new()
	if target and target.has_method("setup_tile_area_overlay"):
		target.setup_tile_area_overlay(self)
	else:
		push_error("[GameBoard] setup_tile_area_overlay: BoardSetup missing setup_tile_area_overlay")


func setup_background_image():
	# Step 3: Delegated to BoardSetup (robust call)
	if BLS == null:
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
		if BLS == null:
			push_error("[GameBoard] setup_background_image: failed to load BoardSetup")
			return
	var target = BLS
	# If load returned a Script resource, instantiate a temporary helper to access methods
	if BLS is Script:
		target = BLS.new()
	if target and target.has_method("setup_background_image"):
		target.setup_background_image(self)
	else:
		push_error("[GameBoard] setup_background_image: BoardSetup missing setup_background_image")


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
			tile.configure_unmovable_hard(unmovable_meta.get("hits", 1), unmovable_meta.get("type", GameRunState.unmovable_type), textures_arr, reveals)

	if tile != null:
		tile.connect("tile_clicked", Callable(self, "_on_tile_clicked"))
		tile.connect("tile_swiped", Callable(self, "_on_tile_swiped"))
		if board_container:
			board_container.add_child(tile)
		else:
			add_child(tile)

	return tile


func create_visual_grid():
	print("[GameBoard] create_visual_grid: entry - BV=", BV)
	# Ensure BoardVisuals is loaded as a script resource exposing static API
	if BV == null:
		BV = load("res://games/match3/board/services/BoardVisuals.gd")
		print("[GameBoard] create_visual_grid: loaded BV=", BV)
	if BV == null:
		push_error("[GameBoard] create_visual_grid: BoardVisuals could not be loaded; aborting visual grid creation")
		return
	if not BV.has_method("create_visual_grid"):
		push_error("[GameBoard] create_visual_grid: BoardVisuals missing create_visual_grid method")
		return
	# Ensure tiles array exists
	if tiles == null:
		tiles = []
	print("[GameBoard] create_visual_grid: calling BV.create_visual_grid now")
	# Use the script resource's static function; fallback to explicit loader if needed
	var bv_local = BV
	if bv_local == null or not bv_local.has_method("create_visual_grid"):
		bv_local = load("res://games/match3/board/services/BoardVisuals.gd")
		print("[GameBoard] create_visual_grid: fallback load BV=", bv_local)
	if bv_local and bv_local.has_method("create_visual_grid"):
		await bv_local.create_visual_grid(self, tiles)
	else:
		push_error("[GameBoard] create_visual_grid: Unable to find create_visual_grid implementation on BoardVisuals")
	print("[GameBoard] create_visual_grid: returned from BV.create_visual_grid; tiles_len=", tiles.size())
	# Diagnostic: print tiles_ref dimensions and sample node names
	var cols = tiles.size()
	var rows = 0
	if cols > 0 and tiles[0] and typeof(tiles[0]) == TYPE_ARRAY:
		rows = tiles[0].size()
	print("[GameBoard] Diagnostic: tiles array dims: ", cols, "x", rows)
	if board_container:
		print("[GameBoard] board_container child_count=", board_container.get_child_count())
		var names = []
		for i in range(min(10, board_container.get_child_count())):
			names.append(board_container.get_child(i).name)
		print("[GameBoard] board_container sample children: ", names)
		# Detailed child diagnostics (print up to 50 children) to inspect tile internals
		for i in range(min(50, board_container.get_child_count())):
			var c = board_container.get_child(i)
			if c == null:
				continue
			# Determine visibility robustly: CanvasItem subclasses (Node2D/Control) expose 'visible'
			var vis = null
			if c is CanvasItem:
				vis = c.visible
			elif c.has_method("is_visible_in_tree"):
				vis = c.is_visible_in_tree()
			# Build base info
			var c_info = {"name": c.name, "class": c.get_class(), "visible": vis}
			# Attempt to read Sprite2D child and its texture info (Tile scene uses Sprite2D)
			var sprite_node = null
			if c.has_node("Sprite2D"):
				sprite_node = c.get_node_or_null("Sprite2D")
			if sprite_node and sprite_node is Sprite2D:
				var tex = sprite_node.texture if sprite_node.has_method("get") or sprite_node.has("texture") else sprite_node.texture
				c_info["sprite_texture"] = str(tex)
				c_info["sprite_scale"] = sprite_node.scale
				c_info["sprite_modulate"] = sprite_node.modulate
			else:
				c_info["sprite_texture"] = null
			# Position if available
			if c is Node2D:
				c_info["pos"] = c.global_position
			elif c.has_method("get") and c.has("position"):
				c_info["pos"] = c.position
			print("[GameBoard] child diag: ", c_info)
	return


func ensure_visuals() -> void:
	"""Compatibility helper: ensure the board visuals are present by directly invoking BoardVisuals.create_visual_grid.
	This is called deferred from GameStateBridge when there is a race between level load and board readiness."""
	print("[GameBoard] ensure_visuals: entry; tiles_len=", tiles.size())
	# Reset creating flag to allow re-creation if left stuck
	creating_visual_grid = false
	var bv = load("res://games/match3/board/services/BoardVisuals.gd")
	if bv == null:
		push_error("[GameBoard] ensure_visuals: failed to load BoardVisuals script resource")
		return
	if not bv.has_method("create_visual_grid"):
		push_error("[GameBoard] ensure_visuals: BoardVisuals missing create_visual_grid")
		return
	# Ensure tiles array
	if tiles == null:
		tiles = []
	await bv.create_visual_grid(self, tiles)
	print("[GameBoard] ensure_visuals: completed; tiles_len=", tiles.size())

# Collectible spawning and handling
func spawn_collectible_visual(x: int, y: int, coll_type: String = "coin"):
	if x < 0 or x >= GameRunState.GRID_WIDTH or y < 0 or y >= GameRunState.GRID_HEIGHT:
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
	BE.create_special_activation_particles(self, world_pos)

func _create_impact_particles(pos: Vector2, color: Color = Color(1,1,1,1)):
	BE.create_impact_particles(self, pos, color)

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
	BE.show_combo_text(self, match_count, positions, combo_multiplier)

func _apply_screen_shake(duration: float, intensity: float):
	BE.apply_screen_shake(self, duration, intensity)


func _on_game_over():
	print("[GameBoard] Game Over — disabling tile input")
	for x in range(GameRunState.GRID_WIDTH):
		for y in range(GameRunState.GRID_HEIGHT):
			var tile = tiles[x][y]
			if tile:
				tile.set_process_input(false)

func _attempt_level_complete() -> void:
	# Called by GameStateBridge — delegate to GameFlowController
	var gfc = get_node_or_null("GameFlowController")
	if gfc == null:
		var gfc_script = load("res://games/match3/board/services/GameFlowController.gd")
		if gfc_script:
			gfc = gfc_script.new()
			gfc.name = "GameFlowController"
			gfc.setup()
			add_child(gfc)
	if gfc:
		gfc.attempt_level_complete()

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
		print("[GameBoard] _on_level_loaded: BLS not loaded at runtime; attempting to load now")
		BLS = load("res://games/match3/board/services/BoardSetup.gd")
		if BLS == null:
			push_error("[GameBoard] _on_level_loaded: Failed to load BoardSetup; cannot set up visuals")
			return
		else:
			print("[GameBoard] _on_level_loaded: BoardSetup loaded at runtime: BLS=", BLS)
	# Wait briefly for GameRunState to be populated to avoid visual/model race
	var wait_attempts = 0
	while (not GameRunState.initialized) and wait_attempts < 20:
		# wait up to ~1 second (20 * 0.05)
		await get_tree().create_timer(0.05).timeout
		wait_attempts += 1
		print("[GameBoard] _on_level_loaded: waiting for GameRunState.initialized, attempt=", wait_attempts)
	if not GameRunState.initialized:
		print("[GameBoard] _on_level_loaded: WARNING - GameRunState not initialized after wait; proceeding anyway")
	if creating_visual_grid:
		print("[GameBoard] _on_level_loaded: skipping — visual grid creation already in progress")
		return
	BLS.on_level_loaded_setup(self)


func _on_external_remove_matches(matches: Array) -> void:
	# Called by GameStateBridge fallback path when remove_matches implementation is not available on the owner
	# This ensures visuals are destroyed to match GameRunState.grid being cleared.
	print("[GameBoard] _on_external_remove_matches called - matches=", matches.size())
	if BA == null:
		push_error("[GameBoard] _on_external_remove_matches: BoardAnimator (BA) not loaded")
		return
	# Animate destruction of matched visuals using BoardAnimator
	await BA.animate_destroy_matches(self, tiles, matches)
	# Ensure tiles array entries corresponding to matches are nulled
	for m in matches:
		var pos = m
		if typeof(m) == TYPE_DICTIONARY and m.has("x") and m.has("y"):
			pos = Vector2(float(m["x"]), float(m["y"]))
		if typeof(pos) != TYPE_VECTOR2:
			continue
		var gx = int(pos.x)
		var gy = int(pos.y)
		if gx >= 0 and gx < tiles.size() and gy >= 0 and gy < tiles[gx].size():
			tiles[gx][gy] = null
	print("[GameBoard] _on_external_remove_matches: visuals updated for matches")


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
	if grid_pos.x < 0 or grid_pos.x >= GameRunState.GRID_WIDTH:
		return
	if grid_pos.y < 0 or grid_pos.y >= GameRunState.GRID_HEIGHT:
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
			# Use GameStateBridge shim to avoid direct dependency on legacy manager during migration
			if GameStateBridge != null:
				GameStateBridge.skip_bonus_animation()
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
		await GA.animate_gravity(self, tiles)
	else:
		push_error("[GameBoard] GravityAnimator not loaded")

func animate_refill() -> Array:
	# A2: Delegated to GravityAnimator.animate_refill (via GA loaded script var)
	if GA != null:
		return await GA.animate_refill(self, tiles)
	push_error("[GameBoard] GravityAnimator not loaded")
	return []

func _check_collectibles_at_bottom():
	# Diagnostic: log that we're checking collectibles, plus basic grid/tiles info
	var cols := tiles.size() if typeof(tiles) == TYPE_ARRAY else 0
	var rows := 0
	if cols > 0 and tiles[0] and typeof(tiles[0]) == TYPE_ARRAY:
		rows = tiles[0].size()
	print("[GameBoard] _check_collectibles_at_bottom: cols=%d rows=%d GameRunState.GRID=(%d,%d)" % [cols, rows, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT])
	# Step 7: Delegated to CollectibleService - guard the call to avoid invalid-call errors
	var svc = CS
	if svc == null:
		svc = COLLECTIBLE_SVC
	if svc != null and svc.has_method("check_collectibles_at_bottom"):
		await svc.check_collectibles_at_bottom(self, tiles)
	else:
		push_error("[GameBoard] CollectibleService.check_collectibles_at_bottom not available (svc=%s)" % str(svc))

func _spawn_level_collectibles():
	# Step 7: Delegated to CollectibleService
	CS.spawn_level_collectibles()

# ============================================
# Cascade, shuffle, and special detection
# ============================================

func process_cascade(initial_swap_pos: Vector2 = Vector2(-1, -1)):
	# A1: Delegated to MatchOrchestrator (loaded at runtime to avoid parse-time cycles)
	if MO == null:
		MO = load("res://games/match3/board/services/MatchOrchestrator.gd")
		MatchOrchestrator = MO
	if MO != null:
		await MO.process_cascade(self, null, initial_swap_pos)
	else:
		print("[GameBoard] ERROR: MatchOrchestrator script not available")

func perform_auto_shuffle():
	"""Perform an automatic board shuffle with visual feedback"""
	print("Performing auto-shuffle animation...")
	if GameStateBridge.shuffle_until_moves_available():
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
	if GameRunState.pending_level_complete or GameRunState.level_transitioning:
		print("[GameBoard] deferred_gravity_then_refill aborted: level transition pending")
		return

	await animate_gravity()
	await animate_refill()
	# --- Safety tagging: some shard drops are queued into pending_shard_cells
	# Tag spawned tiles with their item_id so CollectibleService reliably detects them.
	var pending_map: Dictionary = GameRunState.pending_shard_cells if GameRunState.pending_shard_cells else {}
	if pending_map.size() > 0:
		var to_erase: Array = []
		for key in pending_map.keys():
			var parts = key.split(",")
			if parts.size() != 2:
				continue
			var px := int(parts[0])
			var py := int(parts[1])
			var iid := str(pending_map[key])
			if px >= 0 and px < tiles.size() and py >= 0 and py < tiles[px].size():
				var tnode = tiles[px][py]
				if tnode and is_instance_valid(tnode):
					tnode.set_meta("shard_item_id", iid)
					print("[GameBoard] Tagged tile at (%d,%d) with shard_item_id=%s from pending_shard_cells" % [px, py, iid])
					to_erase.append(key)
			elif px >= 0 and px < GameRunState.grid.size() and py >= 0 and py < GameRunState.grid[px].size() and GameRunState.grid[px][py] == GameRunState.COLLECTIBLE:
				# If this collectible sits at the bottom-most active row of its column, award immediately
				var last_row = -1
				for ry in range(GameRunState.GRID_HEIGHT - 1, -1, -1):
					if not (BR == null) and BR.has_method("is_cell_blocked") and not BR.is_cell_blocked(self, px, ry):
						last_row = ry
						break
				if last_row == py:
					print("[GameBoard] Direct-award pending shard %s at (%d,%d) because visual missing" % [iid, px, py])
					if GalleryManager:
						GalleryManager.add_shard(iid)
					to_erase.append(key)
		# clean up handled keys
		for k in to_erase:
			pending_map.erase(k)
		GameRunState.pending_shard_cells = pending_map

	await _check_collectibles_at_bottom()

	var exclude = [GameRunState.HORIZONTAL_ARROW, GameRunState.VERTICAL_ARROW, GameRunState.FOUR_WAY_ARROW, GameRunState.COLLECTIBLE, GameRunState.SPREADER, GameRunState.UNMOVABLE]
	var new_matches = _MatchFinder.find_matches(GameRunState.grid, GameRunState.GRID_WIDTH, GameRunState.GRID_HEIGHT, GameRunState.MIN_MATCH_SIZE, exclude, -1)
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
	print("[GameBoard] activate_special_tile called: pos=", pos, " BAX=", BAX)
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
	if not GameRunState.initialized or GameRunState.grid == null or GameRunState.grid.size() == 0:
		return
	if border_container == null:
		border_container = Node2D.new()
		border_container.name = "BorderContainer"
		if board_container:
			board_container.add_child(border_container)
		else:
			add_child(border_container)
	if BR != null:
		border_container = BR.draw_board_borders(self, border_container, null, grid_offset, tile_size, border_color, BORDER_WIDTH)
	else:
		print("[GameBoard] BorderRenderer not loaded, skipping border draw")
	# If borders drawn but tiles not created yet, schedule visual grid creation as a safety net
	if tiles == null or tiles.size() == 0:
		print("[GameBoard] draw_board_borders: tiles empty after border draw — scheduling create_visual_grid")
		# Use a deferred call to allow current frame to finish
		call_deferred("create_visual_grid")


func dev_force_shard_drop(px: int, py: int, item_id: String = "dev_shard_test") -> void:
	# Developer helper: force a collectible (shard) to appear at model pos (px,py) and process it.
	# Usage (remote console): get_node("/root/MainGame/GameBoard").call_deferred("dev_force_shard_drop", 3, 7, "my_test_shard")
	print("[GameBoard][dev] Forcing shard drop at (%d,%d) id=%s" % [px, py, item_id])
	# Guard: only run in debug builds or when explicit call is made
	# Set model value
	if GameRunState.grid.size() <= px:
		# extend columns
		while GameRunState.grid.size() <= px:
			GameRunState.grid.append([])
	if GameRunState.grid[px].size() <= py:
		while GameRunState.grid[px].size() <= py:
			GameRunState.grid[px].append(0)
	GameRunState.grid[px][py] = GameRunState.COLLECTIBLE

	# Register pending shard in GameRunState so CollectibleService can resolve item id
	var pend: Dictionary = {}
	if GameRunState.pending_shard_cells:
		pend = GameRunState.pending_shard_cells
	var key = str(px) + "," + str(py)
	pend[key] = item_id
	GameRunState.pending_shard_cells = pend
	print("[GameBoard][dev] Set GameRunState.pending_shard_cells[%s]=%s" % [key, item_id])

	# Kick the board processing so the collectible detection runs
	if has_method("deferred_gravity_then_refill"):
		call_deferred("deferred_gravity_then_refill")
	else:
		print("[GameBoard][dev] deferred_gravity_then_refill not available; call MatchOrchestrator.process_cascade or similar")

func _wait_for_state_initialized() -> void:
	# GameBoard owns all signals directly.
	# If GameRunState is already initialized, trigger level loaded handling now.
	if GameRunState.initialized:
		print("[GameBoard] _wait_for_state_initialized: GameRunState already initialized; calling _on_level_loaded")
		call_deferred("_on_level_loaded")
		return
	# Wait briefly for GameRunState to be initialized by LevelLoader
	var attempts = 0
	while attempts < 60:
		if GameRunState.initialized:
			print("[GameBoard] _wait_for_state_initialized: GameRunState initialized; calling _on_level_loaded")
			call_deferred("_on_level_loaded")
			return
		await get_tree().create_timer(0.05).timeout
		attempts += 1
	print("[GameBoard] _wait_for_state_initialized: GameRunState not initialized after wait")
