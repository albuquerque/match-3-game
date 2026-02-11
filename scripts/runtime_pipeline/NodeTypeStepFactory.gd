extends RefCounted
class_name NodeTypeStepFactory

## NodeTypeStepFactory
## Factory that converts flow node dictionaries into pipeline steps
## Eliminates conditional logic from ExperienceDirector

static func create_step_from_node(node: Dictionary) -> PipelineStep:
	"""Create appropriate pipeline step based on node type"""
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
	return LoadLevelStep.new(level_id)

static func _create_narrative_step(node: Dictionary) -> PipelineStep:
	var stage_id = node.get("id", "")
	var delay = node.get("auto_advance_delay", 3.0)
	var skippable = node.get("skippable", true)
	return ShowNarrativeStep.new(stage_id, delay, skippable)

static func _create_reward_step(node: Dictionary) -> PipelineStep:
	var reward_id = node.get("id", "")
	var rewards = node.get("rewards", [])
	return GrantRewardsStep.new(reward_id, rewards)

static func _create_cutscene_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement CutsceneStep
	push_warning("[NodeTypeStepFactory] Cutscene step not yet implemented")
	return null

static func _create_unlock_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement UnlockStep
	push_warning("[NodeTypeStepFactory] Unlock step not yet implemented")
	return null

static func _create_ad_reward_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement AdRewardStep
	push_warning("[NodeTypeStepFactory] AdReward step not yet implemented")
	return null

static func _create_premium_gate_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement PremiumGateStep
	push_warning("[NodeTypeStepFactory] PremiumGate step not yet implemented")
	return null

static func _create_dlc_flow_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement DLCFlowStep
	push_warning("[NodeTypeStepFactory] DLCFlow step not yet implemented")
	return null

static func _create_conditional_step(node: Dictionary) -> PipelineStep:
	# TODO: Implement ConditionalStep
	push_warning("[NodeTypeStepFactory] Conditional step not yet implemented")
	return null
