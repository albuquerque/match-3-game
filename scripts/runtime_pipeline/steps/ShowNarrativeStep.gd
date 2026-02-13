extends PipelineStep
class_name ShowNarrativeStep

## ShowNarrativeStep
## Shows a narrative stage and waits for completion

var stage_id: String = ""
var auto_advance_delay: float = 3.0
var skippable: bool = true

# Runtime UI pieces
var _overlay_layer: CanvasLayer = null
var _dimmer_poly: Polygon2D = null
var _board_prev_visible: bool = true
var _context: PipelineContext = null
var _auto_timer = null
var _safety_timer = null
var _hud_prev_visible: bool = true
var _booster_panel_prev_visible: bool = true
var _floating_menu_prev_visible: bool = true

func _init(stg_id: String = "", delay: float = 3.0, skip: bool = true):
	super("show_narrative")
	stage_id = stg_id
	auto_advance_delay = delay
	skippable = skip

func execute(context: PipelineContext) -> bool:
	# store context for cleanup
	_context = context

	if stage_id.is_empty():
		push_error("[ShowNarrativeStep] No stage_id provided")
		return false

	print("[ShowNarrativeStep] Showing narrative: %s (delay: %.1fs)" % [stage_id, auto_advance_delay])

	_context.waiting_for_completion = true
	_context.completion_type = "narrative"

	var root = null
	var tree = get_tree()
	if tree:
		root = tree.root
	if not root:
		push_error("[ShowNarrativeStep] Cannot access scene tree")
		return false

	# IMMEDIATELY hide the GameBoard to prevent old level from showing
	var board = _context.game_board if _context else null
	if not board:
		# Try to find it dynamically
		board = ExecutionContextBuilder._find_game_board() if ExecutionContextBuilder else null

	if board:
		_board_prev_visible = board.visible
		board.visible = false
		print("[ShowNarrativeStep] Hidden GameBoard to prevent old level from showing")

		# Hide the Tile Area Overlay (translucent panel behind tiles)
		var parent = board.get_parent()
		if parent:
			var tile_overlay = parent.get_node_or_null("TileAreaOverlay")
			if tile_overlay:
				tile_overlay.visible = false
				print("[ShowNarrativeStep] Hidden TileAreaOverlay")
	else:
		print("[ShowNarrativeStep] GameBoard not found, cannot hide it")

	# Also hide GameUI elements (HUD, BoosterPanel, FloatingMenu)
	var game_ui = _context.game_ui if _context else null
	if game_ui:
		# Hide HUD
		var hud = game_ui.get_node_or_null("VBoxContainer/TopPanel/HUD")
		if hud:
			_hud_prev_visible = hud.visible
			hud.visible = false
			print("[ShowNarrativeStep] Hidden HUD")

		# Hide BoosterPanel
		var booster_panel = game_ui.get_node_or_null("BoosterPanel")
		if booster_panel:
			_booster_panel_prev_visible = booster_panel.visible
			booster_panel.visible = false
			print("[ShowNarrativeStep] Hidden BoosterPanel")

		# Hide FloatingMenu
		var floating_menu = game_ui.get_node_or_null("FloatingMenu")
		if floating_menu:
			_floating_menu_prev_visible = floating_menu.visible
			floating_menu.visible = false
			print("[ShowNarrativeStep] Hidden FloatingMenu")
	else:
		print("[ShowNarrativeStep] GameUI not found in context")

	# Ensure a full-screen overlay exists (create if needed)
	_overlay_layer = _context.overlay_layer if _context else null
	if not _overlay_layer:
		_overlay_layer = CanvasLayer.new()
		_overlay_layer.name = "NarrativeOverlay"
		# Add to root so it's always on top
		root.add_child(_overlay_layer)
		if _context:
			_context.overlay_layer = _overlay_layer
	print("[ShowNarrativeStep] Overlay created: %s" % (_overlay_layer.get_path() if _overlay_layer else "none"))

	# Create narrative container for content and skip button
	var narrative_container = Control.new()
	narrative_container.name = "NarrativeContainer"
	if narrative_container.has_method("set_anchors_preset"):
		narrative_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	else:
		narrative_container.anchor_left = 0
		narrative_container.anchor_top = 0
		narrative_container.anchor_right = 1
		narrative_container.anchor_bottom = 1
	_overlay_layer.add_child(narrative_container)
	print("[ShowNarrativeStep] Narrative container added: %s" % (narrative_container.get_path()))

	# Create a dimmer polygon to fully cover the screen under the narrative (Polygon2D on CanvasLayer)
	if not _dimmer_poly:
		_dimmer_poly = Polygon2D.new()
		_dimmer_poly.name = "NarrativeDimmer"
		# Set color with alpha
		_dimmer_poly.color = Color(0, 0, 0, 0.6)
		# Build fullscreen polygon based on viewport size
		var vp = get_viewport().get_visible_rect().size if get_viewport() else Vector2.ZERO
		var poly = [Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)]
		_dimmer_poly.polygon = poly
		# Add to overlay layer (CanvasLayer expects Node2D children)
		_overlay_layer.add_child(_dimmer_poly)

	# Optional skip button in top-right
	if skippable:
		var skip_btn = Button.new()
		skip_btn.text = "Skip"
		skip_btn.name = "SkipButton"
		# Position in top-right corner using anchors only
		skip_btn.anchor_left = 1.0
		skip_btn.anchor_top = 0.0
		skip_btn.anchor_right = 1.0
		skip_btn.anchor_bottom = 0.0
		skip_btn.offset_left = -120
		skip_btn.offset_top = 20
		skip_btn.offset_right = -20
		skip_btn.offset_bottom = 60
		narrative_container.add_child(skip_btn)
		if not skip_btn.is_connected("pressed", Callable(self, "_on_skip_pressed")):
			skip_btn.connect("pressed", Callable(self, "_on_skip_pressed"))

	# Fade-in the narrative container (not the CanvasLayer)
	narrative_container.modulate = Color(1,1,1,0)
	var tween = get_tree().create_tween()
	tween.tween_property(narrative_container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if not narrative_manager:
		push_error("[ShowNarrativeStep] NarrativeStageManager not found")
		# still proceed but warn
		# ensure we can still auto-advance
		if auto_advance_delay > 0:
			_start_auto_advance_timer()
		return true

	var event_bus = root.get_node_or_null("/root/EventBus")
	print("[ShowNarrativeStep] EventBus available: %s" % (event_bus != null))
	if event_bus and event_bus.has_signal("narrative_stage_complete"):
		print("[ShowNarrativeStep] Connecting to EventBus.narrative_stage_complete")
		if not event_bus.narrative_stage_complete.is_connected(Callable(self, "_on_narrative_complete")):
			event_bus.narrative_stage_complete.connect(Callable(self, "_on_narrative_complete"))

	if narrative_manager.has_method("load_stage_by_id"):
		var loaded = narrative_manager.load_stage_by_id(stage_id)
		print("[ShowNarrativeStep] narrative_manager.load_stage_by_id returned: %s" % str(loaded))
		if loaded:
			if auto_advance_delay > 0:
				_start_auto_advance_timer()
			# start a safety timer to avoid indefinite hang
			_start_safety_timer()
			return true
		else:
			push_warning("[ShowNarrativeStep] Failed to load narrative: %s" % stage_id)
			# restore board visibility on failure
			if _context and _context.game_board:
				_context.game_board.visible = _board_prev_visible
			# remove overlay if we created it
			_cleanup_overlay(_context)
			return false

	# Fallback
	return false

func _start_auto_advance_timer():
	var tree: SceneTree = get_tree()
	if tree:
		_auto_timer = tree.create_timer(auto_advance_delay)
		print("[ShowNarrativeStep] Auto-advance timer started for %.2fs" % auto_advance_delay)
		# use Callable to connect the timeout signal
		_auto_timer.timeout.connect(Callable(self, "_on_auto_advance_timeout"))

func _start_safety_timer():
	var tree: SceneTree = get_tree()
	if tree:
		# safety delay: smaller during debugging to avoid long hangs
		var safety = max(3.0, auto_advance_delay + 1.0)
		_safety_timer = tree.create_timer(safety)
		print("[ShowNarrativeStep] Safety timer started for %.2fs" % safety)
		_safety_timer.timeout.connect(Callable(self, "_on_safety_timeout"))

func _on_auto_advance_timeout():
	print("[ShowNarrativeStep] Auto-advance timeout fired")
	_finish_and_emit()

func _on_safety_timeout():
	print("[ShowNarrativeStep] Safety timeout fired - forcing completion")
	_finish_and_emit()

func _on_narrative_complete(stg_id: String):
	if stg_id == stage_id:
		print("[ShowNarrativeStep] Narrative completed: %s" % stg_id)
		_finish_and_emit()

func _on_skip_pressed():
	print("[ShowNarrativeStep] Skip pressed")
	# Try to tell narrative manager to skip gracefully
	var tree = get_tree()
	if tree:
		var root = tree.root
		var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
		if narrative_manager and narrative_manager.has_method("skip_current"):
			narrative_manager.call("skip_current")
			return
	# Otherwise, finish
	_finish_and_emit()

func _finish_and_emit():
	# Start fade-out, then emit completion when finished
	# Use stored _context reference
	if _context:
		_context.waiting_for_completion = true
	else:
		# No context available; still proceed
		pass

	# Find the narrative container to fade it out
	var narrative_container = null
	if _overlay_layer and _overlay_layer.is_inside_tree():
		narrative_container = _overlay_layer.get_node_or_null("NarrativeContainer")

	if narrative_container and narrative_container is Control:
		var tween = get_tree().create_tween()
		tween.tween_property(narrative_container, "modulate:a", 0.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.connect("finished", Callable(self, "_on_fade_out_complete"))
	else:
		# No container to fade, just complete immediately
		step_completed.emit(true)

func _on_fade_out_complete():
	print("[ShowNarrativeStep] Fade-out complete")
	# Cleanup overlay then emit
	_cleanup_overlay(_context)
	# stop timers if active
	if _auto_timer:
		_auto_timer = null
	if _safety_timer:
		_safety_timer = null
	if _context:
		_context.waiting_for_completion = false
		_context.completion_type = ""
	step_completed.emit(true)

func cleanup():
	# Disconnect event and restore UI - but only if we're still in the tree
	if not is_inside_tree():
		# Step already removed from tree, cannot access EventBus
		# Just clear our references and return
		_auto_timer = null
		_safety_timer = null
		return

	var root = null
	var tree = get_tree()
	if tree:
		root = tree.root
	if root:
		var event_bus = root.get_node_or_null("/root/EventBus")
		if event_bus and event_bus.has_signal("narrative_stage_complete"):
			if event_bus.narrative_stage_complete.is_connected(Callable(self, "_on_narrative_complete")):
				event_bus.narrative_stage_complete.disconnect(Callable(self, "_on_narrative_complete"))

	# stop and clear timers
	_auto_timer = null
	_safety_timer = null

	# Restore board visibility
	if _context and _context.game_board:
		_context.game_board.visible = _board_prev_visible

	# Restore GameUI elements visibility
	if _context and _context.game_ui:
		var hud = _context.game_ui.get_node_or_null("VBoxContainer/TopPanel/HUD")
		if hud:
			hud.visible = _hud_prev_visible
			print("[ShowNarrativeStep] Restored HUD visibility")

		var booster_panel = _context.game_ui.get_node_or_null("BoosterPanel")
		if booster_panel:
			booster_panel.visible = _booster_panel_prev_visible
			print("[ShowNarrativeStep] Restored BoosterPanel visibility")

		var floating_menu = _context.game_ui.get_node_or_null("FloatingMenu")
		if floating_menu:
			floating_menu.visible = _floating_menu_prev_visible
			print("[ShowNarrativeStep] Restored FloatingMenu visibility")

	# Remove overlay/dimmer if we created them
	_cleanup_overlay(_context)

func _cleanup_overlay(context: PipelineContext) -> void:
	if _dimmer_poly and _dimmer_poly.is_inside_tree():
		_dimmer_poly.queue_free()
		_dimmer_poly = null
	# Remove overlay layer only if we created it for this context
	if _overlay_layer and _overlay_layer.is_inside_tree():
		_overlay_layer.queue_free()
		# Clear context.overlay_layer if it referenced this
		if context and context.overlay_layer == _overlay_layer:
			context.overlay_layer = null
		_overlay_layer = null
