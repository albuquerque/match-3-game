extends RefCounted
class_name PipelineContext

## PipelineContext
## Holds shared execution state and runtime references for pipeline steps
## Eliminates need for scene tree searches during execution

# Flow execution data
var flow_id: String = ""
var current_node: Dictionary = {}
var current_node_index: int = 0
var flow_nodes: Array = []

# Runtime references (set once, used by all steps)
var game_board: Node = null
var game_ui: Node = null
var viewport: Window = null
var overlay_layer: CanvasLayer = null

# State tracking
var waiting_for_completion: bool = false
var completion_type: String = ""  # "level", "narrative", "ad", etc.

# Results from previous steps
var step_results: Dictionary = {}

func _init():
	viewport = Engine.get_main_loop().root if Engine.get_main_loop() else null

func set_runtime_references(board: Node, ui: Node, overlay: CanvasLayer = null):
	"""Set all runtime references at once to avoid scene tree lookups"""
	game_board = board
	game_ui = ui
	overlay_layer = overlay
	print("[PipelineContext] Runtime references set")

func get_result(step_name: String, default = null):
	"""Get result from a previous step"""
	return step_results.get(step_name, default)

func set_result(step_name: String, value):
	"""Store result from a step for later steps"""
	step_results[step_name] = value

func clear_results():
	"""Clear all step results"""
	step_results.clear()

func is_valid() -> bool:
	"""Check if context has minimum required references"""
	return viewport != null
