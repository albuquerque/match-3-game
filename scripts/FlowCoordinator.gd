extends Node
class_name FlowCoordinator

## FlowCoordinator
## Thin orchestrator that delegates to pipeline
## NO gameplay logic - only flow management

signal flow_started(flow_id: String)
signal flow_completed(flow_id: String)
signal flow_failed(flow_id: String, reason: String)
signal node_started(node: Dictionary)
signal node_completed(node: Dictionary)

# Components
var parser: Node = null  # ExperienceFlowParser
var state: Node = null   # ExperienceState
var pipeline: ExperiencePipeline = null

# Current flow data
var current_flow: Dictionary = {}
var current_flow_id: String = ""

func _ready():
	print("[FlowCoordinator] Initializing...")
	_create_components()
	print("[FlowCoordinator] Ready")

func _create_components():
	# Create parser
	parser = Node.new()
	parser.name = "ExperienceFlowParser"
	parser.set_script(preload("res://scripts/ExperienceFlowParser.gd"))
	add_child(parser)

	# Create state
	state = Node.new()
	state.name = "ExperienceState"
	state.set_script(preload("res://scripts/ExperienceState.gd"))
	add_child(state)

	# Create pipeline
	pipeline = ExperiencePipeline.new()
	add_child(pipeline)

	# Connect pipeline signals
	pipeline.pipeline_completed.connect(_on_pipeline_completed)
	pipeline.pipeline_failed.connect(_on_pipeline_failed)

	print("[FlowCoordinator] Components created")

func load_flow(flow_id: String) -> bool:
	"""Load an experience flow by ID"""
	var flow_path = "res://data/experience_flows/%s.json" % flow_id

	print("[FlowCoordinator] Loading flow: %s" % flow_id)

	current_flow = parser.parse_flow_file(flow_path)

	if current_flow.is_empty():
		push_error("[FlowCoordinator] Failed to load flow: %s" % flow_id)
		return false

	current_flow_id = flow_id
	state.set_flow(flow_id)

	print("[FlowCoordinator] Flow loaded: %s" % flow_id)
	return true

func start_flow() -> void:
	"""Start executing the current flow"""
	if current_flow.is_empty():
		push_error("[FlowCoordinator] No flow loaded")
		return

	print("[FlowCoordinator] Starting flow: %s" % current_flow_id)
	emit_signal("flow_started", current_flow_id)

	# Build execution context
	var context = ExecutionContextBuilder.build_from_scene_tree()
	context.flow_id = current_flow_id
	context.flow_nodes = current_flow.get("flow", [])
	context.current_node_index = state.current_level_index

	# Build pipeline steps from flow nodes
	var steps = _build_steps_from_flow(context)

	if steps.is_empty():
		push_error("[FlowCoordinator] No valid steps to execute")
		return

	# Start pipeline
	pipeline.start(context, steps)

func start_flow_at_level(level_num: int) -> void:
	"""Start flow at a specific level"""
	if current_flow.is_empty():
		push_error("[FlowCoordinator] No flow loaded")
		return

	print("[FlowCoordinator] Starting flow at level %d" % level_num)

	# Find level node index
	var level_id = "level_%02d" % level_num
	var target_index = _find_level_node_index(level_id)

	if target_index < 0:
		push_warning("[FlowCoordinator] Level %s not found in flow" % level_id)
		start_flow()
		return

	# Check for narrative before level
	var flow_nodes = current_flow.get("flow", [])
	if target_index > 0:
		var prev_node = flow_nodes[target_index - 1]
		if prev_node.get("type") == "narrative_stage":
			target_index = target_index - 1
			print("[FlowCoordinator] Starting from preceding narrative")

	# Update state
	state.current_level_index = target_index

	# Build context and steps
	var context = ExecutionContextBuilder.build_from_scene_tree()
	context.flow_id = current_flow_id
	context.flow_nodes = flow_nodes
	context.current_node_index = target_index

	var steps = _build_steps_from_index(context, target_index)

	if steps.is_empty():
		push_error("[FlowCoordinator] No valid steps from index %d" % target_index)
		return

	pipeline.start(context, steps)

func _build_steps_from_flow(context: PipelineContext) -> Array:
	"""Build pipeline steps from flow nodes starting at current index"""
	return _build_steps_from_index(context, context.current_node_index)

func _build_steps_from_index(context: PipelineContext, start_index: int) -> Array:
	"""Build pipeline steps from a specific node index"""
	var steps: Array = []
	var flow_nodes = context.flow_nodes

	if start_index >= flow_nodes.size():
		return steps

	# Create steps for the remaining flow starting from start_index
	# This allows narrative -> level -> reward sequences to execute
	for i in range(start_index, flow_nodes.size()):
		var node = flow_nodes[i]
		var step = NodeTypeStepFactory.create_step_from_node(node)

		if step:
			steps.append(step)
			print("[FlowCoordinator] Created step for node %d: %s (%s)" % [i, step.step_name, node.get("type", "unknown")])
		else:
			# Skip nodes that don't have step implementations yet
			print("[FlowCoordinator] No step implementation for node %d type: %s" % [i, node.get("type", "unknown")])

	return steps

func _find_level_node_index(level_id: String) -> int:
	"""Find the index of a level node in the flow"""
	var flow_nodes = current_flow.get("flow", [])

	for i in range(flow_nodes.size()):
		var node = flow_nodes[i]
		if node.get("type") == "level" and node.get("id") == level_id:
			return i

	return -1

func _on_pipeline_completed(flow_id: String):
	print("[FlowCoordinator] Flow completed: %s" % flow_id)
	emit_signal("flow_completed", flow_id)

func _on_pipeline_failed(flow_id: String, reason: String):
	push_error("[FlowCoordinator] Flow failed: %s - %s" % [flow_id, reason])
	emit_signal("flow_failed", flow_id, reason)

func get_state_data() -> Dictionary:
	"""Get state data for saving"""
	if state:
		return state.to_dict()
	return {}

func load_state_data(data: Dictionary):
	"""Load state data from save"""
	if state:
		state.from_dict(data)
		if not state.current_flow_id.is_empty():
			load_flow(state.current_flow_id)
