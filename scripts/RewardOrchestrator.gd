extends Node

## RewardOrchestrator
## Handles visual display and animation of rewards from Experience Director
## Integrates with RewardManager for actual reward granting

signal rewards_displayed
signal all_rewards_granted

# Queue for batching rewards
var reward_queue: Array = []
var is_processing: bool = false

# Reference to RewardNotification (will be set by GameUI or created)
var reward_notification: Node = null

func _ready():
	print("============================================================")
	print("[RewardOrchestrator] *** INITIALIZING ***")
	print("============================================================")

## Queue a reward for display and granting
func queue_reward(reward_data: Dictionary):
	"""Add a reward to the queue for processing"""

	print("============================================================")
	print("[RewardOrchestrator] *** QUEUEING REWARD ***")
	print("============================================================")
	print("[RewardOrchestrator] Reward ID: ", reward_data.get("id", "unknown"))
	print("[RewardOrchestrator] Reward data: ", JSON.stringify(reward_data, "\t"))

	reward_queue.append(reward_data)
	print("[RewardOrchestrator] Queue size: ", reward_queue.size())

	# Auto-process if not already processing
	if not is_processing:
		print("[RewardOrchestrator] Starting automatic processing...")
		process_reward_queue()
	else:
		print("[RewardOrchestrator] Already processing, will process this later")

## Process all queued rewards
func process_reward_queue():
	"""Process all rewards in the queue with animations"""

	if reward_queue.is_empty():
		print("[RewardOrchestrator] No rewards to process")
		return

	if is_processing:
		print("[RewardOrchestrator] Already processing rewards")
		return

	is_processing = true
	print("[RewardOrchestrator] Processing %d reward(s)" % reward_queue.size())

	# Process each reward
	for reward_data in reward_queue:
		await _process_single_reward(reward_data)

	# Clear queue
	reward_queue.clear()
	is_processing = false

	emit_signal("all_rewards_granted")
	print("[RewardOrchestrator] All rewards processed")

## Process a single reward node from the flow
func _process_single_reward(reward_data: Dictionary):
	"""Process a single reward with animation"""

	var reward_id = reward_data.get("id", "unknown")
	var rewards_list = reward_data.get("rewards", [])

	print("[RewardOrchestrator] Processing reward: ", reward_id)

	if rewards_list.is_empty():
		print("[RewardOrchestrator] No rewards in list for: ", reward_id)
		return

	# Grant each reward type
	for reward in rewards_list:
		await _grant_reward(reward)

	emit_signal("rewards_displayed")

## Grant a single reward and show notification
func _grant_reward(reward: Dictionary):
	"""Grant a reward and display notification"""

	var reward_type = reward.get("type", "unknown")

	match reward_type:
		"coins":
			await _grant_coins(reward)
		"gems":
			await _grant_gems(reward)
		"booster":
			await _grant_booster(reward)
		"card":
			await _grant_card(reward)
		"theme":
			await _grant_theme(reward)
		"gallery_image":
			await _grant_gallery_image(reward)
		_:
			print("[RewardOrchestrator] Unknown reward type: ", reward_type)

## Grant coins reward
func _grant_coins(reward: Dictionary):
	"""Grant coins and show notification"""

	var amount = reward.get("amount", 0)

	if amount <= 0:
		print("[RewardOrchestrator] Invalid coin amount: ", amount)
		return

	# Grant via RewardManager
	if RewardManager:
		RewardManager.add_coins(amount)
		print("[RewardOrchestrator] Granted %d coins" % amount)

	# Show notification with correct parameters
	await _show_notification("coins", amount, "Earned from completing level")

## Grant gems reward
func _grant_gems(reward: Dictionary):
	"""Grant gems and show notification"""

	var amount = reward.get("amount", 0)

	if amount <= 0:
		print("[RewardOrchestrator] Invalid gem amount: ", amount)
		return

	# Grant via RewardManager
	if RewardManager:
		RewardManager.add_gems(amount)
		print("[RewardOrchestrator] Granted %d gems" % amount)

	# Show notification with correct parameters
	await _show_notification("gems", amount, "Earned from completing level")

## Grant booster reward
func _grant_booster(reward: Dictionary):
	"""Grant booster and show notification"""

	var booster_type = reward.get("booster_type", "")
	var amount = reward.get("amount", 1)

	if booster_type.is_empty():
		print("[RewardOrchestrator] Invalid booster type")
		return

	# Grant via RewardManager
	if RewardManager:
		RewardManager.add_booster(booster_type, amount)
		print("[RewardOrchestrator] Granted %d x %s booster" % [amount, booster_type])

	# Format booster name nicely
	var booster_name = _format_booster_name(booster_type)

	# Show notification - use 'booster' type with amount and description
	await _show_notification("booster", amount, booster_name)

## Grant card reward (for collection system - Phase 8)
func _grant_card(reward: Dictionary):
	"""Grant card and show notification"""

	var card_id = reward.get("id", "")

	if card_id.is_empty():
		print("[RewardOrchestrator] Invalid card ID")
		return

	# TODO: Integrate with CollectionManager (Phase 8)
	print("[RewardOrchestrator] Granted card: ", card_id)

	# Show notification via fallback (RewardNotification doesn't have 'card' type)
	await _show_notification_fallback("Card Unlocked", card_id, 2.0)

## Grant theme reward
func _grant_theme(reward: Dictionary):
	"""Grant theme and show notification"""

	var theme_id = reward.get("id", "")

	if theme_id.is_empty():
		print("[RewardOrchestrator] Invalid theme ID")
		return

	# Grant via RewardManager
	if RewardManager:
		RewardManager.unlock_theme(theme_id)
		print("[RewardOrchestrator] Granted theme: ", theme_id)

	# Show notification via fallback (RewardNotification doesn't have 'theme' type)
	await _show_notification_fallback("Theme Unlocked", theme_id, 2.0)

## Grant gallery image reward
func _grant_gallery_image(reward: Dictionary):
	"""Grant gallery image and show notification"""

	var image_id = reward.get("id", "")

	if image_id.is_empty():
		print("[RewardOrchestrator] Invalid gallery image ID")
		return

	# Grant via RewardManager
	if RewardManager:
		if not image_id in RewardManager.unlocked_gallery_images:
			RewardManager.unlocked_gallery_images.append(image_id)
			RewardManager.save_progress()
			print("[RewardOrchestrator] Granted gallery image: ", image_id)
		else:
			print("[RewardOrchestrator] Gallery image already unlocked: ", image_id)
			return  # Don't show notification for duplicates

	# Show notification via fallback (RewardNotification doesn't have 'gallery' type)
	await _show_notification_fallback("Gallery Unlocked", image_id, 2.0)

## Show reward notification
func _show_notification(reward_type: String, amount: int, description: String = ""):
	"""Display a reward notification to the player using RewardNotification"""

	# Try to find RewardNotification in the scene tree
	if not reward_notification:
		reward_notification = _find_reward_notification()

	if reward_notification and reward_notification.has_method("show_reward"):
		# Use existing RewardNotification system with correct signature
		reward_notification.show_reward(reward_type, amount, description)
		print("[RewardOrchestrator] Displayed notification: %s x%d - %s" % [reward_type, amount, description])
	else:
		# Fallback: just log
		print("[RewardOrchestrator] REWARD: %s x%d - %s" % [reward_type, amount, description])

	# Wait for notification to display
	await get_tree().create_timer(1.5).timeout

## Show notification fallback for types not supported by RewardNotification
func _show_notification_fallback(title: String, message: String, duration: float = 2.0):
	"""Display a simple text notification for unsupported reward types"""

	# Just log for now - can be enhanced with custom popup later
	print("[RewardOrchestrator] REWARD: %s - %s" % [title, message])

	# Wait for duration
	await get_tree().create_timer(duration).timeout

## Find RewardNotification in scene tree
func _find_reward_notification() -> Node:
	"""Find the RewardNotification node in the scene tree"""

	# Try common locations
	var locations = [
		"/root/MainGame/GameUI/RewardNotification",
		"/root/GameUI/RewardNotification",
		"../GameUI/RewardNotification",
		"../../RewardNotification"
	]

	for location in locations:
		var node = get_node_or_null(location)
		if node:
			print("[RewardOrchestrator] Found RewardNotification at: ", location)
			return node

	# Try searching the tree
	var root = get_tree().root
	if root:
		var notification = _search_for_reward_notification(root)
		if notification:
			print("[RewardOrchestrator] Found RewardNotification via search")
			return notification

	print("[RewardOrchestrator] RewardNotification not found - using fallback logging")
	return null

## Recursively search for RewardNotification
func _search_for_reward_notification(node: Node) -> Node:
	"""Recursively search for RewardNotification node"""

	if node.name == "RewardNotification":
		return node

	for child in node.get_children():
		var result = _search_for_reward_notification(child)
		if result:
			return result

	return null

## Format booster name for display
func _format_booster_name(booster_type: String) -> String:
	"""Convert booster_type to nice display name"""

	match booster_type:
		"hammer": return "Hammer"
		"shuffle": return "Shuffle"
		"swap": return "Swap"
		"chain_reaction": return "Chain Reaction"
		"bomb_3x3": return "3x3 Bomb"
		"line_blast": return "Line Blast"
		"row_clear": return "Row Clear"
		"column_clear": return "Column Clear"
		"extra_moves": return "Extra Moves"
		"tile_squasher": return "Tile Squasher"
		_: return booster_type.capitalize()

## Clear the reward queue
func clear_queue():
	"""Clear all pending rewards"""
	reward_queue.clear()
	is_processing = false
	print("[RewardOrchestrator] Queue cleared")

## Check if a specific reward has been granted (to prevent duplicates)
func is_reward_granted(reward_id: String) -> bool:
	"""Check if a reward has already been granted"""

	# Check with ExperienceDirector state
	if ExperienceDirector and ExperienceDirector.state:
		return ExperienceDirector.state.is_reward_unlocked(reward_id)

	return false
