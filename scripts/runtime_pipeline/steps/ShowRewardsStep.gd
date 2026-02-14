extends PipelineStep
class_name ShowRewardsStep

## ShowRewardsStep
## Shows the level transition/rewards screen after level completion
## Waits for user to press Continue or Replay

var level_number: int = 0
var level_completed: bool = true  # true = success, false = failed
var score: int = 0
var stars: int = 0
var coins_earned: int = 0
var gems_earned: int = 0
var replay_available: bool = true

var transition_screen: Control = null
var _continue_pressed: bool = false
var _replay_pressed: bool = false

func _init(lvl_num: int = 0, completed: bool = true):
	super("show_rewards")
	level_number = lvl_num
	level_completed = completed

func execute(context: PipelineContext) -> bool:
	print("[ShowRewardsStep] Showing rewards for level %d (completed: %s)" % [level_number, level_completed])

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

	# Create or get the LevelTransition screen
	if not _get_or_create_transition_screen(context):
		push_error("[ShowRewardsStep] Failed to create transition screen")
		return false

	# Configure the transition screen
	if transition_screen.has_method("show_transition"):
		var transition_data = {
			"level_number": level_number,
			"score": score,
			"stars": stars,
			"coins": coins_earned,
			"gems": gems_earned,
			"success": level_completed,
			"show_replay": replay_available
		}

		print("[ShowRewardsStep] Calling show_transition with data: ", transition_data)
		transition_screen.show_transition(transition_data)
	else:
		push_error("[ShowRewardsStep] LevelTransition doesn't have show_transition method")
		return false

	# Connect to transition screen signals
	if not transition_screen.continue_pressed.is_connected(_on_continue_pressed):
		transition_screen.continue_pressed.connect(_on_continue_pressed)

	# Check if replay signal exists (it might not on older versions)
	if transition_screen.has_signal("replay_pressed"):
		if not transition_screen.is_connected("replay_pressed", Callable(self, "_on_replay_pressed")):
			transition_screen.connect("replay_pressed", Callable(self, "_on_replay_pressed"))

	return true

func _get_or_create_transition_screen(context: PipelineContext) -> bool:
	"""Get existing LevelTransition or create a new one"""

	# Try to find existing LevelTransition in GameUI
	if context.game_ui:
		transition_screen = context.game_ui.get_node_or_null("LevelTransition")

		if transition_screen and is_instance_valid(transition_screen):
			print("[ShowRewardsStep] Found existing LevelTransition")
			return true

	# Try to load from scene
	var scene_path = "res://scenes/LevelTransitionScene.tscn"
	if ResourceLoader.exists(scene_path):
		var packed = load(scene_path)
		if packed and packed is PackedScene:
			transition_screen = packed.instantiate()
			transition_screen.name = "LevelTransition"
			if context.game_ui:
				context.game_ui.add_child(transition_screen)
			print("[ShowRewardsStep] Created LevelTransition from scene")
			return true

	# Fallback: Create from script
	var script_path = "res://scripts/LevelTransition.gd"
	if ResourceLoader.exists(script_path):
		var script = load(script_path)
		if script:
			transition_screen = Control.new()
			transition_screen.set_script(script)
			transition_screen.name = "LevelTransition"
			if context.game_ui:
				context.game_ui.add_child(transition_screen)
			print("[ShowRewardsStep] Created LevelTransition from script")
			return true

	push_error("[ShowRewardsStep] Could not create LevelTransition - no scene or script found")
	return false

func _on_continue_pressed():
	"""User pressed Continue button"""
	print("[ShowRewardsStep] Continue pressed")
	_continue_pressed = true

	# Hide the transition screen
	if transition_screen and is_instance_valid(transition_screen):
		if transition_screen.has_method("hide_transition"):
			transition_screen.hide_transition()
		else:
			transition_screen.visible = false

	# Signal completion with success
	step_completed.emit(true)

func _on_replay_pressed():
	"""User pressed Replay button"""
	print("[ShowRewardsStep] Replay pressed")
	_replay_pressed = true

	# Hide the transition screen
	if transition_screen and is_instance_valid(transition_screen):
		if transition_screen.has_method("hide_transition"):
			transition_screen.hide_transition()
		else:
			transition_screen.visible = false

	# Signal completion but with a flag for replay
	# The pipeline/flow coordinator can check context for replay intent
	step_completed.emit(false)  # false = user wants to replay, not continue

func cleanup():
	"""Disconnect signals and clean up"""
	if transition_screen and is_instance_valid(transition_screen):
		if transition_screen.continue_pressed.is_connected(_on_continue_pressed):
			transition_screen.continue_pressed.disconnect(_on_continue_pressed)

		if transition_screen.has_signal("replay_pressed"):
			if transition_screen.is_connected("replay_pressed", Callable(self, "_on_replay_pressed")):
				transition_screen.disconnect("replay_pressed", Callable(self, "_on_replay_pressed"))

		# Don't free the transition screen - it might be reused
		# Just hide it
		if transition_screen.visible:
			transition_screen.visible = false
