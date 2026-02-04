extends Node
class_name EffectExecutorGameplayPause

# Tracks active pauses (supports nested pauses)
var pause_stack: Array = []
var pause_timers: Dictionary = {}

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var duration = params.get("duration", 0.0)
	var resume_mode = params.get("resume_mode", "auto")

	print("[GameplayPauseExecutor] Pausing gameplay for %s seconds (mode=%s)" % [duration, resume_mode])

	# Get references to game components
	var viewport = context.get("viewport", null)
	var board_node = context.get("board", null)

	if not board_node:
		push_warning("[GameplayPauseExecutor] No board node in context - cannot pause")
		return

	# Create pause ID
	var pause_id = "pause_%d" % Time.get_ticks_msec()
	pause_stack.append(pause_id)

	# Pause board input
	_pause_board(board_node)

	# Auto-resume after duration
	if duration > 0 and resume_mode == "auto":
		if viewport and viewport.has_method("get_tree"):
			var tree = viewport.get_tree()
			if tree:
				var timer = tree.create_timer(duration)
				pause_timers[pause_id] = timer
				timer.timeout.connect(func(): _resume_from_pause(pause_id, board_node))

func _pause_board(board_node: Node) -> void:
	# Disable input processing on the board
	if board_node.has_method("set_process_input"):
		board_node.set_process_input(false)
	if board_node.has_method("set_process_unhandled_input"):
		board_node.set_process_unhandled_input(false)

	# Set a pause flag if the board supports it
	if "gameplay_paused" in board_node:
		board_node.gameplay_paused = true
	else:
		board_node.set_meta("gameplay_paused", true)

	print("[GameplayPauseExecutor] Board input disabled")

func _resume_from_pause(pause_id: String, board_node: Node) -> void:
	# Remove this pause from stack
	pause_stack.erase(pause_id)
	pause_timers.erase(pause_id)

	# Only resume if this was the last pause
	if pause_stack.is_empty():
		_resume_board(board_node)
		print("[GameplayPauseExecutor] Gameplay resumed (all pauses cleared)")
	else:
		print("[GameplayPauseExecutor] Still %d pauses active" % pause_stack.size())

func _resume_board(board_node: Node) -> void:
	if not is_instance_valid(board_node):
		return

	# Re-enable input processing
	if board_node.has_method("set_process_input"):
		board_node.set_process_input(true)
	if board_node.has_method("set_process_unhandled_input"):
		board_node.set_process_unhandled_input(true)

	# Clear pause flag
	if "gameplay_paused" in board_node:
		board_node.gameplay_paused = false
	else:
		board_node.set_meta("gameplay_paused", false)

	print("[GameplayPauseExecutor] Board input re-enabled")

func clear_all_pauses(board_node: Node) -> void:
	"""Emergency cleanup - called on level transitions"""
	pause_stack.clear()
	pause_timers.clear()
	if board_node and is_instance_valid(board_node):
		_resume_board(board_node)
