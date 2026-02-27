extends PipelineStep
class_name AdRewardStep

# AdRewardStep
# Grants rewards after an ad is shown. If no ad system available, grants immediately.

var reward_id: String = ""
var reward_payload: Dictionary = {}
var NodeResolvers = null

func _init(id: String = "", payload: Dictionary = {}):
	super("ad_reward")
	reward_id = id
	reward_payload = payload

func _ensure_resolvers():
	if NodeResolvers == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL:
			NodeResolvers = s
		else:
			NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

func execute(context: PipelineContext) -> bool:
	_ensure_resolvers()
	print("[AdRewardStep] Processing ad reward: %s" % reward_id)
	# If RewardManager supports a generic grant method, use it
	var rm = NodeResolvers._get_rm() if typeof(NodeResolvers) != TYPE_NIL else null
	if rm and rm.has_method("grant_rewards") and reward_payload:
		rm.grant_rewards(reward_payload)
		step_completed.emit(true)
		return true
	# Fallback: emit EventBus custom event
	var ev = NodeResolvers._get_evbus() if typeof(NodeResolvers) != TYPE_NIL else null
	if ev and ev.has_method("emit_custom"):
		ev.emit_custom("ad_reward_granted", reward_id, reward_payload)
	step_completed.emit(true)
	return true

func cleanup():
	pass
