extends Node
class_name EffectExecutorTimelineSequence

# Runs a small timeline/sequence of steps provided in params.
# Params:
#  - sequence: Array of step dictionaries. Each step supports:
#     - delay (float): seconds to wait before running the step (relative to previous)
#     - event (String): name of EventBus event to emit
#     - event_args (Array): optional array of arguments to pass to the event
#     - binding (Dictionary): effect binding to execute via EffectResolver (if provided)
#     - callable (Dictionary): { "node": "path_or_name", "method": "method_name", "args": [] }
#  - id: optional id used for logging
# The executor will use EventBus if available and will attempt to call EffectResolver via /root/EffectResolver if needed.
func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	# Support both "steps" and "sequence" for backward compatibility
	var sequence = params.get("steps", params.get("sequence", []))
	var seq_id = params.get("id", "")
	var board_node = context.get("board", null)

	if typeof(sequence) != TYPE_ARRAY or sequence.size() == 0:
		print("[TimelineSequenceExecutor] Empty or invalid sequence - skipping")
		return

	print("[TimelineSequenceExecutor] Running sequence '%s' with %d steps" % [seq_id, sequence.size()])

	# Schedule steps sequentially using timers
	var time_cursor = 0.0
	for s in sequence:
		var delay = float(s.get("delay", 0.0))
		time_cursor += delay
		var step = s
		# Schedule the step using a simple timer approach
		_schedule_step_simple(time_cursor, step, viewport, params, context, board_node)

# Simple timer-based scheduling without await (to avoid tree context issues)
func _schedule_step_simple(delay: float, step: Dictionary, viewport: Node, params: Dictionary, context: Dictionary, board_node: Node) -> void:
	# Resolve an appropriate SceneTree to create timers on
	var tree = null
	if board_node and is_instance_valid(board_node):
		tree = board_node.get_tree()
	if not tree and viewport and viewport is Node:
		tree = viewport.get_tree()
	if not tree and has_method("get_tree"):
		tree = get_tree()

	if tree == null or delay <= 0.0:
		# No tree or no delay: run immediately
		call_deferred("_run_step", step, viewport, params, context, board_node)
		return

	# Create timer and connect to a simple callback
	var timer = tree.create_timer(delay)
	var callback = func():
		_run_step(step, viewport, params, context, board_node)
	timer.timeout.connect(callback)

# Top-level helper to run a step
func _run_step(step: Dictionary, viewport: Node, params: Dictionary, context: Dictionary, board_node: Node) -> void:
	if not step or typeof(step) != TYPE_DICTIONARY:
		return

	# Resolve EventBus/EffectResolver from SceneTree root
	# Use board_node or viewport to get the tree, not self (which may not be in tree)
	var root = null
	if board_node and is_instance_valid(board_node):
		var tree = board_node.get_tree()
		if tree:
			root = tree.get_root()
	if not root and viewport and viewport is Node:
		var tree = viewport.get_tree()
		if tree:
			root = tree.get_root()
	var event_bus = null
	var resolver = null
	if root:
		event_bus = root.get_node_or_null("EventBus")
		resolver = root.get_node_or_null("EffectResolver")

	# If step has "effect" directly (new format), convert to binding format
	if step.has("effect") and not step.has("binding"):
		var binding = {
			"effect": step.get("effect"),
			"params": step.get("params", {})
		}
		step = {"binding": binding}

	# If binding provided, ask EffectResolver to execute it directly
	if step.has("binding") and resolver:
		var binding = step.get("binding")
		var exec_context = {
			"binding": binding,
			"entity_id": step.get("entity_id", ""),
			"event_context": params.get("event_context", {}),
			"anchor": binding.get("anchor", ""),
			"target": binding.get("target", ""),
			"params": binding.get("params", {}),
			"viewport": viewport,
			"chapter": context.get("chapter", null),
			"board": board_node
		}
		if resolver and resolver.has_method("_execute_effect"):
			resolver._execute_effect(binding, step.get("entity_id", ""), exec_context)
			return

	# If event specified, emit on EventBus (with safe arg expansion)
	if step.has("event") and event_bus:
		var ev_name = step.get("event")
		var ev_args = step.get("event_args", [])
		_emit_signal_wrapped(event_bus, ev_name, ev_args)
		return

	# If callable specified, resolve node and call method
	if step.has("callable"):
		var cinfo = step.get("callable")
		var node_ref = null
		var node_name = cinfo.get("node", "")
		if node_name != "":
			# Prefer resolving under board_node first
			if board_node and is_instance_valid(board_node):
				node_ref = _resolve_node_under(board_node, node_name)
			# Then try under viewport
			if not node_ref and viewport and viewport is Node:
				node_ref = _resolve_node_under(viewport, node_name)
			# Last resort: try global paths under root
			if not node_ref and root:
				node_ref = root.get_node_or_null(node_name)

			var method_name = cinfo.get("method", "")
			var args = cinfo.get("args", [])
			if node_ref and method_name != "" and node_ref.has_method(method_name):
				node_ref.callv(method_name, args)
				return

	# Nothing matched
	print("[TimelineSequenceExecutor] Step had no actionable items: %s" % str(step))

# Helper to emit signals with argument expansion (supports up to 5 args; extend if needed)
func _emit_signal_wrapped(bus: Node, name: String, args: Array) -> void:
	if not bus:
		return
	if args == null or args.size() == 0:
		bus.emit_signal(name)
		return
	match args.size():
		1:
			bus.emit_signal(name, args[0])
			return
		2:
			bus.emit_signal(name, args[0], args[1])
			return
		3:
			bus.emit_signal(name, args[0], args[1], args[2])
			return
		4:
			bus.emit_signal(name, args[0], args[1], args[2], args[3])
			return
		5:
			bus.emit_signal(name, args[0], args[1], args[2], args[3], args[4])
			return
		_:
			# Fallback: call via callv
			var call_args = [name] + args
			bus.callv("emit_signal", call_args)

# Helper: resolve node under a root Node recursively by name or path
func _resolve_node_under(root: Node, name: String) -> Node:
	if not root or name == "":
		return null
	# If name is a path relative to root
	if root.has_node(name):
		return root.get_node(name)
	# Recursive search
	if root.has_method("get_child_count"):
		var cc = root.get_child_count()
		for i in range(cc):
			var c = root.get_child(i)
			if not c:
				continue
			if str(c.name) == name:
				return c
			var found = _resolve_node_under(c, name)
			if found:
				return found
	return null
