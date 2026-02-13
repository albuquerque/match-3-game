extends PipelineStep
class_name CutsceneStep

# CutsceneStep
# Plays a cutscene (scene path) and waits for completion.

var scene_path: String = ""
var _cutscene_node: Node = null
var _connected_signal: String = ""
var _timeout_timer: Timer = null
var _context: PipelineContext = null

func _init(path: String = ""):
	super("cutscene")
	scene_path = path

func execute(context: PipelineContext) -> bool:
	# Store context for callbacks
	_context = context

	# Validate
	if scene_path == "":
		push_error("[CutsceneStep] No scene_path provided")
		return false

	# Try to load the cutscene scene
	var packed = ResourceLoader.load(scene_path)
	if not packed or not (packed is PackedScene):
		push_error("[CutsceneStep] Failed to load cutscene scene: %s" % scene_path)
		return false

	# Instantiate and add to overlay or root
	_cutscene_node = packed.instantiate()
	if not _cutscene_node:
		push_error("[CutsceneStep] Failed to instantiate cutscene scene: %s" % scene_path)
		return false

	var parent: Node = null
	if _context and _context.overlay_layer:
		parent = _context.overlay_layer
	elif _context and _context.game_ui:
		parent = _context.game_ui
	else:
		parent = get_tree().get_root()

	parent.add_child(_cutscene_node)

	# Mark pipeline as waiting for completion
	if _context:
		_context.waiting_for_completion = true
		_context.completion_type = "cutscene"

	# Try to connect to common completion signals on the cutscene node
	if _cutscene_node.has_signal("cutscene_completed"):
		_connected_signal = "cutscene_completed"
		_cutscene_node.connect(_connected_signal, Callable(self, "_on_cutscene_completed"))
	elif _cutscene_node.has_signal("completed"):
		_connected_signal = "completed"
		_cutscene_node.connect(_connected_signal, Callable(self, "_on_cutscene_completed"))
	elif _cutscene_node.has_signal("finished"):
		_connected_signal = "finished"
		_cutscene_node.connect(_connected_signal, Callable(self, "_on_cutscene_completed"))
	else:
		# Fallback: listen for tree_exited (node removed) as completion
		_connected_signal = "tree_exited"
		_cutscene_node.connect("tree_exited", Callable(self, "_on_cutscene_completed"))

	# Optional: Show skip hint via GameUI if available
	if _context and _context.game_ui and _context.game_ui.has_method("show_skip_cutscene_hint"):
		_context.game_ui.show_skip_cutscene_hint()
		# Connect skip action if GameUI exposes a signal
		if _context.game_ui.has_signal("skip_cutscene") and not _context.game_ui.is_connected("skip_cutscene", Callable(self, "_on_cutscene_skipped")):
			_context.game_ui.connect("skip_cutscene", Callable(self, "_on_cutscene_skipped"))

	# Start a safety timeout in case the cutscene never signals completion
	# Use a 60s timeout by default
	_timeout_timer = Timer.new()
	_timeout_timer.wait_time = 60.0
	_timeout_timer.one_shot = true
	add_child(_timeout_timer)
	_timeout_timer.start()
	_timeout_timer.timeout.connect(Callable(self, "_on_cutscene_timeout"))

	print("[CutsceneStep] Cutscene started: %s" % scene_path)
	return true

func _on_cutscene_completed(arg = null):
	# Called when cutscene signals completion or node exits
	if not _context:
		# Shouldn't happen, but guard
		return
	# Clean up the node and any UI hints
	_cleanup_cutscene()

	# Emit completion
	_context.waiting_for_completion = false
	_context.completion_type = ""
	step_completed.emit(true)

func _on_cutscene_skipped():
	print("[CutsceneStep] Cutscene skipped by user")
	_on_cutscene_completed()

func _on_cutscene_timeout():
	push_warning("[CutsceneStep] Cutscene timeout reached - forcing completion")
	_on_cutscene_completed()

func _cleanup_cutscene():
	# Hide skip hint
	if _context and _context.game_ui and _context.game_ui.has_method("hide_skip_cutscene_hint"):
		_context.game_ui.hide_skip_cutscene_hint()

	# Disconnect signals and remove node
	if _cutscene_node:
		if _connected_signal != "" and _cutscene_node.is_connected(_connected_signal, Callable(self, "_on_cutscene_completed")):
			_cutscene_node.disconnect(_connected_signal, Callable(self, "_on_cutscene_completed"))
		if _cutscene_node.is_inside_tree():
			_cutscene_node.queue_free()
		_cutscene_node = null

	# Disconnect skip signal from GameUI if it was connected
	if _context and _context.game_ui and _context.game_ui.has_signal("skip_cutscene") and _context.game_ui.is_connected("skip_cutscene", Callable(self, "_on_cutscene_skipped")):
		_context.game_ui.disconnect("skip_cutscene", Callable(self, "_on_cutscene_skipped"))

	# Remove and free timeout timer
	if _timeout_timer and _timeout_timer.is_inside_tree():
		_timeout_timer.stop()
		remove_child(_timeout_timer)
		_timeout_timer.queue_free()
		_timeout_timer = null

func cleanup():
	# Ensure everything is cleaned if pipeline is aborted
	_cleanup_cutscene()
	if _context:
		_context.waiting_for_completion = false
		_context.completion_type = ""
