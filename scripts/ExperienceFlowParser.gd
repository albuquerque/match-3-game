extends Node

## ExperienceFlowParser
## Parses and validates experience flow JSON files
## Handles flow loading, validation, and error handling

# Valid node types
const VALID_NODE_TYPES = [
	"level",
	"narrative_stage",
	"reward",
	"cutscene",
	"unlock",
	"ad_reward",
	"premium_gate",
	"dlc_flow",
	"conditional"
]

# Cache for loaded flows
var loaded_flows: Dictionary = {}

func parse_flow_file(file_path: String) -> Dictionary:
	"""Parse an experience flow JSON file"""

	# Check cache first
	if file_path in loaded_flows:
		print("[ExperienceFlowParser] Loading flow from cache: ", file_path)
		return loaded_flows[file_path]

	# Check if file exists
	if not FileAccess.file_exists(file_path):
		print("[ExperienceFlowParser] ERROR: Flow file not found: ", file_path)
		return {}

	# Load and parse JSON
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("[ExperienceFlowParser] ERROR: Could not open flow file: ", file_path)
		return {}

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("[ExperienceFlowParser] ERROR: Failed to parse JSON in: ", file_path)
		print("[ExperienceFlowParser] Error: ", json.get_error_message())
		return {}

	var flow_data = json.data

	# Validate flow structure
	if not validate_flow(flow_data, file_path):
		print("[ExperienceFlowParser] ERROR: Invalid flow structure in: ", file_path)
		return {}

	# Cache the flow
	loaded_flows[file_path] = flow_data

	print("[ExperienceFlowParser] Successfully loaded flow: ", flow_data.get("experience_id", "unknown"))
	return flow_data

func validate_flow(flow_data: Dictionary, file_path: String = "") -> bool:
	"""Validate flow structure and required fields"""

	# Check required fields
	if not flow_data.has("experience_id"):
		print("[ExperienceFlowParser] ERROR: Missing 'experience_id' in ", file_path)
		return false

	if not flow_data.has("version"):
		print("[ExperienceFlowParser] ERROR: Missing 'version' in ", file_path)
		return false

	if not flow_data.has("flow"):
		print("[ExperienceFlowParser] ERROR: Missing 'flow' array in ", file_path)
		return false

	# Validate flow array
	var flow = flow_data["flow"]
	if not flow is Array:
		print("[ExperienceFlowParser] ERROR: 'flow' must be an array in ", file_path)
		return false

	# Validate each node
	for i in range(flow.size()):
		var node = flow[i]
		if not validate_node(node, i, file_path):
			return false

	print("[ExperienceFlowParser] Flow validation passed: ", flow_data.get("experience_id"))
	return true

func validate_node(node: Dictionary, index: int, file_path: String = "") -> bool:
	"""Validate a single flow node"""

	# Check required fields
	if not node.has("type"):
		print("[ExperienceFlowParser] ERROR: Node at index ", index, " missing 'type' in ", file_path)
		return false

	var node_type = node["type"]

	# Validate node type
	if not node_type in VALID_NODE_TYPES:
		print("[ExperienceFlowParser] ERROR: Invalid node type '", node_type, "' at index ", index, " in ", file_path)
		print("[ExperienceFlowParser] Valid types: ", VALID_NODE_TYPES)
		return false

	# Type-specific validation
	match node_type:
		"level":
			if not node.has("id"):
				print("[ExperienceFlowParser] ERROR: 'level' node at index ", index, " missing 'id' in ", file_path)
				return false

		"narrative_stage":
			if not node.has("id"):
				print("[ExperienceFlowParser] ERROR: 'narrative_stage' node at index ", index, " missing 'id' in ", file_path)
				return false

		"reward":
			if not node.has("id"):
				print("[ExperienceFlowParser] ERROR: 'reward' node at index ", index, " missing 'id' in ", file_path)
				return false

		"dlc_flow":
			if not node.has("id"):
				print("[ExperienceFlowParser] ERROR: 'dlc_flow' node at index ", index, " missing 'id' in ", file_path)
				return false

		"conditional":
			if not node.has("condition"):
				print("[ExperienceFlowParser] ERROR: 'conditional' node at index ", index, " missing 'condition' in ", file_path)
				return false
			if not node.has("then"):
				print("[ExperienceFlowParser] ERROR: 'conditional' node at index ", index, " missing 'then' branch in ", file_path)
				return false

	return true

func get_node_at_index(flow_data: Dictionary, index: int) -> Dictionary:
	"""Get a specific node from a flow by index"""

	if not flow_data.has("flow"):
		print("[ExperienceFlowParser] ERROR: Flow data missing 'flow' array")
		return {}

	var flow = flow_data["flow"]
	if index < 0 or index >= flow.size():
		print("[ExperienceFlowParser] ERROR: Index ", index, " out of bounds (flow size: ", flow.size(), ")")
		return {}

	return flow[index]

func get_flow_length(flow_data: Dictionary) -> int:
	"""Get the number of nodes in a flow"""

	if not flow_data.has("flow"):
		return 0

	return flow_data["flow"].size()

func clear_cache():
	"""Clear the flow cache (useful for hot-reloading in development)"""
	loaded_flows.clear()
	print("[ExperienceFlowParser] Flow cache cleared")

func reload_flow(file_path: String) -> Dictionary:
	"""Force reload a flow from disk, bypassing cache"""
	if file_path in loaded_flows:
		loaded_flows.erase(file_path)
	return parse_flow_file(file_path)

# Node type helpers
func is_level_node(node: Dictionary) -> bool:
	return node.get("type") == "level"

func is_narrative_stage_node(node: Dictionary) -> bool:
	return node.get("type") == "narrative_stage"

func is_reward_node(node: Dictionary) -> bool:
	return node.get("type") == "reward"

func is_cutscene_node(node: Dictionary) -> bool:
	return node.get("type") == "cutscene"

func is_unlock_node(node: Dictionary) -> bool:
	return node.get("type") == "unlock"

func is_ad_reward_node(node: Dictionary) -> bool:
	return node.get("type") == "ad_reward"

func is_premium_gate_node(node: Dictionary) -> bool:
	return node.get("type") == "premium_gate"

func is_dlc_flow_node(node: Dictionary) -> bool:
	return node.get("type") == "dlc_flow"

func is_conditional_node(node: Dictionary) -> bool:
	return node.get("type") == "conditional"

# Utility methods
func get_node_id(node: Dictionary) -> String:
	"""Get the ID of a node (if it has one)"""
	return node.get("id", "")

func get_node_type(node: Dictionary) -> String:
	"""Get the type of a node"""
	return node.get("type", "unknown")

func node_to_string(node: Dictionary) -> String:
	"""Get a human-readable string representation of a node"""
	var type = get_node_type(node)
	var id = get_node_id(node)

	if id.is_empty():
		return type
	else:
		return "%s: %s" % [type, id]

func print_flow_summary(flow_data: Dictionary):
	"""Print a summary of a flow for debugging"""
	print("=== Experience Flow Summary ===")
	print("  ID: ", flow_data.get("experience_id", "unknown"))
	print("  Version: ", flow_data.get("version", "unknown"))
	print("  Description: ", flow_data.get("description", "none"))
	print("  Nodes: ", get_flow_length(flow_data))

	if flow_data.has("flow"):
		print("  Flow:")
		for i in range(flow_data["flow"].size()):
			var node = flow_data["flow"][i]
			print("    [%d] %s" % [i, node_to_string(node)])

	print("===============================")
