extends "res://experience/pipeline/PipelineStep.gd"

## ShowRewardsStep
## Shows the level transition/rewards screen after level completion
## Handles level failure by delegating to ShowLevelFailureStep
## Uses animated reward system with data-driven container selection

var level_number: int = 0
var level_completed: bool = true  # true = success, false = failed
var score: int = 0
var stars: int = 0
var coins_earned: int = 0
var gems_earned: int = 0

var reward_controller = null

func _init(lvl_num: int = 0, completed: bool = true):
	super("show_rewards")
	level_number = lvl_num
	level_completed = completed

func execute(context) -> bool:
	print("[ShowRewardsStep] Showing rewards for level %d (completed: %s)" % [level_number, level_completed])

	# Check if level actually failed
	if context.get_result("level_failed", false):
		print("[ShowRewardsStep] Level failed - showing failure screen instead of rewards")
		# Show failure screen instead
		var failure_step = load("res://experience/pipeline/steps/ShowLevelFailureStep.gd").new(context.get_result("current_level", level_number))
		# Note: Don't manually set pipeline_context - execute() receives context as parameter
		var success = await failure_step.execute(context)

		# Check what the user chose
		if context.get_result("retry_level", false):
			print("[ShowRewardsStep] User chose RETRY - restarting flow at level %d" % level_number)
			# Restart the experience flow at the same level
			# This ensures the pipeline is active for the next attempt
			var level_to_retry = context.get_result("current_level", level_number)
			var _st3 := Engine.get_main_loop() as SceneTree
			var xd = _st3.root.get_node_or_null("/root/ExperienceDirector") if _st3 else null
			if xd and xd.has_method("start_flow_at_level"):
				xd.start_flow_at_level(level_to_retry)
			else:
				# Fallback: load directly if no ExperienceDirector
				if context.game_ui:
					context.game_ui._load_level_by_number(level_to_retry)
			return success
		elif context.get_result("return_to_map", false):
			print("[ShowRewardsStep] User chose EXIT TO MAP - returning to world map")
			# Return to world map
			if context.game_ui:
				context.game_ui._show_worldmap_fullscreen()
			return success

		return success

	# Set waiting flag
	context.waiting_for_completion = true
	context.completion_type = "rewards"

	# Get level data from context or LevelManager
	if level_number <= 0:
		level_number = context.get_result("current_level", 1)

	# Get score and rewards from context (populated by LoadLevelStep)
	score = context.get_result("score", 0)
	stars = context.get_result("stars", 0)
	coins_earned = context.get_result("coins_earned", 0)
	gems_earned = context.get_result("gems_earned", 0)
	level_completed = context.get_result("level_completed", true)

	print("[ShowRewardsStep] Score: %d, Stars: %d, Coins: %d, Gems: %d" % [score, stars, coins_earned, gems_earned])

	# Use new reward system
	return _show_reward_screen(context)


func _show_reward_screen(context) -> bool:
	"""Show the reward screen with animated containers"""

	# Get current theme
	var _st := Engine.get_main_loop() as SceneTree
	var _theme_mgr = _st.root.get_node_or_null("ThemeManager") if _st else null
	var theme_name: String = _theme_mgr.get_theme_name() if _theme_mgr and _theme_mgr.has_method("get_theme_name") else "modern"

	# Load reward profile via explicit path to avoid class_name cache dependency
	var _rpp = load("res://meta/rewards/system/RewardPresentationProfile.gd")
	var profile_id: String = _rpp.get_profile_for_theme(theme_name) if _rpp else "default_chest"
	var profile: Dictionary = _rpp.load_profile(profile_id) if _rpp else {}

	if profile.is_empty():
		# Fallback to built-in default so we never hard-fail here
		profile = {
			"profile_id": "default",
			"container_type": "CHEST",
			"open_method": "tap",
			"stages": ["spawn_container", "interaction", "reward_reveal", "summary"],
			"reward_reveal": {
				"spawn_pattern": "simple",
				"delay_between_rewards_ms": 200,
				"hud_fly_animation": true
			}
		}

	# Create reward data
	var reward_data = {
		"level_number": level_number,
		"score": score,
		"stars": stars,
		"coins": coins_earned,
		"gems": gems_earned,
		"success": level_completed,
		"shards_collected": GalleryManager.session_shards_collected if GalleryManager else 0,
		"items_unlocked": GalleryManager.session_items_unlocked.duplicate() if GalleryManager else []
	}

	# Create controller (dynamically to avoid parse-time class resolution)
	var controller_script_path = "res://meta/rewards/system/RewardTransitionController.gd"
	if ResourceLoader.exists(controller_script_path):
		var controller_scr = load(controller_script_path)
		if controller_scr and controller_scr is Script and controller_scr.has_method("new"):
			reward_controller = controller_scr.new()
		else:
			push_error("[ShowRewardsStep] Failed to instantiate RewardTransitionController from %s" % controller_script_path)
			return false
	else:
		push_error("[ShowRewardsStep] RewardTransitionController script not found: %s" % controller_script_path)
		return false

	# Get parent UI
	var ui_parent = context.game_ui if context.game_ui else null
	if not ui_parent:
		push_error("[ShowRewardsStep] No UI parent available")
		return false

	# Freeze board input and hide the board so the reward screen is the only thing visible.
	GameRunState.level_transitioning = true
	var board = GameRunState.board_ref
	if board and is_instance_valid(board):
		board.visible = false

	# Add controller to scene tree
	ui_parent.add_child(reward_controller)

	# Setup controller
	reward_controller.setup(profile, reward_data, ui_parent)


	# Container selection is data-driven via container_selection_rules.json
	# To force a specific container: reward_controller.container_override = "container_id"

	# Connect signals
	if not reward_controller.transition_completed.is_connected(_on_reward_completed):
		reward_controller.transition_completed.connect(_on_reward_completed)

	# Start the reward sequence
	reward_controller.start()

	print("[ShowRewardsStep] Reward system started with profile: %s" % profile_id)
	return true

func _on_reward_completed():
	"""Reward system completed - user clicked Continue"""
	print("[ShowRewardsStep] Reward system completed")

	# Signal completion with success
	step_completed.emit(true)

func cleanup():
	"""Disconnect signals and clean up"""
	if reward_controller and is_instance_valid(reward_controller):
		if reward_controller.transition_completed.is_connected(_on_reward_completed):
			reward_controller.transition_completed.disconnect(_on_reward_completed)
		reward_controller.queue_free()
		reward_controller = null
	# Restore board — the next pipeline step (LoadLevelStep) will re-populate it.
	# level_transitioning stays true until LoadLevelStep resets it on level load.
	var board = GameRunState.board_ref
	if board and is_instance_valid(board):
		board.visible = true
