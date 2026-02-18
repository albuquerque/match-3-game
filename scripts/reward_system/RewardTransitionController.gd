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
var reward_container: RewardContainer = null
var container_override: String = ""  # Optional: Override which container config to load

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


func _run_summary_stage():
	"""Show final summary with total rewards"""
	print("[RewardTransitionController] Showing summary")

	var container_config: Dictionary = {}

	# Priority 1: Manual override (highest priority)
	if container_override != "":
		print("[RewardTransitionController] Using manual override: %s" % container_override)
		container_config = ContainerConfigLoader.load_container(container_override)
	else:
		# Priority 2: Data-driven rules evaluation
		var rule_container = ContainerSelectionRules.get_container_for_context(
			level_number,
			rewards_data.get("coins", 0),
			rewards_data.get("gems", 0),
			stars
		)

		if rule_container != "":
			print("[RewardTransitionController] Using rule-selected container: %s" % rule_container)
			container_config = ContainerConfigLoader.load_container(rule_container)
		else:
			# Priority 3: Theme-based selection (fallback)
			var theme_name = ThemeManager.get_theme_name() if ThemeManager else "modern"
			print("[RewardTransitionController] No rules matched, using theme container for: %s" % theme_name)
			container_config = ContainerConfigLoader.load_for_theme(theme_name)

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
		reward_container = RewardContainer.new()
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

	# Show reward summary with Continue button
	_show_container_summary()

func _show_container_summary():
	"""Show reward amounts and Continue button after container animation"""
	# Create summary overlay with high z-index to ensure visibility
	var summary_overlay = Control.new()
	summary_overlay.name = "ContainerSummaryOverlay"
	summary_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_overlay.z_index = 1000  # Very high to be on top
	summary_overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to elements below
	ui_parent.add_child(summary_overlay)

	# Create semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)  # Darker so it's visible
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	summary_overlay.add_child(bg)

	# Create summary panel (centered)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 400)
	panel.z_index = 1001
	# Center it properly
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250  # Half of width
	panel.offset_top = -200   # Half of height
	panel.offset_right = 250
	panel.offset_bottom = 200
	summary_overlay.add_child(panel)

	# Add a visible background to the panel
	var panel_bg = panel.get_theme_stylebox("panel", "PanelContainer")
	if not panel_bg:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.3, 0.95)
		style.border_width_left = 3
		style.border_width_right = 3
		style.border_width_top = 3
		style.border_width_bottom = 3
		style.border_color = Color(0.8, 0.7, 0.3, 1.0)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		panel.add_theme_stylebox_override("panel", style)

	# Add content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	# Add some padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(top_spacer)

	# Title
	var title = Label.new()
	title.text = tr("UI_LEVEL_COMPLETE")
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Rewards section
	var rewards_title = Label.new()
	rewards_title.text = tr("UI_REWARDS_EARNED")
	rewards_title.add_theme_font_size_override("font_size", 24)
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rewards_title)

	# Rewards list - show all reward types
	var coins = rewards_data.get("coins", 0)
	var gems = rewards_data.get("gems", 0)
	var boosters = rewards_data.get("boosters", {})
	var gallery_images = rewards_data.get("gallery_images", [])
	var cards = rewards_data.get("cards", [])
	var themes = rewards_data.get("themes", [])
	var videos = rewards_data.get("videos", [])

	# Coins
	if coins > 0:
		var coins_label = Label.new()
		coins_label.text = tr("UI_REWARDS_COINS") % coins
		coins_label.add_theme_font_size_override("font_size", 28)
		coins_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(coins_label)

	# Gems
	if gems > 0:
		var gems_label = Label.new()
		gems_label.text = tr("UI_REWARDS_GEMS") % gems
		gems_label.add_theme_font_size_override("font_size", 28)
		gems_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1.0))
		gems_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gems_label)

	# Boosters
	if not boosters.is_empty():
		for booster_type in boosters.keys():
			var booster_count = boosters[booster_type]
			if booster_count > 0:
				var booster_label = Label.new()
				var booster_icon = _get_booster_icon(booster_type)
				booster_label.text = tr("UI_BOOSTER_PREFIX") % [booster_icon, booster_type.capitalize(), booster_count]
				booster_label.add_theme_font_size_override("font_size", 24)
				booster_label.add_theme_color_override("font_color", Color(0.9, 0.5, 1.0, 1.0))
				booster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(booster_label)

	# Gallery Images
	if not gallery_images.is_empty():
		var gallery_label = Label.new()
		gallery_label.text = tr("UI_GALLERY_IMAGES_UNLOCKED") % gallery_images.size()
		gallery_label.add_theme_font_size_override("font_size", 24)
		gallery_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4, 1.0))
		gallery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(gallery_label)

		# Show individual image names if not too many
		if gallery_images.size() <= 3:
			for image_name in gallery_images:
				var img_label = Label.new()
				img_label.text = "  • %s" % image_name
				img_label.add_theme_font_size_override("font_size", 18)
				img_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(img_label)

	# Collection Cards
	if not cards.is_empty():
		var card_label = Label.new()
		card_label.text = tr("UI_CARDS_UNLOCKED") % cards.size()
		card_label.add_theme_font_size_override("font_size", 24)
		card_label.add_theme_color_override("font_color", Color(0.4, 0.9, 0.7, 1.0))
		card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(card_label)

		# Show individual card names if not too many
		if cards.size() <= 3:
			for card in cards:
				var card_name = card.get("card_name", card.get("card_id", "Unknown"))
				var card_item_label = Label.new()
				card_item_label.text = "  • %s" % card_name
				card_item_label.add_theme_font_size_override("font_size", 18)
				card_item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vbox.add_child(card_item_label)

	# Themes
	if not themes.is_empty():
		var theme_label = Label.new()
		theme_label.text = tr("UI_THEMES_UNLOCKED") % themes.size()
		theme_label.add_theme_font_size_override("font_size", 24)
		theme_label.add_theme_color_override("font_color", Color(0.9, 0.4, 0.9, 1.0))
		theme_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(theme_label)

	# Videos
	if not videos.is_empty():
		var video_label = Label.new()
		video_label.text = tr("UI_VIDEOS_UNLOCKED") % videos.size()
		video_label.add_theme_font_size_override("font_size", 24)
		video_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5, 1.0))
		video_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(video_label)

	# Score
	var score_label = Label.new()
	score_label.text = tr("UI_LABEL_SCORE") + ": %d" % score
	score_label.add_theme_font_size_override("font_size", 22)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(score_label)

	# Stars
	var stars_label = Label.new()
	var stars_text = ""
	for i in range(stars):
		stars_text += "⭐"
	stars_label.text = stars_text if stars > 0 else "☆☆☆"
	stars_label.add_theme_font_size_override("font_size", 32)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stars_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer)

	# Continue button
	var continue_btn = Button.new()
	continue_btn.text = tr("UI_CONTINUE")
	continue_btn.custom_minimum_size = Vector2(250, 70)
	continue_btn.add_theme_font_size_override("font_size", 28)

	# Style the button
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.2, 0.7, 0.3, 1.0)
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	continue_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.3, 0.8, 0.4, 1.0)
	btn_hover.corner_radius_top_left = 8
	btn_hover.corner_radius_top_right = 8
	btn_hover.corner_radius_bottom_left = 8
	btn_hover.corner_radius_bottom_right = 8
	continue_btn.add_theme_stylebox_override("hover", btn_hover)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(continue_btn)
	vbox.add_child(hbox)

	# Bottom spacer
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_spacer)

	# Connect button
	continue_btn.pressed.connect(func():
		print("[RewardTransitionController] Continue button pressed")
		# Cleanup summary
		if is_instance_valid(summary_overlay):
			summary_overlay.queue_free()
		# Advance to next stage
		_on_ui_continue_pressed()
	)

	# Also make background clickable
	bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			print("[RewardTransitionController] Background clicked, advancing")
			if is_instance_valid(summary_overlay):
				summary_overlay.queue_free()
			_on_ui_continue_pressed()
	)

	print("[RewardTransitionController] Container summary displayed with Continue button")
	print("[RewardTransitionController] Summary overlay z_index: %d, visible: %s" % [summary_overlay.z_index, summary_overlay.visible])


func _on_container_complete():
	"""Handle container completion"""
	print("[RewardTransitionController] Container animation complete")
	# For now, auto-advance (TODO: wait for Continue button)
	await get_tree().create_timer(1.0).timeout
	_on_stage_completed(Stage.SUMMARY)

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

