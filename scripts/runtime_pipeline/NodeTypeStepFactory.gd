extends RefCounted
class_name NodeTypeStepFactory

## NodeTypeStepFactory
## Factory that converts flow node dictionaries into pipeline steps
## Eliminates conditional logic from ExperienceDirector

static func create_step_from_node(node: Dictionary) -> PipelineStep:
	"""Create appropriate pipeline step based on node type
	Supports external definition files via `definition_id` key on node.
	Inline properties override definition values.
	"""
	# Resolve external definition if present
	var def_id = node.get("definition_id", "")
	if def_id != "":
		var def = FlowStepDefinitionLoader.load_definition(def_id)
		# Merge: copy def then overwrite with node values
		var merged = {}
		for k in def.keys():
			merged[k] = def[k]
		for k in node.keys():
			merged[k] = node[k]
		node = merged

	var node_type = node.get("type", "")

	match node_type:
		"level":
			return _create_level_step(node)
		"narrative_stage":
			return _create_narrative_step(node)
		"reward":
			return _create_reward_step(node)
		"cutscene":
			return _create_cutscene_step(node)
		"unlock":
			return _create_unlock_step(node)
		"ad_reward":
			return _create_ad_reward_step(node)
		"premium_gate":
			return _create_premium_gate_step(node)
		"dlc_flow":
			return _create_dlc_flow_step(node)
		"conditional":
			return _create_conditional_step(node)
		_:
			push_error("[NodeTypeStepFactory] Unknown node type: %s" % node_type)
			return null

static func _create_level_step(node: Dictionary) -> PipelineStep:
	var level_id = node.get("id", "")
	return load("res://scripts/runtime_pipeline/steps/LoadLevelStep.gd").new(level_id)

static func _create_narrative_step(node: Dictionary) -> PipelineStep:
	var stage_id = node.get("id", "")
	var delay = node.get("auto_advance_delay", 3.0)
	var skippable = node.get("skippable", true)
	return load("res://scripts/runtime_pipeline/steps/ShowNarrativeStep.gd").new(stage_id, delay, skippable)

static func _create_reward_step(node: Dictionary) -> PipelineStep:
	var reward_id = node.get("id", "")
	var rewards = node.get("rewards", [])
	return load("res://scripts/runtime_pipeline/steps/GrantRewardsStep.gd").new(reward_id, rewards)

static func _create_cutscene_step(node: Dictionary) -> PipelineStep:
	var scene_path = node.get("scene", "")
	return load("res://scripts/runtime_pipeline/steps/CutsceneStep.gd").new(scene_path)

static func _create_unlock_step(node: Dictionary) -> PipelineStep:
	var unlock_id = node.get("id", "")
	return load("res://scripts/runtime_pipeline/steps/UnlockStep.gd").new(unlock_id)

static func _create_ad_reward_step(node: Dictionary) -> PipelineStep:
	var reward_id = node.get("id", "")
	var payload = node.get("payload", {})
	return load("res://scripts/runtime_pipeline/steps/AdRewardStep.gd").new(reward_id, payload)

static func _create_premium_gate_step(node: Dictionary) -> PipelineStep:
	var gate_id = node.get("id", "")
	return load("res://scripts/runtime_pipeline/steps/PremiumGateStep.gd").new(gate_id)

static func _create_dlc_flow_step(node: Dictionary) -> PipelineStep:
	var dlc_id = node.get("id", "")
	return load("res://scripts/runtime_pipeline/steps/DLCFlowStep.gd").new(dlc_id)

static func _create_conditional_step(node: Dictionary) -> PipelineStep:
	var cond = node.get("condition", "")
	var t_branch = node.get("true_branch", {})
	var f_branch = node.get("false_branch", {})
	return load("res://scripts/runtime_pipeline/steps/ConditionalStep.gd").new(cond, t_branch, f_branch)
