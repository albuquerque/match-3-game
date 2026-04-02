extends "res://experience/pipeline/PipelineStep.gd"
class_name AdRewardStep

# AdRewardStep
# Grants rewards after an ad is shown. If no ad system available, grants immediately.

var reward_id: String = ""
var reward_payload: Dictionary = {}

func _init(id: String = "", payload: Dictionary = {}):
	super("ad_reward")
	reward_id = id
	reward_payload = payload

func execute(context) -> bool:
	print("[AdRewardStep] Processing ad reward: %s" % reward_id)
	if RewardManager and RewardManager.has_method("grant_rewards") and reward_payload:
		RewardManager.grant_rewards(reward_payload)
	else:
		push_warning("[AdRewardStep] RewardManager not found for reward: %s" % reward_id)
	step_completed.emit(true)
	return true

func cleanup():
	pass
