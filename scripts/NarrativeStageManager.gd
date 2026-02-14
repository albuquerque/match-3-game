extends Node

## NarrativeStageManager
## Manages narrative stage lifecycle and integration with game systems
## This is the main entry point for the narrative stage system

var controller: Node = null
var renderer: Node = null
var active_stage_id: String = ""

# Preloaded scenes
var controller_scene: Script = null
var renderer_scene: Script = null

var _locked: bool = false
var _watchdog_timer: SceneTreeTimer = null
var _watchdog_duration: float = 15.0

signal stage_shown(stage_id: String, fullscreen: bool)
signal stage_cleared()

func _ready():
	print("[NarrativeStageManager] Ready")
	_initialize_components()

func _initialize_components():
	"""Initialize controller and renderer"""
	# Attempt to load controller/renderer scripts at runtime to avoid preload-time failures
	if controller_scene == null:
		var cs = load("res://scripts/NarrativeStageController.gd")
		if cs and cs is Script:
			controller_scene = cs
		else:
			print("[NarrativeStageManager] WARNING: Could not load NarrativeStageController.gd at runtime; controller will be a plain Node")

	# Create controller node
	controller = Node.new()
	controller.name = "NarrativeStageController"
	if controller_scene != null:
		# Attach the controller script if available
		controller.set_script(controller_scene)
	else:
		print("[NarrativeStageManager] Controller script unavailable; some narrative features will be disabled until script loads correctly")
	add_child(controller)

	# Attempt to load renderer script if not already loaded
	if renderer_scene == null:
		var rs = load("res://scripts/NarrativeStageRenderer.gd")
		if rs and rs is Script:
			renderer_scene = rs
		else:
			print("[NarrativeStageManager] WARNING: Could not load NarrativeStageRenderer.gd at runtime; renderer will be a plain Control")

	# Create renderer (as Control node for UI)
	renderer = Control.new()
	renderer.name = "NarrativeStageRenderer"
	if renderer_scene != null:
		renderer.set_script(renderer_scene)
	else:
		print("[NarrativeStageManager] Renderer script unavailable; narrative visuals will be disabled until script loads correctly")
	add_child(renderer)

	# Link controller to renderer
	controller.set_renderer(renderer)

	print("[NarrativeStageManager] Components initialized")

func _stage_is_fullscreen(stage_data: Dictionary) -> bool:
	if not stage_data or not stage_data.has("states"):
		return false
	for s in stage_data["states"]:
		if typeof(s) == TYPE_DICTIONARY:
			var pos = s.get("position", "")
			if pos == "fullscreen":
				return true
	# fallback: if any state explicitly requests fullscreen via anchor or other hints
	return false

func load_stage_for_level(level_num: int) -> bool:
	"""Load narrative stage for a specific level if available"""
	print("[NarrativeStageManager] load_stage_for_level called with level=", level_num, " active_stage_id=", active_stage_id, " _locked=", _locked)
	# If a stage is already active (for example the Experience pipeline explicitly loaded a stage),
	# do NOT auto-load the per-level stage. This preserves explicit flow control and avoids
	# the situation where a flow's requested stage is immediately replaced by a level-specific stage.
	if active_stage_id != "":
		print("[NarrativeStageManager] Active stage present (", active_stage_id, ") - skipping auto-load")
		return false

	# Clear any existing stage
	clear_stage()

	# Try to find stage JSON for this level
	# New layout: store per-level narrative stages under data/narrative_stages/levels/
	var stage_path = "res://data/narrative_stages/levels/level_%d.json" % level_num

	print("[NarrativeStageManager] Looking for stage file at: ", stage_path)
	if FileAccess.file_exists(stage_path):
		print("[NarrativeStageManager] Loading stage for level ", level_num)
		if controller.load_stage_from_file(stage_path):
			active_stage_id = "level_%d" % level_num

			# Preload assets for performance
			var stage_data = controller.current_stage_data
			if stage_data and renderer:
				renderer.preload_assets(stage_data)
				# Also set renderer anchor explicitly in manager to avoid ordering races
				var stage_anchor = stage_data.get("anchor", "")
				if stage_anchor != "" and renderer.has_method("set_visual_anchor"):
					renderer.set_visual_anchor(stage_anchor)
					print("[NarrativeStageManager] Explicitly set renderer anchor: ", stage_anchor)

			# Emit signal for listeners (GameUI) indicating a stage was shown
			var is_full = _stage_is_fullscreen(stage_data)
			emit_signal("stage_shown", active_stage_id, is_full)

			return true

	# Try DLC stages
	if _try_load_dlc_stage(level_num):
		return true

	print("[NarrativeStageManager] No narrative stage for level ", level_num)
	return false

func load_stage_by_id(stage_id: String) -> bool:
	"""Load a specific narrative stage by ID"""
	print("[NarrativeStageManager] load_stage_by_id called: ", stage_id)
	print("[NarrativeStageManager] current active_stage_id=", active_stage_id, " _locked=", _locked)
	clear_stage()

	var stage_path = "res://data/narrative_stages/%s.json" % stage_id
	print("[NarrativeStageManager] Resolved stage_path=", stage_path)

	if FileAccess.file_exists(stage_path):
		print("[NarrativeStageManager] Loading stage: ", stage_id)
		if controller.load_stage_from_file(stage_path):
			active_stage_id = stage_id

			# Preload assets
			var stage_data = controller.current_stage_data
			if stage_data and renderer:
				renderer.preload_assets(stage_data)
				# Ensure renderer anchor is set to stage's anchor as well (safety)
				var anchor_val = stage_data.get("anchor", "")
				if anchor_val != "" and renderer.has_method("set_visual_anchor"):
					renderer.set_visual_anchor(anchor_val)
					print("[NarrativeStageManager] Set renderer anchor for id load: ", anchor_val)

			# Emit signal for listeners
			var is_full = _stage_is_fullscreen(stage_data)
			emit_signal("stage_shown", active_stage_id, is_full)

			return true

	print("[NarrativeStageManager] Stage not found: ", stage_id)
	return false

func load_dlc_stage(chapter_id: String, stage_name: String) -> bool:
	"""Load narrative stage from DLC chapter"""
	clear_stage()

	if controller.load_stage_from_dlc(chapter_id, stage_name):
		active_stage_id = "%s:%s" % [chapter_id, stage_name]

		# Preload assets
		var stage_data = controller.current_stage_data
		if stage_data and renderer:
			renderer.preload_assets(stage_data)
			# Set renderer anchor explicitly for DLC stages as well
			var anchor_val2 = stage_data.get("anchor", "")
			if anchor_val2 != "" and renderer.has_method("set_visual_anchor"):
				renderer.set_visual_anchor(anchor_val2)
				print("[NarrativeStageManager] Set renderer anchor for DLC stage: ", anchor_val2)

		# Emit signal for listeners
		var is_full2 = _stage_is_fullscreen(stage_data)
		emit_signal("stage_shown", active_stage_id, is_full2)

		return true

	return false

func clear_stage(force: bool=false):
	"""Clear current narrative stage"""
	print("[NarrativeStageManager] clear_stage called (force=", force, ") _locked=", _locked)
	if _locked and not force:
		print("[NarrativeStageManager] clear_stage aborted because manager is locked")
		return
	if controller:
		controller.clear_stage()

	# Clear renderer visuals and any render container override
	if renderer:
		if renderer.has_method("clear"):
			renderer.clear()
		if renderer.has_method("clear_render_container"):
			renderer.clear_render_container()

	active_stage_id = ""
	print("[NarrativeStageManager] Stage cleared (active_stage_id reset)")
	# Emit cleared signal so UI can reactivate gameplay elements
	emit_signal("stage_cleared")

func set_anchor(anchor_name: String):
	"""Set which visual anchor the renderer should use"""
	if renderer:
		renderer.set_visual_anchor(anchor_name)

func is_stage_active() -> bool:
	"""Check if a narrative stage is currently active"""
	return active_stage_id != ""

func _try_load_dlc_stage(level_num: int) -> bool:
	"""Try to load narrative stage from DLC for this level"""
	# Get current chapter for this level
	var level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager:
		return false

	# Check if level is in a DLC chapter
	# (This would need to be implemented based on your level-to-chapter mapping)

	return false

func lock_stage(val: bool=true):
	"""Lock or unlock the manager to prevent auto-reloads/clears."""
	_locked = val
	print("[NarrativeStageManager] lock_stage called set to: ", _locked)
	# Manage watchdog: if locked, schedule a forced clear/unlock after _watchdog_duration
	var tree = get_tree()
	if _locked and tree:
		# cancel any existing watchdog
		if _watchdog_timer:
			_watchdog_timer = null
		_watchdog_timer = tree.create_timer(_watchdog_duration)
		_watchdog_timer.timeout.connect(Callable(self, "_on_watchdog_timeout"))
		print("[NarrativeStageManager] Watchdog scheduled for ", _watchdog_duration, "s")
	elif not _locked:
		# cancel watchdog if unlocking
		if _watchdog_timer:
			_watchdog_timer = null
			print("[NarrativeStageManager] Watchdog cancelled due to unlock")

func trigger_event(event_name: String, context: Dictionary = {}):
	"""Public: trigger an event against the current stage/controller.
	Used by external systems (e.g., pipeline ShowNarrativeStep) to request transitions like 'auto_advance'."""
	print("[NarrativeStageManager] trigger_event called: ", event_name, " controller=", controller != null)
	if controller and controller.has_method("_check_transitions"):
		controller._check_transitions(event_name, context)
		print("[NarrativeStageManager] Triggered event for controller: ", event_name)
		return true
	print("[NarrativeStageManager] Cannot trigger event; controller missing or method not available: ", event_name)
	return false
