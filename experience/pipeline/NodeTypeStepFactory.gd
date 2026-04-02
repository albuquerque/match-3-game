extends RefCounted
# class_name NodeTypeStepFactory — removed, loaded via _step_factory() in FlowCoordinator

const _DEF_LOADER = preload("res://experience/pipeline/FlowStepDefinitionLoader.gd")

const _LoadLevelStep        = preload("res://experience/pipeline/steps/LoadLevelStep.gd")
const _ShowNarrativeStep    = preload("res://experience/pipeline/steps/ShowNarrativeStep.gd")
const _GrantRewardsStep     = preload("res://experience/pipeline/steps/GrantRewardsStep.gd")
const _ShowRewardsStep      = preload("res://experience/pipeline/steps/ShowRewardsStep.gd")
const _ShowLevelFailureStep = preload("res://experience/pipeline/steps/ShowLevelFailureStep.gd")
const _CutsceneStep         = preload("res://experience/pipeline/steps/CutsceneStep.gd")
const _UnlockStep           = preload("res://experience/pipeline/steps/UnlockStep.gd")
const _AdRewardStep         = preload("res://experience/pipeline/steps/AdRewardStep.gd")
const _PremiumGateStep      = preload("res://experience/pipeline/steps/PremiumGateStep.gd")
const _DLCFlowStep          = preload("res://experience/pipeline/steps/DLCFlowStep.gd")
const _ConditionalStep      = preload("res://experience/pipeline/steps/ConditionalStep.gd")

static var _DEF_CACHE: Dictionary = {}

## NodeTypeStepFactory
## Factory that converts flow node dictionaries into pipeline steps

static func _load_definition_local(def_id: String) -> Dictionary:
	if def_id == null or def_id == "":
		return {}
	if _DEF_CACHE.has(def_id):
		return _DEF_CACHE[def_id]
	var paths = ["res://data/flow_step_definitions/%s.json" % def_id, "user://flow_step_definitions/%s.json" % def_id]
	for p in paths:
		if FileAccess.file_exists(p):
			var f = FileAccess.open(p, FileAccess.READ)
			if f:
				var txt = f.get_as_text()
				f.close()
				var json = JSON.new()
				if json.parse(txt) == OK and typeof(json.get_data()) == TYPE_DICTIONARY:
					_DEF_CACHE[def_id] = json.get_data()
					return _DEF_CACHE[def_id]
				else:
					push_error("[NodeTypeStepFactory] Failed to parse JSON for %s: %s" % [p, json.get_error_message()])
			else:
				push_error("[NodeTypeStepFactory] Failed to open file: %s" % p)
	push_warning("[NodeTypeStepFactory] Definition not found: %s" % def_id)
	_DEF_CACHE[def_id] = {}
	return {}

static func create_step_from_node(node: Dictionary):
	var def_id = node.get("definition_id", "")
	if def_id != "":
		var def = _load_definition_local(def_id)
		var merged = {}
		for k in def.keys(): merged[k] = def[k]
		for k in node.keys(): merged[k] = node[k]
		node = merged

	var node_type = node.get("type", "")
	match node_type:
		"level":
			return _LoadLevelStep.new(node.get("id", ""))
		"narrative_stage":
			return _ShowNarrativeStep.new(node.get("id", ""), node.get("auto_advance_delay", 3.0), node.get("skippable", true))
		"reward":
			return _GrantRewardsStep.new(node.get("id", ""), node.get("rewards", []))
		"show_rewards":
			return _ShowRewardsStep.new(node.get("level_number", 0), node.get("completed", true))
		"show_level_failure":
			return _ShowLevelFailureStep.new(node.get("level_number", 0))
		"cutscene":
			return _CutsceneStep.new(node.get("scene", ""))
		"unlock":
			return _UnlockStep.new(node.get("id", ""))
		"ad_reward":
			return _AdRewardStep.new(node.get("id", ""), node.get("payload", {}))
		"premium_gate":
			return _PremiumGateStep.new(node.get("id", ""))
		"dlc_flow":
			return _DLCFlowStep.new(node.get("id", ""))
		"conditional":
			return _ConditionalStep.new(node.get("condition", ""), node.get("true_branch", {}), node.get("false_branch", {}))
		_:
			push_error("[NodeTypeStepFactory] Unknown node type: %s" % node_type)
			return null
