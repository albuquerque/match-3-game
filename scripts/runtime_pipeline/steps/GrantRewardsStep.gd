extends PipelineStep
class_name GrantRewardsStep

## GrantRewardsStep
## Grants rewards directly without showing popups
## Rewards are displayed on transition screen instead

var reward_id: String = ""
var rewards_list: Array = []

func _init(rwd_id: String = "", rwds: Array = []):
	super("grant_rewards")
	reward_id = rwd_id
	rewards_list = rwds

func execute(context: PipelineContext) -> bool:
	if rewards_list.is_empty():
		print("[GrantRewardsStep] No rewards to grant")
		return true

	print("[GrantRewardsStep] Granting %d reward(s) for: %s" % [rewards_list.size(), reward_id])

	# Grant each reward
	for reward in rewards_list:
		_grant_single_reward(reward)

	# Store reward info in context for transition screen
	context.set_result("last_rewards", {
		"reward_id": reward_id,
		"rewards": rewards_list
	})

	return true

func _grant_single_reward(reward: Dictionary):
	var reward_type = reward.get("type", "")
	var amount = reward.get("amount", 0)

	match reward_type:
		"coins":
			if RewardManager:
				RewardManager.add_coins(amount)
				print("[GrantRewardsStep] Granted %d coins" % amount)

		"gems":
			if RewardManager:
				RewardManager.add_gems(amount)
				print("[GrantRewardsStep] Granted %d gems" % amount)

		"booster":
			var booster_type = reward.get("booster_type", "")
			if RewardManager and RewardManager.has_method("add_booster") and not booster_type.is_empty():
				RewardManager.add_booster(booster_type, amount)
				print("[GrantRewardsStep] Granted %d x %s booster" % [amount, booster_type])

		"card":
			var collection_id = reward.get("collection_id", "")
			var card_id = reward.get("card_id", "")
			if CollectionManager and not collection_id.is_empty() and not card_id.is_empty():
				var unlocked = CollectionManager.unlock_item(collection_id, card_id)
				if unlocked:
					print("[GrantRewardsStep] Unlocked card: %s/%s" % [collection_id, card_id])
				else:
					print("[GrantRewardsStep] Card already unlocked: %s/%s" % [collection_id, card_id])

		"gallery_image":
			var image_name = reward.get("image_name", "")
			print("[GrantRewardsStep] Gallery image unlock: %s" % image_name)

		"theme":
			var theme_name = reward.get("theme_name", "")
			print("[GrantRewardsStep] Theme unlock: %s" % theme_name)

		"video":
			var video_name = reward.get("video_name", "")
			print("[GrantRewardsStep] Video unlock: %s" % video_name)

		_:
			push_warning("[GrantRewardsStep] Unknown reward type: %s" % reward_type)
