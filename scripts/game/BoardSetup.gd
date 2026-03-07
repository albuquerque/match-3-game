extends Node
# BoardSetup — loaded as a script resource (via BLS var in GameBoard), not instanced directly

## BoardSetup — all layout calculation, background/overlay setup, board-group
## visibility helpers, and skip-bonus hint management.
## Step 3 of GameBoard Round 3 refactor.
## All methods are static; call them with the GameBoard node as first argument.

# ── Layout ────────────────────────────────────────────────────────────────────

static func calculate_responsive_layout(board: Node) -> void:
	var viewport = board.get_viewport()
	var screen_size = viewport.get_visible_rect().size

	var ui_top_space = 125.0   # HUDComponent is 120px tall; 5px gap above board
	var ui_bottom_space = 100.0
	var available_width = screen_size.x - (board.board_margin * 2)
	var available_height = screen_size.y - ui_top_space - ui_bottom_space - (board.board_margin * 2)

	var max_tile_size_width  = available_width  / GameManager.GRID_WIDTH
	var max_tile_size_height = available_height / GameManager.GRID_HEIGHT
	board.tile_size = min(max_tile_size_width, max_tile_size_height)
	board.tile_size = max(board.tile_size, 50.0)

	var total_grid_width  = GameManager.GRID_WIDTH  * board.tile_size
	var total_grid_height = GameManager.GRID_HEIGHT * board.tile_size

	board.grid_offset = Vector2(
		(screen_size.x - total_grid_width) / 2,
		ui_top_space + (available_height - total_grid_height) / 2
	)

	print("Screen size: ", screen_size)
	print("Calculated tile size: ", board.tile_size)
	print("Grid offset: ", board.grid_offset)

# ── Background / overlay ──────────────────────────────────────────────────────

static func setup_background(board: Node) -> void:
	var background = board.get_node_or_null("Background")
	if background:
		background.visible = false
		var board_size = Vector2(
			GameManager.GRID_WIDTH  * board.tile_size + 20,
			GameManager.GRID_HEIGHT * board.tile_size + 20
		)
		background.color    = board.BOARD_BACKGROUND_COLOR
		background.size     = board_size
		background.position = Vector2(board.grid_offset.x - 10, board.grid_offset.y - 10)

	setup_tile_area_overlay(board)

static func setup_tile_area_overlay(board: Node) -> void:
	# Destroy any existing overlay
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		var p = board.tile_area_overlay.get_parent()
		if p:
			p.remove_child(board.tile_area_overlay)
		board.tile_area_overlay.queue_free()
		board.tile_area_overlay = null

	# Remove orphaned overlays from parent
	var parent = board.get_parent()
	if parent:
		for child in parent.get_children():
			if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
				parent.remove_child(child)
				child.queue_free()

	# Remove orphaned overlays from self
	for child in board.get_children():
		if child and is_instance_valid(child) and child.name == "TileAreaOverlay":
			board.remove_child(child)
			child.queue_free()

	var overlay = Control.new()
	overlay.name         = "TileAreaOverlay"
	overlay.z_index      = -50
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	for x in range(GameManager.GRID_WIDTH):
		for y in range(GameManager.GRID_HEIGHT):
			if not GameManager.is_cell_blocked(x, y):
				var rect = ColorRect.new()
				rect.color        = Color(0.1, 0.15, 0.25, 0.5)
				rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				rect.position     = Vector2(x * board.tile_size + board.grid_offset.x,
				                           y * board.tile_size + board.grid_offset.y)
				rect.size         = Vector2(board.tile_size, board.tile_size)
				overlay.add_child(rect)

	board.tile_area_overlay = overlay

	if parent:
		parent.call_deferred("add_child", overlay)
		print("[BoardSetup] TileAreaOverlay added to parent (deferred): %s cells" % overlay.get_child_count())
	else:
		board.call_deferred("add_child", overlay)
		print("[BoardSetup] TileAreaOverlay added to self (deferred): %s cells" % overlay.get_child_count())

static func setup_background_image(board: Node) -> void:
	print("[BoardSetup] setup_background_image called with path: ", board.background_image_path)

	if board.background_sprite:
		board.background_sprite.queue_free()
		board.background_sprite = null

	if board.background_image_path == "":
		print("[BoardSetup] No background image path set")
		return

	if not ResourceLoader.exists(board.background_image_path):
		print("[BoardSetup] ERROR: Background image not found at: ", board.background_image_path)
		return

	var texture = load(board.background_image_path)
	if not texture:
		print("[BoardSetup] ERROR: Failed to load texture from: ", board.background_image_path)
		return

	var viewport = board.get_viewport()
	if not viewport:
		print("[BoardSetup] ERROR: No viewport available")
		return

	var bg_rect = TextureRect.new()
	bg_rect.name         = "BackgroundImage"
	bg_rect.texture      = texture
	bg_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.size         = viewport.get_visible_rect().size
	bg_rect.position     = Vector2.ZERO
	bg_rect.z_index      = -100
	board.background_sprite = bg_rect

	var parent = board.get_parent()
	if parent:
		board.call_deferred("_deferred_attach_background", bg_rect, parent)
		print("[BoardSetup] Background will be attached to parent (deferred): ", parent.name)
	else:
		board.call_deferred("add_child", bg_rect)
		board.call_deferred("move_child", bg_rect, 0)
		print("[BoardSetup] Background will be added to self (deferred)")

# ── Visibility helpers ────────────────────────────────────────────────────────

static func hide_tile_overlay(board: Node) -> void:
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.visible = false
		print("[BoardSetup] Tile overlay hidden")
	var background = board.get_node_or_null("Background")
	if background:
		background.visible = false

static func show_tile_overlay(board: Node) -> void:
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.visible = true
		print("[BoardSetup] Tile overlay shown")
	var background = board.get_node_or_null("Background")
	if background and board.background_image_path == "":
		background.visible = false

static func hide_board_group(board: Node) -> void:
	print("[BoardSetup] Hiding entire board group")
	if board.board_container and is_instance_valid(board.board_container):
		board.board_container.visible = false
		print("[BoardSetup]   - BoardContainer hidden")
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.visible = false
		print("[BoardSetup]   - TileAreaOverlay hidden")

static func show_board_group(board: Node) -> void:
	print("[BoardSetup] Showing entire board group")
	if board.board_container and is_instance_valid(board.board_container):
		board.board_container.visible = true
		print("[BoardSetup]   - BoardContainer shown")
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.visible = true
		print("[BoardSetup]   - TileAreaOverlay shown")

# ── Skip-bonus hint ───────────────────────────────────────────────────────────

static func show_skip_bonus_hint(board: Node) -> void:
	if board.skip_bonus_label:
		board.skip_bonus_label.visible = true
		board.skip_bonus_active = true
		return

	var lbl = Label.new()
	lbl.name                    = "SkipBonusLabel"
	lbl.text                    = "TAP TO SKIP ⏩"
	lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.3, 1.0))

	var viewport_size = board.get_viewport().get_visible_rect().size
	var board_bottom  = board.grid_offset.y + (board.tile_size * GameManager.GRID_HEIGHT)
	lbl.position              = Vector2(viewport_size.x / 2 - 150, board_bottom + 20)
	lbl.custom_minimum_size   = Vector2(300, 60)

	board.add_child(lbl)
	board.skip_bonus_label  = lbl
	board.skip_bonus_active = true

	var tween = board.create_tween()
	tween.set_loops(-1)
	tween.tween_property(lbl, "modulate:a", 0.5, 0.5)
	tween.tween_property(lbl, "modulate:a", 1.0, 0.5)
	print("[BoardSetup] Showing skip bonus hint")

static func hide_skip_bonus_hint(board: Node) -> void:
	if board.skip_bonus_label:
		board.skip_bonus_label.visible = false
	board.skip_bonus_active = false
	print("[BoardSetup] Hiding skip bonus hint")

# ── Level loaded setup (setup portion only) ───────────────────────────────────

static func on_level_loaded_setup(board: Node) -> void:
	## Called by GameBoard._on_level_loaded — handles all layout/visual setup.
	print("[BoardSetup] on_level_loaded_setup: start")

	hide_board_group(board)
	print("[BoardSetup] Board group hidden — will show after grid created")

	# Reset game-state flags
	if typeof(GameManager) != TYPE_NIL:
		GameManager.processing_moves       = false
		GameManager.level_transitioning    = false
		GameManager.pending_level_complete = false
		GameManager.pending_level_failed   = false
		GameManager.in_bonus_conversion    = false
		GameManager.reset_combo()
		print("[BoardSetup] Safety flags cleared")

	# Clean up old tile area overlay
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.queue_free()
		board.tile_area_overlay = null

	# Recalculate layout
	calculate_responsive_layout(board)
	setup_background(board)

	print("[BoardSetup][DEBUG] tile_size=", board.tile_size, " grid_offset=", board.grid_offset)

	# Hide the just-created overlay until the grid is ready
	if board.tile_area_overlay and is_instance_valid(board.tile_area_overlay):
		board.tile_area_overlay.visible = false

	setup_background_image(board)

	# Defer visual grid and borders
	board.call_deferred("create_visual_grid")
	board.call_deferred("_safe_draw_board_borders_deferred")

	# Show tile overlay after defer
	if board.tile_area_overlay:
		board.tile_area_overlay.visible = true

	# Reset skip hint
	if board.skip_bonus_label:
		hide_skip_bonus_hint(board)

	# Clear selection
	if board.selected_tile:
		board.selected_tile.set_selected(false)
		board.selected_tile = null

	print("[BoardSetup] on_level_loaded_setup: complete")
