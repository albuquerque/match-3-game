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
var _controller_conn: Object = null
var _finished: bool = false
var _exec_start_time: int = 0
var _pending_state_timers: Dictionary = {}
var _state_timer_seq: int = 0

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
		if _context:
			_context.overlay_layer = _overlay_layer
	print("[ShowNarrativeStep] Overlay created: %s" % (_overlay_layer.get_path() if _overlay_layer else "none"))
	print("[ShowNarrativeStep][ts] overlay created ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)

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
		# Ensure dimmer sits behind narrative content
		_dimmer_poly.z_index = 0
		# Add to overlay layer (CanvasLayer expects Node2D children)
		_overlay_layer.add_child(_dimmer_poly)

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
	_overlay_layer.add_child(narrative_container)
	print("[ShowNarrativeStep] Narrative container added: %s" % (narrative_container.get_path()))

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
		# Lock NarrativeStageManager to prevent level-based auto-loads from replacing this pipeline-driven stage
		if narrative_manager.has_method("lock_stage"):
			narrative_manager.lock_stage(true)
			print("[ShowNarrativeStep] Locked NarrativeStageManager for stage: %s" % stage_id)
		var loaded = narrative_manager.load_stage_by_id(stage_id)
		print("[ShowNarrativeStep] narrative_manager.load_stage_by_id returned: %s" % str(loaded))
		print("[ShowNarrativeStep][ts] load_stage_by_id return ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
		if loaded:
			# Success: compute conservative safety timeout based on stage definition (so we don't cut off later states)
			var computed_safety: float = 0.0
			var stage_path = "res://data/narrative_stages/%s.json" % stage_id
			if FileAccess.file_exists(stage_path):
				var f = FileAccess.open(stage_path, FileAccess.READ)
				if f:
					var txt = f.get_as_text()
					f.close()
					# try parse JSON and sum durations
					var j = JSON.parse_string(txt)
					if typeof(j) == TYPE_DICTIONARY:
						var parse_err = j.get("error", null)
						var parse_res = j.get("result", null)
						if parse_err == OK and parse_res and typeof(parse_res) == TYPE_DICTIONARY:
							var sd = parse_res
							if sd.has("states"):
								for st in sd["states"]:
									computed_safety += float(st.get("duration", 0.0))
								# add a small slack so minor jitter won't cut off
								computed_safety += 1.0
								print("[ShowNarrativeStep] Computed safety timeout from stage JSON: ", computed_safety)
							else:
								print("[ShowNarrativeStep] Stage JSON has no 'states' array: ", stage_path)
						else:
							var msg = j.get("error_message", "(no message)")
							print("[ShowNarrativeStep] Failed to parse stage JSON for safety computation: ", stage_path, " parse_err=", parse_err, " msg=", msg)
					else:
						print("[ShowNarrativeStep] Unexpected JSON.parse_string result type for: ", stage_path)
				else:
					print("[ShowNarrativeStep] Could not open stage file for safety computation: ", stage_path)
			else:
				print("[ShowNarrativeStep] Stage file not found for safety computation: ", stage_path)

			# Start safety timer using computed value if available; otherwise fallback to default
			if computed_safety > 0.0:
				_start_safety_timer(computed_safety)
			else:
				_start_safety_timer()

			# Connect to the manager's controller state_changed so we can observe transitions
			if narrative_manager and narrative_manager.controller != null:
				var ctrl = narrative_manager.controller
				if ctrl and ctrl.has_signal("state_changed") and not ctrl.state_changed.is_connected(Callable(self, "_on_controller_state_changed")):
					ctrl.state_changed.connect(Callable(self, "_on_controller_state_changed"))
					_controller_conn = ctrl
					# Immediately inspect current state to schedule duration if controller already set it (avoid race)
					if ctrl.current_state != "":
						var cur = ctrl.current_state
						print("[ShowNarrativeStep] Controller current_state at connect: ", cur, " ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
						if cur != "":
							_on_controller_state_changed(cur)
					# If controller has stage data, ensure safety timer isn't shorter than controller-internal estimate
					if ctrl.current_stage_data and ctrl.current_stage_data.has("states"):
						var total_ctrl: float = 0.0
						for s in ctrl.current_stage_data["states"]:
							total_ctrl += float(s.get("duration", 0.0))
						# add slack
						total_ctrl += 1.0
						# if controller estimate is longer than file-based safety, replace timer
						if total_ctrl > computed_safety:
							_start_safety_timer(total_ctrl)
			# Also rely on EventBus.narrative_stage_complete (connected earlier)
			return true

		# Unlock manager on failure
		if narrative_manager.has_method("lock_stage"):
			narrative_manager.lock_stage(false)
			print("[ShowNarrativeStep] Unlocked NarrativeStageManager after failed load: %s" % stage_id)
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
		print("[ShowNarrativeStep] Auto-advance timer started for %.2fs ms=" % auto_advance_delay, Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
		# use Callable to connect the timeout signal
		_auto_timer.timeout.connect(Callable(self, "_on_auto_advance_timeout"))

func _start_safety_timer(override_seconds: float = 0.0):
	var tree: SceneTree = get_tree()
	if not tree:
		return
	var safety: float = 0.0
	if override_seconds > 0.0:
		safety = override_seconds
	else:
		# default conservative safety
		safety = max(3.0, auto_advance_delay + 1.0)
	# If we already have a safety timer, disconnect its signal to avoid duplicate callbacks
	if _safety_timer:
		# try to disconnect previous signal safely
		if _safety_timer.timeout and _safety_timer.timeout.is_connected(Callable(self, "_on_safety_timeout")):
			_safety_timer.timeout.disconnect(Callable(self, "_on_safety_timeout"))
	# create new timer
	_safety_timer = tree.create_timer(safety)
	_safety_timer.timeout.connect(Callable(self, "_on_safety_timeout"))
	print("[ShowNarrativeStep] Safety timer started for %.2fs" % safety)

func _on_auto_advance_timeout():
	print("[ShowNarrativeStep] Auto-advance timeout fired ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
	# Instead of finishing the pipeline immediately, try multiple ways to advance the narrative stage
	var tree = get_tree()
	if tree:
		var root = tree.root
		print("[ShowNarrativeStep] root: ", root, " ms=", Time.get_ticks_msec())
		var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
		print("[ShowNarrativeStep] narrative_manager: ", narrative_manager)
		if narrative_manager:
			print("[ShowNarrativeStep] narrative_manager has trigger_event: ", narrative_manager.has_method("trigger_event"))
			if narrative_manager.has_method("trigger_event"):
				narrative_manager.trigger_event("auto_advance", {})
				print("[ShowNarrativeStep] Requested NarrativeStageManager to auto_advance via trigger_event ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
				return
			# Fallback: try to access controller directly
			if narrative_manager.controller != null:
				var ctrl = narrative_manager.controller
				print("[ShowNarrativeStep] narrative_manager.controller: ", ctrl)
				if ctrl and ctrl.has_method("_check_transitions"):
					ctrl._check_transitions("auto_advance", {})
					print("[ShowNarrativeStep] Requested controller to auto_advance via _check_transitions ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
					return
			# If manager exists but we couldn't invoke it, wait a short grace period before finishing to avoid races
			print("[ShowNarrativeStep] Manager present but could not invoke transition; waiting grace period before finishing")
			var grace = 0.5
			var gtimer = tree.create_timer(grace)
			gtimer.timeout.connect(Callable(self, "_finish_and_emit"))
			return

	# Fallback: no manager/controller available -> finish step
	print("[ShowNarrativeStep] NarrativeStageManager/controller not available, finishing step ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
	_finish_and_emit()

func _on_safety_timeout():
	var now = Time.get_ticks_msec()
	print("[ShowNarrativeStep] Safety timeout fired at ms=", now, " checking pending_state_timers=", _pending_state_timers)
	# If there are pending state timers, compute remaining time and reschedule safety timer instead of forcing completion
	if _pending_state_timers.size() > 0:
		var min_remaining: float = -1.0
		for key in _pending_state_timers.keys():
			var entry = _pending_state_timers[key]
			if typeof(entry) == TYPE_DICTIONARY and entry.has("expiry"):
				var expiry = int(entry["expiry"])
				var remaining = float(expiry - now) / 1000.0
				if remaining > 0.0:
					if min_remaining < 0.0 or remaining < min_remaining:
						min_remaining = remaining
		# If we found a pending expiry in the future, reschedule safety timer to wait until then + small slack
		if min_remaining > 0.0:
			var wait = min_remaining + 0.25 # 250ms slack
			print("[ShowNarrativeStep] Deferring safety completion, rescheduling safety timer for ", wait, "s (min_remaining=", min_remaining, ")")
			_start_safety_timer(wait)
			return
	# No relevant pending timers -> force completion
	print("[ShowNarrativeStep] No pending state timers or all expired; forcing completion now")
	_finish_and_emit()

func _on_narrative_complete(stg_id: String):
	if _finished:
		return
	if stg_id == stage_id:
		print("[ShowNarrativeStep] Narrative completed: %s" % stg_id)
		_finish_and_emit()

func _on_controller_state_changed(new_state: String):
	print("[ShowNarrativeStep] Controller state changed: ", new_state, " ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
	# When controller advances to a new state, if that state has a duration, ensure we wait that duration before finishing
	var tree = get_tree()
	if not tree:
		return
	# get narrative manager and controller state data
	var root = tree.root
	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
	if not narrative_manager:
		return
	if narrative_manager.controller == null:
		return
	var ctrl = narrative_manager.controller
	if not ctrl:
		return
	# find state data in controller.current_stage_data (if available)
	if ctrl.current_stage_data:
		var sd = ctrl.current_stage_data
		if sd and sd.has("states"):
			for s in sd["states"]:
				if s.get("name", "") == new_state:
					var dur = s.get("duration", 0.0)
					print("[ShowNarrativeStep] Found state duration for ", new_state, ": ", dur, " ms=", Time.get_ticks_msec(), " delta=", Time.get_ticks_msec() - _exec_start_time)
					if dur > 0:
						if _finished:
							return
						# increment seq and schedule a timer bound to this seq
						_state_timer_seq += 1
						var seq = _state_timer_seq
						# clear previous pending timers (we only care about the most recent sequence)
						_pending_state_timers.clear()
						var expiry = Time.get_ticks_msec() + int(dur * 1000)
						_pending_state_timers[seq] = {"state": new_state, "expiry": expiry}
						var t = tree.create_timer(dur)
						# bind seq to the callback so we can validate which timer fired
						t.timeout.connect(Callable(self, "_on_controller_state_duration_complete").bind(seq))
						print("[ShowNarrativeStep] Scheduled controller state duration timer seq=", seq, " for ", new_state, " ms=", Time.get_ticks_msec(), " duration=", dur)
						return

func _on_controller_state_duration_complete(seq: int) -> void:
	if _finished:
		return
	var tree = get_tree()
	var root = tree.root if tree else null
	var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager") if root else null
	var ctrl = null
	if narrative_manager and narrative_manager.controller != null:
		ctrl = narrative_manager.controller
	var cur_state = ctrl.current_state if ctrl and ctrl.current_state != null else ""
	var now = Time.get_ticks_msec()
	var entry = _pending_state_timers.get(seq, null)
	print("[ShowNarrativeStep] State-duration timer fired; seq=", seq, ", now=", now, ", cur_state=", cur_state, ", entry=", entry)
	if entry == null:
		print("[ShowNarrativeStep] No pending entry for seq=", seq, " - ignoring")
		return
	var expected_state = entry.get("state", "")
	var expiry = entry.get("expiry", 0)
	# Only finish if the controller's current state matches and we've reached expiry
	if cur_state == expected_state and expiry != 0 and now >= expiry:
		_pending_state_timers.erase(seq)
		print("[ShowNarrativeStep] Controller state duration complete (seq=", seq, ", state=", cur_state, "), finishing step ms=", now, " delta=", now - _exec_start_time)
		_finish_and_emit()
	else:
		print("[ShowNarrativeStep] Ignoring timer seq=", seq, " because state mismatch or expiry not reached (expected=", expected_state, ", cur=", cur_state, ", expiry=", expiry, ")")
		return

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
	# Disconnect controller signal if connected
	if _controller_conn and _controller_conn.has_signal("state_changed"):
		if _controller_conn.state_changed.is_connected(Callable(self, "_on_controller_state_changed")):
			_controller_conn.state_changed.disconnect(Callable(self, "_on_controller_state_changed"))
		_controller_conn = null
	if _context:
		_context.waiting_for_completion = false
		_context.completion_type = ""
	# Unlock NarrativeStageManager now that the pipeline-driven stage is fully finished
	var tree = get_tree()
	if tree:
		var root = tree.root
		var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
		if narrative_manager and narrative_manager.has_method("lock_stage"):
			narrative_manager.lock_stage(false)
			print("[ShowNarrativeStep] Unlocked NarrativeStageManager after completion: %s" % stage_id)
			# Clear any active stage so level-specific stage (top_banner) can be loaded by level events
			if narrative_manager and narrative_manager.has_method("clear_stage"):
				narrative_manager.clear_stage()
				print("[ShowNarrativeStep] Cleared NarrativeStageManager active stage to allow level-specific stage to load")
				# Explicitly reset anchor to top_banner so renderer is prepared for per-level banner
				if narrative_manager and narrative_manager.has_method("set_anchor"):
					narrative_manager.set_anchor("top_banner")
					print("[ShowNarrativeStep] Reset NarrativeStageManager anchor to 'top_banner'")
	_finished = true
	step_completed.emit(true)

func cleanup():
	# Disconnect event and restore UI - but only if we're still in the tree
	if not is_inside_tree():
		# Step already removed from tree, cannot access EventBus via get_tree()
		# Just clear our references and attempt a safe fallback to Engine.get_main_loop()
		_auto_timer = null
		_safety_timer = null
		# Try to access the SceneTree safely via Engine.get_main_loop() when node not inside tree
		var main_loop = Engine.get_main_loop()
		var tree = null
		if main_loop and main_loop is SceneTree:
			tree = main_loop
		if tree:
			var root = tree.root
			var narrative_manager = root.get_node_or_null("/root/NarrativeStageManager")
			if narrative_manager and narrative_manager.has_method("lock_stage"):
				narrative_manager.lock_stage(false)
				print("[ShowNarrativeStep] Unlocked NarrativeStageManager in cleanup: %s" % stage_id)
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

	# Disconnect controller signal if connected
	if _controller_conn and _controller_conn.has_signal("state_changed"):
		if _controller_conn.state_changed.is_connected(Callable(self, "_on_controller_state_changed")):
			_controller_conn.state_changed.disconnect(Callable(self, "_on_controller_state_changed"))
		_controller_conn = null

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
	# Remove dimmer polygon if present
	if _dimmer_poly and _dimmer_poly.is_inside_tree():
		_dimmer_poly.queue_free()
		_dimmer_poly = null
		print("[ShowNarrativeStep] Removed dimmer polygon")

	# Remove overlay layer only if we created it or it still exists
	if _overlay_layer and _overlay_layer.is_inside_tree():
		_overlay_layer.queue_free()
		# Clear context.overlay_layer if it referenced this
		if context and context.overlay_layer == _overlay_layer:
			context.overlay_layer = null
		_overlay_layer = null
		print("[ShowNarrativeStep] Removed overlay layer")
