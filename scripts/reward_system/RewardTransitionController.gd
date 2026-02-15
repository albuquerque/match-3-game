extends Node
class_name RewardTransitionController

## RewardTransitionController
## Manages the complete reward reveal experience with stages and animations
## Orchestrates: Intro → Container Spawn → Interaction → Reveal → Summary → Exit

signal stage_started(stage_name: String)
signal stage_completed(stage_name: String)
signal transition_completed
signal skip_requested
signal container_opened
signal reward_revealed(reward_type: String, amount: int)

enum Stage {
	INTRO,
	SPAWN_CONTAINER,
	INTERACTION,
	REWARD_REVEAL,
	SUMMARY,
	EXIT
}

enum ContainerType {
	CHEST,
	SCROLL,
	TREASURE_PILE,
	DIVINE_LIGHT,
	MYSTERY_BOX,
	CARD_PACK
}

enum InteractionMode {
	TAP,
	HOLD_TO_OPEN,
	DRAG_TO_OPEN,
	AUTO_OPEN,
	MULTI_TAP_BREAK
}

# Configuration
var profile: Dictionary = {}
var current_stage: Stage = Stage.INTRO
var stages_to_run: Array = []
var skip_mode: bool = false
var reduced_motion: bool = false

# Stage references
var intro_stage: Node = null
var container_spawn_stage: Node = null
var interaction_stage: Node = null
var reward_reveal_stage: Node = null
var summary_stage: Node = null
var exit_stage: Node = null

# Reward data
var rewards_data: Dictionary = {}
var level_number: int = 0
var score: int = 0
var stars: int = 0

# Container instance
var container_instance: Node = null

# Simple UI for Phase 2
var simple_ui: Control = null

# Parent UI reference
var ui_parent: Control = null

func _init():
	name = "RewardTransitionController"

func setup(config: Dictionary, reward_data: Dictionary, parent: Control):
	"""Initialize the controller with configuration and reward data"""
	profile = config
	rewards_data = reward_data
	ui_parent = parent

	# Extract level data
	level_number = reward_data.get("level_number", 0)
	score = reward_data.get("score", 0)
	stars = reward_data.get("stars", 0)

	# Parse stages to run
	var stage_names = profile.get("stages", ["intro", "spawn_container", "interaction", "reward_reveal", "summary"])
	stages_to_run = _parse_stage_names(stage_names)

	# Check for reduced motion preference
	reduced_motion = _check_reduced_motion_setting()

	print("[RewardTransitionController] Setup complete. Level %d, Score: %d, Stars: %d" % [level_number, score, stars])
	print("[RewardTransitionController] Stages to run: ", stage_names)

func start():
	"""Begin the reward transition sequence"""
	print("[RewardTransitionController] Starting reward transition")
	current_stage = Stage.INTRO
	_run_current_stage()

func skip():
	"""Skip animations and fast-forward to summary"""
	print("[RewardTransitionController] Skip requested")
	skip_mode = true
	skip_requested.emit()
	_fast_forward_to_summary()

func _run_current_stage():
	"""Execute the current stage"""
	var stage_index = stages_to_run.find(current_stage)
	if stage_index == -1:
		# Stage not in run list, move to next
		_advance_stage()
		return

	var stage_name = _get_stage_name(current_stage)
	print("[RewardTransitionController] Running stage: ", stage_name)
	stage_started.emit(stage_name)

	match current_stage:
		Stage.INTRO:
			# Skip intro - go straight to next
			_on_stage_completed(Stage.INTRO)
		Stage.SPAWN_CONTAINER:
			# Skip spawn - go straight to next
			_on_stage_completed(Stage.SPAWN_CONTAINER)
		Stage.INTERACTION:
			# Skip interaction - go straight to next
			_on_stage_completed(Stage.INTERACTION)
		Stage.REWARD_REVEAL:
			# Skip reveal - go straight to next (rewards already in context)
			_on_stage_completed(Stage.REWARD_REVEAL)
		Stage.SUMMARY:
			_run_summary_stage()
		Stage.EXIT:
			_run_exit_stage()

func _run_intro_stage():
	"""Play intro animation (camera zoom, banner slide, etc.)"""
	print("[RewardTransitionController] Intro stage: Level %d Complete!" % level_number)

	# Emit analytics event
	_emit_analytics("intro_started", {"level": level_number})

	# TODO: Add intro animation (camera zoom, banner)
	# For now, just delay
	var duration = 1.0 if not skip_mode else 0.1
	await get_tree().create_timer(duration).timeout

	_on_stage_completed(Stage.INTRO)

func _run_spawn_container_stage():
	"""Spawn and animate the reward container (chest, scroll, etc.)"""
	print("[RewardTransitionController] Spawning container")

	var container_type = profile.get("container_type", "CHEST")

	# TODO: Instantiate actual container
	# For now, placeholder
	print("[RewardTransitionController] Container type: ", container_type)

	# Emit analytics
	_emit_analytics("container_spawned", {"type": container_type})

	var duration = 0.8 if not skip_mode else 0.1
	await get_tree().create_timer(duration).timeout

	_on_stage_completed(Stage.SPAWN_CONTAINER)

func _run_interaction_stage():
	"""Wait for player interaction to open container"""
	print("[RewardTransitionController] Waiting for interaction")

	var interaction_mode = profile.get("open_method", "tap")

	# TODO: Implement actual interaction
	# For now, auto-open after delay
	print("[RewardTransitionController] Interaction mode: ", interaction_mode)

	if interaction_mode == "auto_open" or skip_mode:
		var duration = 0.5 if not skip_mode else 0.0
		await get_tree().create_timer(duration).timeout
		_on_container_opened()
	else:
		# TODO: Set up tap/hold/drag handlers
		# For now, auto-open after 1 second
		await get_tree().create_timer(1.0).timeout
		_on_container_opened()

func _on_container_opened():
	"""Handle container being opened"""
	print("[RewardTransitionController] Container opened!")
	container_opened.emit()
	_emit_analytics("container_opened", {})
	_on_stage_completed(Stage.INTERACTION)

func _run_reward_reveal_stage():
	"""Animate rewards flying out and revealing"""
	print("[RewardTransitionController] Revealing rewards")

	var reveal_config = profile.get("reward_reveal", {})
	var spawn_pattern = reveal_config.get("spawn_pattern", "arc")
	var delay_ms = reveal_config.get("delay_between_rewards_ms", 250)

	# Get rewards from rewards_data
	var coins = rewards_data.get("coins", 0)
	var gems = rewards_data.get("gems", 0)

	print("[RewardTransitionController] Coins: %d, Gems: %d" % [coins, gems])
	print("[RewardTransitionController] Spawn pattern: %s, Delay: %dms" % [spawn_pattern, delay_ms])

	# TODO: Implement actual reward animations
	# For now, emit signals for each reward
	if coins > 0:
		reward_revealed.emit("coins", coins)
		_emit_analytics("reward_revealed", {"type": "coins", "amount": coins})
		if not skip_mode:
			await get_tree().create_timer(delay_ms / 1000.0).timeout

	if gems > 0:
		reward_revealed.emit("gems", gems)
		_emit_analytics("reward_revealed", {"type": "gems", "amount": gems})
		if not skip_mode:
			await get_tree().create_timer(delay_ms / 1000.0).timeout

	# Check for rare rewards
	if gems >= 20:
		_emit_analytics("rare_reward_revealed", {"type": "gems", "amount": gems})

	_on_stage_completed(Stage.REWARD_REVEAL)

func _run_summary_stage():
	"""Show final summary with total rewards"""
	print("[RewardTransitionController] Showing summary")

	# Create and show simple UI
	if not simple_ui:
		simple_ui = preload("res://scripts/reward_system/SimpleRewardUI.gd").new()
		simple_ui.name = "SimpleRewardUI"
		ui_parent.add_child(simple_ui)

		# Connect continue button
		if not simple_ui.continue_pressed.is_connected(_on_ui_continue_pressed):
			simple_ui.continue_pressed.connect(_on_ui_continue_pressed)

		print("[RewardTransitionController] Created SimpleRewardUI")

	# Show the UI with reward data
	var ui_data = {
		"level_number": level_number,
		"score": score,
		"stars": stars,
		"coins": rewards_data.get("coins", 0),
		"gems": rewards_data.get("gems", 0)
	}
	simple_ui.show_rewards(ui_data)

	# Don't auto-advance - wait for user to click Continue
	print("[RewardTransitionController] Waiting for user to click Continue...")

func _on_ui_continue_pressed():
	"""Handle Continue button from SimpleRewardUI"""
	print("[RewardTransitionController] User clicked Continue")
	_on_stage_completed(Stage.SUMMARY)

func _run_exit_stage():
	"""Clean up and signal completion"""
	print("[RewardTransitionController] Exiting reward transition")

	_emit_analytics("reward_sequence_completed", {
		"level": level_number,
		"skipped": skip_mode,
		"total_coins": rewards_data.get("coins", 0),
		"total_gems": rewards_data.get("gems", 0)
	})

	transition_completed.emit()

	# Clean up
	_cleanup()

func _on_stage_completed(stage: Stage):
	"""Handle stage completion and advance"""
	var stage_name = _get_stage_name(stage)
	print("[RewardTransitionController] Stage completed: ", stage_name)
	stage_completed.emit(stage_name)

	_advance_stage()

func _advance_stage():
	"""Move to the next stage"""
	var next_stage_value = current_stage + 1

	if next_stage_value > Stage.EXIT:
		# All stages complete
		_run_exit_stage()
		return

	current_stage = next_stage_value as Stage
	_run_current_stage()

func _fast_forward_to_summary():
	"""Skip directly to summary stage"""
	current_stage = Stage.SUMMARY

	# Emit all rewards instantly
	var coins = rewards_data.get("coins", 0)
	var gems = rewards_data.get("gems", 0)

	if coins > 0:
		reward_revealed.emit("coins", coins)
	if gems > 0:
		reward_revealed.emit("gems", gems)

	_emit_analytics("reward_sequence_skipped", {"at_stage": _get_stage_name(current_stage)})

	_run_summary_stage()

func _parse_stage_names(stage_names: Array) -> Array:
	"""Convert stage name strings to Stage enum values"""
	var stages = []
	for name in stage_names:
		match name:
			"intro":
				stages.append(Stage.INTRO)
			"spawn_container":
				stages.append(Stage.SPAWN_CONTAINER)
			"interaction":
				stages.append(Stage.INTERACTION)
			"reward_reveal":
				stages.append(Stage.REWARD_REVEAL)
			"summary":
				stages.append(Stage.SUMMARY)
			"exit":
				stages.append(Stage.EXIT)
	return stages

func _get_stage_name(stage: Stage) -> String:
	"""Get string name for stage enum"""
	match stage:
		Stage.INTRO:
			return "intro"
		Stage.SPAWN_CONTAINER:
			return "spawn_container"
		Stage.INTERACTION:
			return "interaction"
		Stage.REWARD_REVEAL:
			return "reward_reveal"
		Stage.SUMMARY:
			return "summary"
		Stage.EXIT:
			return "exit"
	return "unknown"

func _check_reduced_motion_setting() -> bool:
	"""Check if reduced motion is enabled in settings"""
	# TODO: Check actual setting from game settings
	return false

func _emit_analytics(event_name: String, data: Dictionary):
	"""Emit analytics event"""
	print("[RewardTransitionController] Analytics: %s - %s" % [event_name, data])
	# TODO: Send to actual analytics system

func _cleanup():
	"""Clean up resources"""
	if container_instance and is_instance_valid(container_instance):
		container_instance.queue_free()
		container_instance = null

	if simple_ui and is_instance_valid(simple_ui):
		simple_ui.queue_free()
		simple_ui = null
