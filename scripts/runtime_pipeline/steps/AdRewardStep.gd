extends PipelineStep
class_name AdRewardStep

# AdRewardStep
# Grants rewards after an ad is shown. If no ad system available, grants immediately.

var reward_id: String = ""
var reward_payload: Dictionary = {}

func _init(id: String = "", payload: Dictionary = {}):
	super("ad_reward")
	reward_id = id
	reward_payload = payload

func execute(context: PipelineContext) -> bool:
	print("[AdRewardStep] Processing ad reward: %s" % reward_id)
	# If RewardManager supports a generic grant method, use it
	if RewardManager and RewardManager.has_method("grant_rewards") and reward_payload:
		RewardManager.grant_rewards(reward_payload)
		step_completed.emit(true)
		return true
	# Fallback: emit EventBus custom event
	if EventBus and EventBus.has_method("emit_custom"):
		EventBus.emit_custom("ad_reward_granted", reward_id, reward_payload)
	step_completed.emit(true)
	return true

func cleanup():
	pass
