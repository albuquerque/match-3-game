extends Node

const _RewardContainer    = preload("res://meta/rewards/system/RewardContainer.gd")
const _RewardSummaryPanel = preload("res://meta/rewards/system/RewardSummaryPanel.gd")

func _config_loader():
	return load("res://meta/rewards/system/ContainerConfigLoader.gd")

func _selection_rules():
	return load("res://meta/rewards/system/ContainerSelectionRules.gd")

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


# Configuration
var profile: Dictionary = {}
var current_stage: Stage = Stage.INTRO
var stages_to_run: Array = []
var skip_mode: bool = false
var reduced_motion: bool = false

# Reward data
var rewards_data: Dictionary = {}
var level_number: int = 0
var score: int = 0
var stars: int = 0

# Animated reward container
var reward_container = null  # RewardContainer
var container_override: String = ""  # Optional: Override which container config to load

# Parent UI reference
var ui_parent: Control = null
var last_summary_overlay: Control = null

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

# NodeResolvers is a global autoload — no local declaration needed.

func _run_summary_stage():
	"""Show final summary with total rewards"""
	print("[RewardTransitionController] Showing summary")

	var container_config: Dictionary = {}

	# Priority 1: Manual override (highest priority)
	if container_override != "":
		print("[RewardTransitionController] Using manual override: %s" % container_override)
		container_config = _config_loader().load_container(container_override)
	else:
		var rule_container = _selection_rules().get_container_for_context(
			level_number,
			rewards_data.get("coins", 0),
			rewards_data.get("gems", 0),
			stars
		)

		if rule_container != "":
			print("[RewardTransitionController] Using rule-selected container: %s" % rule_container)
			container_config = _config_loader().load_container(rule_container)
		else:
			var theme_name = "modern"
			if ThemeManager and ThemeManager.has_method("get_theme_name"):
				theme_name = ThemeManager.get_theme_name()
			elif ThemeManager and "current_theme" in ThemeManager:
				theme_name = ThemeManager.current_theme
			print("[RewardTransitionController] No rules matched, using theme container for: %s" % theme_name)
			container_config = _config_loader().load_for_theme(theme_name)

	if not container_config.is_empty():
		print("[RewardTransitionController] Using container: %s" % container_config.get("container_id", "unknown"))
		_show_with_container(container_config)
	else:
		push_error("[RewardTransitionController] No container config found!")
		_on_stage_completed(Stage.SUMMARY)

func _show_with_container(config: Dictionary):
	"""Show rewards using animated container system"""
	# Create container
	if not reward_container:
		reward_container = _RewardContainer.new()
		reward_container.name = "RewardContainer"
		ui_parent.add_child(reward_container)

		# Center on screen
		var viewport_size = ui_parent.get_viewport_rect().size
		reward_container.position = viewport_size / 2

		# Setup with config
		reward_container.setup(config)

		# Set rewards
		reward_container.set_rewards(
			rewards_data.get("coins", 0),
			rewards_data.get("gems", 0),
			rewards_data.get("boosters", [])
		)

		# Connect signals
		reward_container.all_complete.connect(_on_container_complete)

		print("[RewardTransitionController] Reward container created and configured")

	# Play opening animation
	reward_container.play_opening_animation()

	# Wait for it to open, then reveal
	await reward_container.opening_complete
	await get_tree().create_timer(0.5).timeout
	reward_container.play_reveal_animation()

	# Wait for reveal to complete
	await reward_container.revealing_complete

	# Chest has done its job — free it before showing the summary so it
	# never sits behind (or overlaps) the CLAIM button.
	if reward_container and is_instance_valid(reward_container):
		reward_container.queue_free()
		reward_container = null

	# Show reward summary with Continue button
	_show_container_summary()

func _show_container_summary():
	"""Instantiate the RewardSummary scene and populate it with reward data."""
	var scene = load("res://scenes/ui/components/RewardSummary.tscn")
	if not scene:
		push_error("[RewardTransitionController] RewardSummary.tscn not found — falling back to stage complete")
		_on_stage_completed(Stage.SUMMARY)
		return

	var panel = scene.instantiate()
	if not panel or not panel.has_method("setup"):
		push_error("[RewardTransitionController] RewardSummary.tscn root is not a RewardSummaryPanel")
		_on_stage_completed(Stage.SUMMARY)
		return

	if ui_parent:
		ui_parent.add_child(panel)
	else:
		add_child(panel)

	last_summary_overlay = panel

	panel.setup(rewards_data)
	panel.continue_pressed.connect(_on_ui_continue_pressed)

	print("[RewardTransitionController] RewardSummary scene instantiated")


func _on_multiplier_chosen(multiplier: float, rewards_label: Label, base_coins: int, base_gems: int) -> void:
	"""Apply the chosen multiplier to the rewards and update the display."""
	print("[RewardTransitionController] Multiplier chosen: %.1f×" % multiplier)
	var final_coins = int(round(base_coins * multiplier))
	var final_gems  = int(round(base_gems  * multiplier))
	rewards_data["coins"] = final_coins
	rewards_data["gems"]  = final_gems
	# Update the already-visible rewards label
	if rewards_label and is_instance_valid(rewards_label):
		var text = ""
		if final_coins > 0: text += tr("UI_REWARDS_COINS") % final_coins + "\n"
		if final_gems  > 0: text += tr("UI_REWARDS_GEMS")  % final_gems  + "\n"
		if text == "": text = tr("UI_REWARDS_NONE")
		rewards_label.text = text.strip_edges()
	# Grant the multiplied rewards
	var rm = get_node_or_null("/root/RewardManager")
	if rm:
		if rm.has_method("add_coins") and final_coins > 0: rm.add_coins(final_coins)
		if rm.has_method("add_gems")  and final_gems  > 0: rm.add_gems(final_gems)

func _on_multiplier_ad_requested(mmg: Node) -> void:
	_on_no_ad_timer(mmg)

func _on_no_ad_timer(mmg: Node) -> void:
	if mmg and is_instance_valid(mmg):
		mmg.confirm_ad_watched()

func _on_admob_reward_for_multiplier(_type, _amount, mmg: Node) -> void:
	if mmg and is_instance_valid(mmg):
		mmg.confirm_ad_watched()

func _on_container_complete():
	await get_tree().create_timer(1.0).timeout
	_on_stage_completed(Stage.SUMMARY)

func _on_ui_continue_pressed():
	if last_summary_overlay and is_instance_valid(last_summary_overlay):
		last_summary_overlay.queue_free()
		last_summary_overlay = null
	_on_stage_completed(Stage.SUMMARY)

func _on_summary_bg_gui_input(_event):
	pass  # Input handling is now owned by RewardSummary.tscn

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

func _get_booster_icon(booster_type: String) -> String:
	"""Get emoji icon for booster type"""
	match booster_type:
		"hammer":
			return "🔨"
		"swap":
			return "🔄"
		"shuffle":
			return "🔀"
		"bomb":
			return "💣"
		"rainbow":
			return "🌈"
		"lightning":
			return "⚡"
		_:
			return "🎁"

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

	if reward_container and is_instance_valid(reward_container):
		reward_container.cleanup()
		reward_container.queue_free()
		reward_container = null

