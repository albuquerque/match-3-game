extends PipelineStep
class_name ShowNarrativeStep

## ShowNarrativeStep
## Shows a narrative stage and waits for completion

var stage_id: String = ""
var auto_advance_delay: float = 3.0
var skippable: bool = true

# Runtime UI pieces
var _overlay_layer: CanvasLayer = null
var _dimmer_rect: ColorRect = null
var _board_prev_visible: bool = true
var _context: PipelineContext = null
var _auto_timer = null
var _safety_timer = null
var _hud_prev_visible: bool = true
var _booster_panel_prev_visible: bool = true
var _floating_menu_prev_visible: bool = true
var _controller_conn: Object = null
var _skip_button: Button = null
var _finished: bool = false
var _exec_start_time: int = 0
var _pending_state_timers: Dictionary = {}
var _state_timer_seq: int = 0
var _overlay_watchdog: Timer = null

func _init(stg_id: String = "", delay: float = 3.0, skip: bool = true):
	super("show_narrative")
	stage_id = stg_id
	auto_advance_delay = delay
	skippable = skip

func execute(context: PipelineContext) -> bool:
	# store context for cleanup
	_context = context

	# record start time
	_exec_start_time = Time.get_ticks_msec()
	print("[ShowNarrativeStep][ts] execute start ms=", _exec_start_time)

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
		# Make sure overlay is above other CanvasLayers
		_overlay_layer.layer = 1000
		if _context:
			_context.overlay_layer = _overlay_layer
	print("[ShowNarrativeStep] Overlay created: %s" % (_overlay_layer.get_path() if _overlay_layer else "none"))
	print("[ShowNarrativeStep][ts] overlay created ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)

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
	# Ensure narrative container renders above the dimmer
	narrative_container.z_index = 10
	# Prevent clicks from falling through the narrative container
	narrative_container.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay_layer.add_child(narrative_container)
	print("[ShowNarrativeStep] Narrative container added: %s" % (narrative_container.get_path()))
	# Debug: log children of narrative_container after creation
	print("[ShowNarrativeStep] _inline children after_creation for: ", narrative_container.get_path())
	for _c in narrative_container.get_children():
		if typeof(_c) == TYPE_OBJECT and _c is Node:
			print("  - child: ", _c.name, " (path:", _c.get_path(), ") type:", _c.get_class())

	# Overlay watchdog: give renderer/background time to attach (0.6s), then verify meaningful visuals exist
	_overlay_watchdog = Timer.new()
	_overlay_watchdog.one_shot = true
	_overlay_watchdog.wait_time = 0.6
	_overlay_watchdog.connect("timeout", Callable(self, "_on_overlay_watchdog"))
	narrative_container.add_child(_overlay_watchdog)
	_overlay_watchdog.start()

	# Create a ColorRect dimmer inside the narrative container so it shares the same Control hierarchy
	if not _dimmer_rect:
		_dimmer_rect = ColorRect.new()
		_dimmer_rect.name = "NarrativeDimmer"
		# Fill the full rect
		if _dimmer_rect.has_method("set_anchors_preset"):
			_dimmer_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		else:
			_dimmer_rect.anchor_left = 0
			_dimmer_rect.anchor_top = 0
			_dimmer_rect.anchor_right = 1
			_dimmer_rect.anchor_bottom = 1
		# Default: fully transparent; stage JSON may opt-in to a dimmer
		_dimmer_rect.color = Color(0, 0, 0, 0.0)
		# Ensure dimmer sits behind narrative content within the container
		_dimmer_rect.z_index = 0
		# Let underlying controls still receive mouse events through the container policy; dimmer itself ignores mouse
		_dimmer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		narrative_container.add_child(_dimmer_rect)
		print("[ShowNarrativeStep] Added ColorRect dimmer to NarrativeContainer")

	# Optional skip button in top-right
	print("[ShowNarrativeStep] skippable = %s" % skippable)
	if skippable:
		print("[ShowNarrativeStep] Creating skip button...")
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
		# Ensure the skip button sits above any rendered image and captures input
		skip_btn.z_index = 2000
		skip_btn.mouse_filter = Control.MOUSE_FILTER_STOP

		# Add styling to make button visible and attractive
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Semi-transparent dark background
		style_normal.border_width_left = 2
		style_normal.border_width_right = 2
		style_normal.border_width_top = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color(0.8, 0.8, 0.8, 1.0)  # Light border
		style_normal.corner_radius_top_left = 5
		style_normal.corner_radius_top_right = 5
		style_normal.corner_radius_bottom_left = 5
		style_normal.corner_radius_bottom_right = 5
		skip_btn.add_theme_stylebox_override("normal", style_normal)

		var style_hover = StyleBoxFlat.new()
		style_hover.bg_color = Color(0.3, 0.3, 0.3, 0.9)  # Brighter on hover
		style_hover.border_width_left = 2
		style_hover.border_width_right = 2
		style_hover.border_width_top = 2
		style_hover.border_width_bottom = 2
		style_hover.border_color = Color(1.0, 1.0, 1.0, 1.0)  # White border on hover
		style_hover.corner_radius_top_left = 5
		style_hover.corner_radius_top_right = 5
		style_hover.corner_radius_bottom_left = 5
		style_hover.corner_radius_bottom_right = 5
		skip_btn.add_theme_stylebox_override("hover", style_hover)

		var style_pressed = StyleBoxFlat.new()
		style_pressed.bg_color = Color(0.1, 0.1, 0.1, 0.9)  # Darker when pressed
		style_pressed.border_width_left = 2
		style_pressed.border_width_right = 2
		style_pressed.border_width_top = 2
		style_pressed.border_width_bottom = 2
		style_pressed.border_color = Color(0.6, 0.6, 0.6, 1.0)
		style_pressed.corner_radius_top_left = 5
		style_pressed.corner_radius_top_right = 5
		style_pressed.corner_radius_bottom_left = 5
		style_pressed.corner_radius_bottom_right = 5
		skip_btn.add_theme_stylebox_override("pressed", style_pressed)

		# Set text color to be visible
		skip_btn.add_theme_color_override("font_color", Color.WHITE)
		skip_btn.add_theme_color_override("font_hover_color", Color.YELLOW)
		skip_btn.add_theme_color_override("font_pressed_color", Color.GRAY)

		narrative_container.add_child(skip_btn)
		print("[ShowNarrativeStep] ✓ Skip button created and added to NarrativeContainer")
		# store persistent reference so we can raise it after visuals areadded by renderer
		_skip_button = skip_btn
		if not _skip_button.is_connected("pressed", Callable(self, "_on_skip_pressed")):
			_skip_button.connect("pressed", Callable(self, "_on_skip_pressed"))
			print("[ShowNarrativeStep] ✓ Skip button connected to _on_skip_pressed")
	else:
		print("[ShowNarrativeStep] Skip button disabled (skippable = false)")

	# Fade-in the narrative container (not the CanvasLayer)
	narrative_container.modulate = Color(1,1,1,0)
	var tween = get_tree().create_tween()
	tween.tween_property(narrative_container, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if not narrative_manager:
		print("[ShowNarrativeStep] NarrativeStageManager not found - attempting local renderer fallback")
		# Try to load the renderer script dynamically and render the stage ourselves as a fallback
		var rs = load("res://scripts/NarrativeStageRenderer.gd")
		var local_renderer = null
		if rs and rs is Script:
			local_renderer = Control.new()
			local_renderer.name = "LocalNarrativeRenderer"
			local_renderer.set_script(rs)
			# add to our narrative container so visuals appear above dimmer
			narrative_container.add_child(local_renderer)
			print("[ShowNarrativeStep] Local renderer instantiated and added to NarrativeContainer")

		# Load stage JSON directly and render its first state as a best-effort
		var stage_path_f = "res://data/narrative_stages/%s.json" % stage_id
		if FileAccess.file_exists(stage_path_f):
			var f = FileAccess.open(stage_path_f, FileAccess.READ)
			if f:
				var txt = f.get_as_text()
				f.close()
				var parsed = JSON.parse_string(txt)
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has("result"):
					var sd = parsed.get("result")
					if sd and sd.has("states") and sd["states"].size() > 0:
						var first_state = sd["states"][0]
						# If we have a renderer instance, ask it to render the full state (text+asset)
						if local_renderer and local_renderer.has_method("render_state"):
							local_renderer.render_state(first_state)
							print("[ShowNarrativeStep] Local renderer rendered first state of stage: ", stage_id)
							# apply dimmer alpha if specified
							if sd.has("dimmer_alpha"):
								var ca = sd.get("dimmer_alpha", 0.0)
								if _dimmer_rect and _dimmer_rect.is_inside_tree():
									var cc = _dimmer_rect.color
									cc.a = float(ca)
									_dimmer_rect.color = cc
									print("[ShowNarrativeStep] Applied local dimmer alpha:", ca)
							# Schedule safety timer based on total durations
							var total_dur = 0.0
							for st in sd["states"]:
								total_dur += float(st.get("duration", 0.0))
							if total_dur <= 0.0:
								total_dur = auto_advance_delay if auto_advance_delay > 0 else 3.0
							_start_safety_timer(total_dur + 1.0)
						else:
							print("[ShowNarrativeStep] Stage JSON missing states for: ", stage_id)
				else:
					print("[ShowNarrativeStep] Failed to parse stage JSON for fallback: ", stage_path_f)
			else:
				print("[ShowNarrativeStep] Could not open stage file for fallback: ", stage_path_f)
		else:
			print("[ShowNarrativeStep] Fallback renderer script not available; cannot show narrative (will auto-advance)")
			# start auto advance as last resort
			if auto_advance_delay > 0:
				_start_auto_advance_timer()
		# Continue - let the pipeline wait for completion; step will finish when timer or skip triggers
		return true

	var event_bus = root.get_node_or_null("/root/EventBus")
	print("[ShowNarrativeStep] EventBus available: %s" % (event_bus != null))
	if event_bus and event_bus.has_signal("narrative_stage_complete"):
		print("[ShowNarrativeStep] Connecting to EventBus.narrative_stage_complete")
		if not event_bus.narrative_stage_complete.is_connected(Callable(self, "_on_narrative_complete")):
			event_bus.narrative_stage_complete.connect(Callable(self, "_on_narrative_complete"))

	if narrative_manager.has_method("load_stage_by_id"):
		# Lock NarrativeStageManager to prevent level-based auto-loads from replacing this pipeline-driven stage
		if narrative_manager.has_method("lock_stage"):
			narrative_manager.lock_stage(true)
			print("[ShowNarrativeStep] Locked NarrativeStageManager for stage: %s" % stage_id)
		# If renderer supports rendering into a provided container, prefer to render into our NarrativeContainer
		if narrative_manager.renderer != null and narrative_container != null:
			if narrative_manager.renderer.has_method("set_render_container"):
				# set the render container so visuals are added inside the overlay layer (above dimmer)
				narrative_manager.renderer.set_render_container(narrative_container)
				print("[ShowNarrativeStep] Set renderer render_container to NarrativeContainer")

		var loaded = narrative_manager.load_stage_by_id(stage_id)
		print("[ShowNarrativeStep] narrative_manager.load_stage_by_id returned: %s" % str(loaded))
		print("[ShowNarrativeStep][ts] load_stage_by_id return ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
		if loaded:
			# Force-render current controller state into our narrative_container if controller set a state but visuals didn't appear due to ordering races
			if narrative_manager.controller != null and narrative_manager.renderer != null:
				var ctrl = narrative_manager.controller
				var rdr = narrative_manager.renderer
				# If controller has a current_state and renderer exposes render_state, attempt to render it explicitly
				if ctrl.current_state != "" and rdr.has_method("render_state"):
					# Find the state definition in controller.current_stage_data
					var csd = ctrl.current_stage_data if ctrl else null
					var state_def = null
					if csd and csd.has("states"):
						for s in csd["states"]:
							if s.get("name", "") == ctrl.current_state:
								state_def = s
								break
					# Prepare render_state_data similar to controller._set_state (inject anchor if missing)
					if state_def != null:
						var render_state_data = {}
						for k in state_def.keys():
							render_state_data[k] = state_def[k]
						if not render_state_data.has("position"):
							var stag_anchor = ctrl.current_stage_data.get("anchor", "")
							if stag_anchor != "":
								render_state_data["position"] = stag_anchor
						print("[ShowNarrativeStep] Forcing renderer to render current_state=", ctrl.current_state, " with asset=", render_state_data.get("asset", "(none)"))
						# Call render_state on renderer now
						rdr.render_state(render_state_data)
						# If renderer created visuals under a different parent (race), move them into narrative_container
						if rdr.current_visual and rdr.current_visual.is_inside_tree():
							var vis_parent = rdr.current_visual.get_parent()
							print("[ShowNarrativeStep] Renderer placed visual under: ", vis_parent.name if vis_parent else "(no parent)")
							if vis_parent != narrative_container:
								# Reparent visual into our overlay container
								if vis_parent:
									vis_parent.remove_child(rdr.current_visual)
								narrative_container.add_child(rdr.current_visual)
								rdr.current_visual.z_index = 100
								print("[ShowNarrativeStep] Moved renderer visual into NarrativeContainer")

							# CRITICAL: Ensure skip button is above visuals by moving it to front
							if _skip_button and _skip_button.is_inside_tree():
								narrative_container.move_child(_skip_button, -1)  # Move to end (rendered last = on top)
								print("[ShowNarrativeStep] Moved skip button to front (above visuals)")
							# Also move renderer's current_text_label if present
							if rdr.current_text_label and rdr.current_text_label.is_inside_tree():
								var tpar = rdr.current_text_label.get_parent()
								if tpar != narrative_container:
									if tpar:
										tpar.remove_child(rdr.current_text_label)
										narrative_container.add_child(rdr.current_text_label)
									print("[ShowNarrativeStep] Moved renderer text label into NarrativeContainer")
									# Ensure skip button is still on top after text is added
									if _skip_button and _skip_button.is_inside_tree():
										narrative_container.move_child(_skip_button, -1)
										print("[ShowNarrativeStep] Re-raised skip button after text label")
						else:
							print("[ShowNarrativeStep] Renderer did not create a visual (current_visual null) after render_state call")
							# Fallback: try to ask renderer to load and display the state's asset directly
							var fallback_asset = null
							if state_def and state_def.has("asset"):
								fallback_asset = state_def.get("asset")
							elif ctrl.current_stage_data and ctrl.current_stage_data.has("states") and ctrl.current_stage_data["states"].size() > 0:
								fallback_asset = ctrl.current_stage_data["states"][0].get("asset", null)
							if fallback_asset and fallback_asset != "":
								print("[ShowNarrativeStep] Fallback: attempting to load asset via renderer: ", fallback_asset)
								# Use public API (display_asset) to show asset; this will also set z_index appropriately
								if rdr.has_method("display_asset"):
									var pos_mode = state_def.get("position", ctrl.current_stage_data.get("anchor", "top_banner")) if state_def else ctrl.current_stage_data.get("anchor", "top_banner")
									var ok = rdr.display_asset(fallback_asset, pos_mode)
									if ok:
										print("[ShowNarrativeStep] Fallback: renderer.display_asset succeeded for: ", fallback_asset)
										# If renderer created visuals under a different parent, move them into narrative_container
										if rdr.current_visual and rdr.current_visual.is_inside_tree():
											var pv = rdr.current_visual.get_parent()
											if pv != narrative_container:
												if pv:
													pv.remove_child(rdr.current_visual)
												narrative_container.add_child(rdr.current_visual)
												rdr.current_visual.z_index = 100
												print("[ShowNarrativeStep] Fallback: moved renderer visual into NarrativeContainer")
										# Move text if present
										if rdr.current_text_label and rdr.current_text_label.is_inside_tree():
											var tpp = rdr.current_text_label.get_parent()
											if tpp and tpp != narrative_container:
												tpp.remove_child(rdr.current_text_label)
												narrative_container.add_child(rdr.current_text_label)
											print("[ShowNarrativeStep] Fallback: moved renderer text label into NarrativeContainer")
										# CRITICAL: Ensure skip button is on top after all visuals
										if _skip_button and _skip_button.is_inside_tree():
											narrative_container.move_child(_skip_button, -1)
											print("[ShowNarrativeStep] Fallback: raised skip button to front")
									else:
										print("[ShowNarrativeStep] Fallback: renderer.display_asset failed for: ", fallback_asset)
								else:
									print("[ShowNarrativeStep] Fallback: renderer missing display_asset method")
							else:
								print("[ShowNarrativeStep] Fallback: no asset available to attempt fallback render")

	# Success! Narrative is now showing
	# IMPORTANT: Keep waiting_for_completion = true so pipeline waits for the narrative to finish
	# The narrative will complete via EventBus signal or safety/watchdog timers
	_context.waiting_for_completion = true
	return true

func _start_auto_advance_timer():
	if auto_advance_delay <= 0:
		return

	print("[ShowNarrativeStep] Starting auto-advance timer (delay: %.1fs)" % auto_advance_delay)
	if _auto_timer:
		_auto_timer.stop()
	_auto_timer = Timer.new()
	_auto_timer.wait_time = auto_advance_delay
	_auto_timer.one_shot = true
	_auto_timer.connect("timeout", Callable(self, "_on_auto_advance_timeout"))
	add_child(_auto_timer)
	_auto_timer.start()

func _on_auto_advance_timeout():
	print("[ShowNarrativeStep] Auto-advance timer expired")
	_finish_narrative_stage()

func _finish_narrative_stage():
	if _finished:
		return
	_finished = true

	print("[ShowNarrativeStep] Finishing narrative stage: %s" % stage_id)

	# Stop watchdog timer if it's still running
	if _overlay_watchdog and is_instance_valid(_overlay_watchdog):
		_overlay_watchdog.stop()
		_overlay_watchdog = null
		print("[ShowNarrativeStep] Stopped overlay watchdog timer")

	# Stop safety timer if it's still running
	if _safety_timer and is_instance_valid(_safety_timer):
		_safety_timer.stop()
		_safety_timer = null
		print("[ShowNarrativeStep] Stopped safety timer")

	# Stop auto-advance timer if it's still running
	if _auto_timer and is_instance_valid(_auto_timer):
		_auto_timer.stop()
		_auto_timer = null
		print("[ShowNarrativeStep] Stopped auto-advance timer")

	var root = get_tree().root
	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if narrative_manager and narrative_manager.has_method("unlock_stage"):
		narrative_manager.unlock_stage()
		print("[ShowNarrativeStep] Unlocked NarrativeStageManager")

	# Cleanup context visibility
	if _context:
		# Don't restore board visibility - the LoadLevelStep will handle showing the board
		# when it loads the new level. Restoring the old visibility state would interfere.
		# var board = _context.game_board
		# if board:
		# 	board.visible = _board_prev_visible

		var game_ui = _context.game_ui
		if game_ui:
			# Restore HUD
			var hud = game_ui.get_node_or_null("VBoxContainer/TopPanel/HUD")
			if hud:
				hud.visible = _hud_prev_visible

			# Restore BoosterPanel
			var booster_panel = game_ui.get_node_or_null("BoosterPanel")
			if booster_panel:
				booster_panel.visible = _booster_panel_prev_visible

			# Restore FloatingMenu
			var floating_menu = game_ui.get_node_or_null("FloatingMenu")
			if floating_menu:
				floating_menu.visible = _floating_menu_prev_visible

	# Remove narrative overlay and its children
	if _overlay_layer and _overlay_layer.is_inside_tree():
		_overlay_layer.queue_free()
		print("[ShowNarrativeStep] Removed narrative overlay")
	else:
		print("[ShowNarrativeStep] Narrative overlay not found or already removed")

	# Disconnect from event bus if connected
	var event_bus = null
	var tree = get_tree()
	if tree:
		var root2 = tree.root
		event_bus = root2.get_node_or_null("/root/EventBus")
	if event_bus and event_bus.has_signal("narrative_stage_complete"):
		if event_bus.narrative_stage_complete.is_connected(Callable(self, "_on_narrative_complete")):
			event_bus.narrative_stage_complete.disconnect(Callable(self, "_on_narrative_complete"))
			print("[ShowNarrativeStep] Disconnected from EventBus.narrative_stage_complete")

	print("[ShowNarrativeStep] Finished")

	# CRITICAL: Emit step_completed signal to tell pipeline this step is done
	step_completed.emit(true)

func _on_skip_pressed() -> void:
	print("[ShowNarrativeStep] Skip pressed by user at ms=", Time.get_ticks_msec())
	# Skip should immediately finish the narrative stage, bypassing any timers or transitions
	print("[ShowNarrativeStep] Forcibly finishing narrative stage due to skip")

	# CRITICAL: Stop the controller's timers before finishing to prevent ghost state transitions
	var root = get_tree().root
	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if narrative_manager:
		var controller = narrative_manager.get_node_or_null("NarrativeStageController")
		if controller:
			# Stop auto-advance timer
			if controller.has_method("stop_all_timers"):
				controller.stop_all_timers()
				print("[ShowNarrativeStep] Stopped controller timers via stop_all_timers()")
			# Clear stage to stop any ongoing transitions
			if narrative_manager.has_method("clear_stage"):
				narrative_manager.clear_stage(true)  # Force clear
				print("[ShowNarrativeStep] Force-cleared narrative stage to stop transitions")

	_finish_narrative_stage()

func _start_safety_timer(duration: float) -> void:
	if _safety_timer:
		_safety_timer.stop()
	_safety_timer = Timer.new()
	_safety_timer.wait_time = duration
	_safety_timer.one_shot = true
	_safety_timer.connect("timeout", Callable(self, "_on_safety_timeout"))
	add_child(_safety_timer)
	_safety_timer.start()
	print("[ShowNarrativeStep] Safety timer started for ", duration, "s")

func _on_safety_timeout() -> void:
	print("[ShowNarrativeStep] Safety timer expired; forcing finish of narrative: ", stage_id)
	_finish_narrative_stage()

func _on_overlay_watchdog() -> void:
	print("[ShowNarrativeStep] Overlay watchdog triggered; verifying visuals before cleanup")
	# Don't do anything if we've already finished
	if _finished:
		print("[ShowNarrativeStep] Already finished - ignoring watchdog")
		return
	if not _overlay_layer or not _overlay_layer.is_inside_tree():
		print("[ShowNarrativeStep] No overlay layer present - nothing to do")
		return
	var nc = _overlay_layer.get_node_or_null("NarrativeContainer")
	if not nc:
		print("[ShowNarrativeStep] NarrativeContainer missing - finishing to be safe")
		_finish_narrative_stage()
		return
	# Determine if any meaningful visual was added (exclude dimmer and skip button)
	var meaningful = false
	for c in nc.get_children():
		if not (c.name == "NarrativeDimmer" or c.name == "SkipButton" or c is Timer):
			# Treat TextureRect, Label, Control, or custom nodes as meaningful visuals
			meaningful = true
			break
	if meaningful:
		print("[ShowNarrativeStep] Visuals found in NarrativeContainer - keeping overlay")
		return
	# No meaningful visuals - finish the narrative step to restore UI/board
	print("[ShowNarrativeStep] No visuals created after watchdog - finishing narrative step to restore UI/board")
	_finish_narrative_stage()

func _on_narrative_complete(stage_id: String) -> void:
	"""Callback when narrative stage completes via EventBus signal"""
	print("[ShowNarrativeStep] Received narrative_stage_complete for: ", stage_id)
	# Only finish if this matches our stage_id
	if stage_id == self.stage_id:
		print("[ShowNarrativeStep] Stage ID matches - finishing narrative")
		_finish_narrative_stage()
	else:
		print("[ShowNarrativeStep] Stage ID mismatch (expected: ", self.stage_id, ", got: ", stage_id, ") - ignoring")
