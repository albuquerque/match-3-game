extends Node

## NarrativeStageController
## Manages the narrative stage state machine and coordinates with renderer
## Load stage JSON, react to EventBus events, trigger state transitions

signal state_changed(new_state: String)
signal stage_loaded(stage_id: String)

var current_stage_data: Dictionary = {}
var current_state: String = ""
var renderer: Node = null

# State tracking
var _transitions: Array = []
var _states: Dictionary = {}
var _active: bool = false

# Progress milestone tracking (to prevent triggering all at once)
var _progress_milestones_reached: Dictionary = {
	"progress_25": false,
	"progress_50": false,
	"progress_75": false,
	"goal_complete": false
}

var _auto_timer: SceneTreeTimer = null
var _completion_timer: SceneTreeTimer = null

func _ready():
	print("[NarrativeStageController] Ready")

	# Connect to EventBus for game events
	if EventBus:
		EventBus.level_loaded.connect(_on_level_loaded)
		EventBus.level_complete.connect(_on_level_complete)
		EventBus.match_cleared.connect(_on_match_cleared)
		print("[NarrativeStageController] Connected to EventBus")

func load_stage(stage_data: Dictionary) -> bool:
	"""Load a narrative stage from JSON data"""
	if not stage_data.has("id"):
		print("[NarrativeStageController] ERROR: Stage data missing 'id'")
		return false

	print("[NarrativeStageController] Loading stage: ", stage_data.get("id"))
	print("[NarrativeStageController][ts] load start ms=", Time.get_ticks_msec())
	current_stage_data = stage_data

	# If renderer is set and stage specifies an anchor, apply it so visuals render in the correct area
	if renderer and renderer.has_method("set_visual_anchor"):
		var anchor_val = stage_data.get("anchor", "")
		if anchor_val != "":
			renderer.set_visual_anchor(anchor_val)
			print("[NarrativeStageController] Applied stage anchor to renderer: ", anchor_val)

	# Reset milestone tracking
	_progress_milestones_reached = {
		"progress_25": false,
		"progress_50": false,
		"progress_75": false,
		"goal_complete": false
	}
	print("[NarrativeStageController] Reset progress milestones")

	# Parse states
	_states.clear()
	if stage_data.has("states"):
		for state in stage_data["states"]:
			if state.has("name"):
				_states[state["name"]] = state
				print("[NarrativeStageController]   State: ", state["name"])

	# Parse transitions
	_transitions.clear()
	if stage_data.has("transitions"):
		_transitions = stage_data["transitions"]
		print("[NarrativeStageController]   Transitions: ", _transitions.size())

	# Set initial state. Do this regardless of whether transitions exist so stages without transitions still render.
	# Check for stage_loaded or level_start transitions, otherwise fall back to first declared state.
	var initial_set: bool = false
	if _transitions.size() > 0:
		# First check for level_start transitions (legacy)
		for trans in _transitions:
			if trans.get("event") == "level_start":
				_set_state(trans.get("to", ""))
				initial_set = true
				break

		# If no level_start, check for stage_loaded transitions
		if not initial_set:
			for trans in _transitions:
				if trans.get("event") == "stage_loaded":
					# Found stage_loaded transition - will be triggered after activation
					initial_set = true
					break

	# If we didn't find any matching transitions, fall back to the first declared state
	if not initial_set and _states.size() > 0:
		var first_state_name = _states.keys()[0]
		_set_state(first_state_name)

	_active = true
	emit_signal("stage_loaded", stage_data.get("id"))
	print("[NarrativeStageController][ts] load complete ms=", Time.get_ticks_msec())

	# CRITICAL: After activation, check for stage_loaded transitions to trigger initial state
	# This allows stages to define their initial state via transition event
	_check_transitions("stage_loaded", {})

	return true
	return true

func load_stage_from_file(path: String) -> bool:
	"""Load stage from JSON file"""
	if not FileAccess.file_exists(path):
		print("[NarrativeStageController] File not found: ", path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("[NarrativeStageController] Failed to open: ", path)
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		print("[NarrativeStageController] JSON parse error in ", path)
		return false

	return load_stage(json.data)

func load_stage_from_dlc(chapter_id: String, stage_name: String) -> bool:
	"""Load stage from DLC chapter"""
	# Try to load from DLC via AssetRegistry or DLCManager
	var dlc_manager = get_node_or_null("/root/DLCManager")
	if not dlc_manager:
		print("[NarrativeStageController] DLCManager not available")
		return false

	# Construct path to stage JSON in DLC chapter
	var stage_path = "user://dlc/chapters/%s/stages/%s.json" % [chapter_id, stage_name]
	return load_stage_from_file(stage_path)

func clear_stage():
	"""Clear current stage and reset state"""
	print("[NarrativeStageController] Clearing stage")
	current_stage_data.clear()
	_states.clear()
	_transitions.clear()
	current_state = ""
	_active = false

	# Cancel timers
	_auto_timer = null
	_completion_timer = null

	# Notify renderer to clear visuals
	if renderer and renderer.has_method("clear"):
		renderer.clear()

func set_renderer(renderer_node: Node):
	"""Set the renderer that will handle visual output"""
	renderer = renderer_node
	print("[NarrativeStageController] Renderer set: ", renderer.name if renderer else "null")

func _set_state(state_name: String):
	"""Internal: Set current state and notify renderer"""
	if not _states.has(state_name):
		print("[NarrativeStageController] WARNING: Unknown state: ", state_name)
		return

	print("[NarrativeStageController] State: ", current_state, " -> ", state_name)
	print("[NarrativeStageController][ts] _set_state called ms=", Time.get_ticks_msec())
	current_state = state_name

	# Get state data
	var state_data = _states[state_name]

	# Ensure the renderer knows about the stage-level anchor/position.
	# We prefer an explicit state 'position' if present, otherwise fall back to the stage's top-level 'anchor'.
	var render_state_data = {}
	for k in state_data.keys():
		render_state_data[k] = state_data[k]
	# If state doesn't include 'position', copy from current_stage_data.anchor
	if not render_state_data.has("position"):
		var stage_anchor = current_stage_data.get("anchor", "")
		if stage_anchor != "":
			render_state_data["position"] = stage_anchor
			print("[NarrativeStageController] Injected stage anchor into state position: ", stage_anchor)

	# Notify renderer
	if renderer and renderer.has_method("render_state"):
		print("[NarrativeStageController] About to call renderer.render_state. renderer=", renderer.name, ", has_method(render_state)=", renderer.has_method("render_state"))
		print("[NarrativeStageController] render_state_data keys: ", render_state_data.keys())
		print("[NarrativeStageController] render_state_data asset: ", render_state_data.get("asset", "(none)"), " position: ", render_state_data.get("position", "(none)"))
		renderer.render_state(render_state_data)
	else:
		print("[NarrativeStageController] Renderer not available or missing render_state method. renderer=", renderer)

	emit_signal("state_changed", state_name)

	# Cancel any existing auto timer
	if _auto_timer:
		_auto_timer = null

	# Schedule auto_advance if defined in transitions for this state
	for trans in _transitions:
		print("[NarrativeStageController] Inspect trans: from=", trans.get("from", ""), ", event=", trans.get("event", ""), ", to=", trans.get("to", ""), ", delay=", trans.get("delay", 0.0))
		if trans.get("from", "") == state_name and trans.get("event", "") == "auto_advance":
			var delay = trans.get("delay", 0.0)
			print("[NarrativeStageController] Matched auto_advance transition for state ", state_name, ", delay=", delay)
			if delay > 0:
				print("[NarrativeStageController] Scheduling auto_advance in ", delay, "s for state: ", state_name)
				var tree = get_tree()
				if tree:
					_auto_timer = tree.create_timer(delay)
					print("[NarrativeStageController][ts] auto_advance scheduled ms=", Time.get_ticks_msec(), " will fire after=", delay)
					_auto_timer.timeout.connect(Callable(self, "_on_auto_advance_timeout"))
				return

	# If there are no outbound transitions from this state, consider stage complete
	var has_outbound = false
	for t in _transitions:
		if t.get("from", "") == state_name:
			has_outbound = true
			break
	if not has_outbound:
		print("[NarrativeStageController] No outbound transitions from state: ", state_name, " — marking stage complete")
		# If state specifies a duration, wait before emitting complete so the state is visible
		var duration = state_data.get("duration", 0.0)
		if duration > 0:
			print("[NarrativeStageController] Scheduling stage completion in ", duration, "s for terminal state: ", state_name)
			var tree = get_tree()
			if tree:
				_completion_timer = tree.create_timer(duration)
				print("[NarrativeStageController][ts] completion scheduled ms=", Time.get_ticks_msec(), " duration=", duration)
				_completion_timer.timeout.connect(Callable(self, "_on_completion_timeout"))
			return
		# Emit EventBus signal immediately if no duration
		var eb = get_node_or_null("/root/EventBus")
		if eb and eb.has_signal("narrative_stage_complete"):
			eb.emit_signal("narrative_stage_complete", current_stage_data.get("id", ""))

func _check_transitions(event_name: String, context: Dictionary = {}):
	"""Check if any transitions match the event and trigger state change"""
	if not _active:
		return

	print("[NarrativeStageController] Checking transitions for event: ", event_name)

	for trans in _transitions:
		if trans.get("event") == event_name:
			# Check optional conditions
			if trans.has("condition"):
				if not _check_condition(trans["condition"], context):
					continue

			# Trigger transition
			var target_state = trans.get("to")
			if target_state:
				_set_state(target_state)
				return  # Stop after first matching transition!
				return

func _check_condition(condition: Dictionary, context: Dictionary) -> bool:
	"""Check if condition matches context"""
	# Check score threshold
	if condition.has("min_score"):
		var score = context.get("score", GameManager.score if GameManager else 0)
		if score < condition["min_score"]:
			return false

	# Check match count
	if condition.has("match_count"):
		var matches = context.get("match_count", 0)
		if matches < condition["match_count"]:
			return false

	# Check combo
	if condition.has("combo"):
		var combo = context.get("combo", 0)
		if combo < condition["combo"]:
			return false

	return true

# EventBus handlers

func _on_level_loaded(level_id: String, context: Dictionary):
	"""Handle level loaded event"""
	print("[NarrativeStageController] Level loaded: ", level_id)
	_check_transitions("level_start", context)

func _on_level_complete(level_id: String, context: Dictionary):
	"""Handle level complete event"""
	print("[NarrativeStageController] Level complete: ", level_id)
	_check_transitions("level_complete", context)

	# Only trigger goal_complete if not already triggered by 100% progress
	if not _progress_milestones_reached["goal_complete"]:
		print("[NarrativeStageController] Triggering goal_complete milestone (level complete)")
		_progress_milestones_reached["goal_complete"] = true
		_check_transitions("goal_complete", context)

func _on_match_cleared(match_size: int, context: Dictionary):
	"""Handle match cleared event"""
	# Check for progress-based transitions
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var progress = 0

		# Calculate progress based on level type
		if game_manager.collectible_target > 0:
			# Collectible level
			progress = float(game_manager.collectibles_collected) / float(game_manager.collectible_target)
		elif game_manager.unmovable_target > 0:
			# Unmovable level
			progress = float(game_manager.unmovables_cleared) / float(game_manager.unmovable_target)
		else:
			# Score level
			progress = float(game_manager.score) / float(game_manager.target_score)

		# Check for progress milestones
		var progress_percent = int(progress * 100)

		print("[NarrativeStageController] Progress: ", progress_percent, "% (", game_manager.score, "/", game_manager.target_score, ")")

		# Check for specific progress events (only trigger each once)
		if progress_percent >= 25 and not _progress_milestones_reached["progress_25"]:
			print("[NarrativeStageController] Triggering progress_25 milestone")
			_progress_milestones_reached["progress_25"] = true
			_check_transitions("progress_25", context)
		elif progress_percent >= 50 and not _progress_milestones_reached["progress_50"]:
			print("[NarrativeStageController] Triggering progress_50 milestone")
			_progress_milestones_reached["progress_50"] = true
			_check_transitions("progress_50", context)
		elif progress_percent >= 75 and not _progress_milestones_reached["progress_75"]:
			print("[NarrativeStageController] Triggering progress_75 milestone")
			_progress_milestones_reached["progress_75"] = true
			_check_transitions("progress_75", context)
		elif progress_percent >= 100 and not _progress_milestones_reached["goal_complete"]:
			print("[NarrativeStageController] Triggering goal_complete milestone (100% progress)")
			_progress_milestones_reached["goal_complete"] = true
			_check_transitions("goal_complete", context)

func _on_auto_advance_timeout():
	print("[NarrativeStageController] Auto-advance timer fired for state: ", current_state)
	print("[NarrativeStageController][ts] auto_advance fired ms=", Time.get_ticks_msec())

	# Guard: Don't execute if controller was deactivated (e.g., by skip)
	if not _active:
		print("[NarrativeStageController] Controller inactive - ignoring auto-advance")
		return

	# Clear timer reference
	_auto_timer = null
	_check_transitions("auto_advance", {})

func _on_completion_timeout():
	print("[NarrativeStageController] Completion timer fired for stage: ", current_stage_data.get("id", ""))
	print("[NarrativeStageController][ts] completion fired ms=", Time.get_ticks_msec())

	# Guard: Don't execute if controller was deactivated (e.g., by skip)
	if not _active:
		print("[NarrativeStageController] Controller inactive - ignoring completion")
		return

	_completion_timer = null
	var eb = get_node_or_null("/root/EventBus")
	if eb and eb.has_signal("narrative_stage_complete"):
		eb.emit_signal("narrative_stage_complete", current_stage_data.get("id", ""))

func stop_all_timers():
	"""Stop all active timers (auto-advance and completion)"""
	if _auto_timer and is_instance_valid(_auto_timer):
		# SceneTreeTimer doesn't have a stop method, but we can disconnect the timeout signal
		# Actually, we can't easily stop a SceneTreeTimer, so just clear the reference
		_auto_timer = null
		print("[NarrativeStageController] Cleared auto-advance timer reference")

	if _completion_timer and is_instance_valid(_completion_timer):
		_completion_timer = null
		print("[NarrativeStageController] Cleared completion timer reference")

	# Reset state to prevent any further transitions
	_active = false
	print("[NarrativeStageController] Deactivated controller (timers stopped)")

