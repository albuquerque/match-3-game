extends Control

signal continue_pressed
signal rewards_claimed

var background: ColorRect
var content_container: VBoxContainer
var title_label: Label
var score_label: Label
var rewards_container: VBoxContainer
var multiplier_container: VBoxContainer
var multiplier_bar_bg: ColorRect
var multiplier_pointer: ColorRect
var multiplier_zones: Array = []
var zone_labels: Array = []
var tap_instruction_label: Label
var ad_trigger_button: Button
var continue_button: Button

var level_data = {}
var _base_coins = 0
var _base_gems = 0
var _reward_multiplied = false
var _multiplier_active = false
var _pointer_position = 0.0
var _pointer_direction = 1.0
var _pointer_speed = 200.0  # pixels per second
var _selected_multiplier = 1.0
var bangers_font  # Bangers font resource for consistent styling

# Multiplier zone configuration [start%, end%, multiplier, color]
var _multiplier_config = [
	[0.0, 0.15, 1.0, Color(0.5, 0.5, 0.5, 1.0)],      # Gray - 1x
	[0.15, 0.30, 1.5, Color(0.4, 0.7, 0.4, 1.0)],     # Green - 1.5x
	[0.30, 0.45, 2.0, Color(0.3, 0.5, 0.8, 1.0)],     # Blue - 2x
	[0.45, 0.55, 3.0, Color(0.7, 0.4, 0.9, 1.0)],     # Purple - 3x (center)
	[0.55, 0.70, 2.0, Color(0.3, 0.5, 0.8, 1.0)],     # Blue - 2x
	[0.70, 0.85, 1.5, Color(0.4, 0.7, 0.4, 1.0)],     # Green - 1.5x
	[0.85, 1.0, 1.0, Color(0.5, 0.5, 0.5, 1.0)],      # Gray - 1x
]

func _ready():
	# Create fullscreen opaque background
	background = ColorRect.new()
	background.name = "Background"
	background.color = Color(0.05, 0.05, 0.1, 1.0)  # Dark opaque background
	background.anchor_left = 0
	background.anchor_top = 0
	background.anchor_right = 1
	background.anchor_bottom = 1
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(background)

	# Create content container
	content_container = VBoxContainer.new()
	content_container.name = "ContentContainer"
	content_container.anchor_left = 0.1
	content_container.anchor_top = 0.2
	content_container.anchor_right = 0.9
	content_container.anchor_bottom = 0.8
	content_container.add_theme_constant_override("separation", 20)
	add_child(content_container)

	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "🎉 Level Complete! 🎉"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Apply Bangers font for impactful display
	bangers_font = load("res://fonts/Bangers/Bangers-Regular.ttf")
	ThemeManager.apply_bangers_font(title_label, 48)
	title_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))  # Gold color
	content_container.add_child(title_label)

	# Star rating container (will be populated dynamically)
	var star_container = HBoxContainer.new()
	star_container.name = "StarContainer"
	star_container.alignment = BoxContainer.ALIGNMENT_CENTER
	star_container.add_theme_constant_override("separation", 15)
	content_container.add_child(star_container)

	# Score label
	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(score_label, 32)
	content_container.add_child(score_label)

	# Rewards container
	rewards_container = VBoxContainer.new()
	rewards_container.name = "RewardsContainer"
	rewards_container.add_theme_constant_override("separation", 10)
	content_container.add_child(rewards_container)

	var rewards_title = Label.new()
	rewards_title.text = "Rewards Earned:"
	rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(rewards_title, 28)
	rewards_container.add_child(rewards_title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	content_container.add_child(spacer)

	# Create multiplier mini-game container
	_create_multiplier_ui()

	# Button container for horizontal layout
	var button_container = HBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 20)
	content_container.add_child(button_container)

	# Replay button
	var replay_button = Button.new()
	replay_button.name = "ReplayButton"
	replay_button.text = "🔄 REPLAY"
	ThemeManager.apply_bangers_font_to_button(replay_button, 22)
	replay_button.custom_minimum_size = Vector2(200, 80)
	replay_button.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))  # Cyan
	replay_button.pressed.connect(_on_replay_pressed)
	button_container.add_child(replay_button)

	# Continue button
	continue_button = Button.new()
	continue_button.name = "ContinueButton"
	continue_button.text = "▶ NEXT LEVEL"
	ThemeManager.apply_bangers_font_to_button(continue_button, 22)
	continue_button.custom_minimum_size = Vector2(200, 80)
	continue_button.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
	continue_button.pressed.connect(_on_continue_pressed)
	button_container.add_child(continue_button)

	# Set fullscreen
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Connect to AdMobManager signals if available
	_connect_admob_signals()

func _create_multiplier_ui():
	"""Create the interactive multiplier mini-game UI"""
	multiplier_container = VBoxContainer.new()
	multiplier_container.name = "MultiplierContainer"
	multiplier_container.add_theme_constant_override("separation", 15)
	content_container.add_child(multiplier_container)

	# Title for multiplier game
	var multiplier_title = Label.new()
	multiplier_title.text = "🎯 Multiplier Challenge!"
	multiplier_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(multiplier_title, 24)
	multiplier_title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	multiplier_container.add_child(multiplier_title)

	# Ad trigger button
	ad_trigger_button = Button.new()
	ad_trigger_button.name = "AdTriggerButton"
	ad_trigger_button.text = "🎯 Start Multiplier Challenge!"
	ad_trigger_button.custom_minimum_size = Vector2(300, 60)
	ThemeManager.apply_bangers_font_to_button(ad_trigger_button, 20)
	ad_trigger_button.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
	ad_trigger_button.pressed.connect(_on_ad_trigger_pressed)
	multiplier_container.add_child(ad_trigger_button)

	# Container for the bar (visible from start so user can see what they're playing for)
	var bar_container = Control.new()
	bar_container.name = "BarContainer"
	bar_container.custom_minimum_size = Vector2(500, 120)
	bar_container.visible = true  # Changed to true - show bar immediately
	multiplier_container.add_child(bar_container)

	# Background for multiplier bar
	multiplier_bar_bg = ColorRect.new()
	multiplier_bar_bg.name = "MultiplierBarBg"
	multiplier_bar_bg.color = Color(0.2, 0.2, 0.2, 1.0)
	multiplier_bar_bg.position = Vector2(10, 10)
	multiplier_bar_bg.size = Vector2(480, 60)
	bar_container.add_child(multiplier_bar_bg)

	# Create multiplier zones
	var bar_width = 480.0
	for zone_data in _multiplier_config:
		var zone_rect = ColorRect.new()
		zone_rect.color = zone_data[3]  # Color from config
		zone_rect.position = Vector2(10 + bar_width * zone_data[0], 10)
		zone_rect.size = Vector2(bar_width * (zone_data[1] - zone_data[0]), 60)
		bar_container.add_child(zone_rect)
		multiplier_zones.append(zone_rect)

		# Add label showing multiplier
		var zone_label = Label.new()
		zone_label.text = "%.1fx" % zone_data[2]
		zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		zone_label.position = zone_rect.position
		zone_label.size = zone_rect.size
		ThemeManager.apply_bangers_font(zone_label, 16)
		zone_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		bar_container.add_child(zone_label)
		zone_labels.append(zone_label)

	# Moving pointer
	multiplier_pointer = ColorRect.new()
	multiplier_pointer.name = "MultiplierPointer"
	multiplier_pointer.color = Color(1.0, 1.0, 0.0, 0.9)  # Yellow
	multiplier_pointer.position = Vector2(10, 10)
	multiplier_pointer.size = Vector2(8, 60)
	bar_container.add_child(multiplier_pointer)

	# Tap instruction
	tap_instruction_label = Label.new()
	tap_instruction_label.name = "TapInstruction"
	tap_instruction_label.text = "TAP TO STOP AND WATCH AD!"
	tap_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(tap_instruction_label, 20)
	tap_instruction_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))  # Red
	tap_instruction_label.visible = false  # Hidden until game starts
	multiplier_container.add_child(tap_instruction_label)

func _process(delta):
	"""Update multiplier pointer position if mini-game is active"""
	if not _multiplier_active:
		return

	# Move pointer back and forth
	var bar_width = 480.0
	_pointer_position += _pointer_speed * _pointer_direction * delta

	# Bounce at edges
	if _pointer_position >= bar_width:
		_pointer_position = bar_width
		_pointer_direction = -1.0
	elif _pointer_position <= 0:
		_pointer_position = 0
		_pointer_direction = 1.0

	# Update pointer visual position
	if multiplier_pointer:
		multiplier_pointer.position.x = 10 + _pointer_position

func _input(event):
	"""Handle tap to stop the pointer"""
	if not _multiplier_active:
		return

	if event is InputEventScreenTouch and event.pressed:
		_on_multiplier_tapped()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_multiplier_tapped()

func show_transition(completed_level: int, final_score: int, coins_earned: int, gems_earned: int, has_next_level: bool = true, stars: int = 1):
	"""Show the level transition screen with rewards and star rating"""
	print("=".repeat(60))
	print("[LevelTransition] 🎆 show_transition() CALLED 🎆")
	print("=".repeat(60))
	print("[LevelTransition] Showing transition for level ", completed_level)
	print("[LevelTransition] Score: ", final_score, ", Coins: ", coins_earned, ", Gems: ", gems_earned)
	print("[LevelTransition] Stars earned: ", stars, "/3")
	print("[LevelTransition] Has next level: ", has_next_level)
	print("[LevelTransition] Current visibility BEFORE: ", visible)
	print("[LevelTransition] Current z_index: ", z_index)

	# Ensure AdMob signals are connected (safe to call multiple times)
	_connect_admob_signals()

	# Store base rewards for potential multiplication
	_base_coins = coins_earned
	_base_gems = gems_earned
	_reward_multiplied = false

	# Update title with animation
	title_label.text = "🎉 Level %d Complete! 🎉" % completed_level

	# Add subtle pulsing animation to title
	var title_tween = create_tween()
	title_tween.set_loops()
	title_tween.tween_property(title_label, "scale", Vector2(1.05, 1.05), 0.8)
	title_tween.tween_property(title_label, "scale", Vector2(1.0, 1.0), 0.8)

	# Update star rating display
	_update_star_display(stars)

	# Update score
	score_label.text = "Final Score: %d" % final_score

	# Update rewards display
	_update_rewards_display(coins_earned, gems_earned)

	# Check if this level unlocked a gallery image
	_check_and_show_gallery_unlock(completed_level)

	# Update button text based on whether there's a next level
	if has_next_level:
		continue_button.text = "Continue to Next Level"
	else:
		continue_button.text = "Back to Menu"

	# Reset multiplier UI
	_reset_multiplier_ui()

	# Add small delay before starting multiplier to avoid consuming skip tap
	await get_tree().create_timer(0.3).timeout

	# Auto-start the multiplier game (no button needed)
	_start_multiplier_game()

	# Show this screen
	visible = true

	print("[LevelTransition] ✅ Visibility set to: ", visible)
	print("[LevelTransition] Parent: ", get_parent().name if get_parent() else "NO PARENT")
	print("[LevelTransition] Is in scene tree: ", is_inside_tree())
	print("=".repeat(60))
	print("[LevelTransition] Transition screen displayed")
	print("=".repeat(60))

func _update_star_display(stars: int):
	"""Update the star rating display (1-3 stars)"""
	var star_container = content_container.get_node_or_null("StarContainer")
	if not star_container:
		return

	# Clear existing stars
	for child in star_container.get_children():
		child.queue_free()

	# Create 3 star labels
	for i in range(3):
		var star_label = Label.new()
		ThemeManager.apply_bangers_font(star_label, 64)

		if i < stars:
			# Earned star - golden
			star_label.text = "⭐"
			star_label.add_theme_color_override("font_color", StarRatingManager.get_star_color(i + 1, stars))
		else:
			# Unearned star - grey
			star_label.text = "☆"
			star_label.add_theme_color_override("font_color", StarRatingManager.get_star_color(i + 1, stars))

		star_container.add_child(star_label)

		# Animate star appearance with delay
		star_label.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(star_label, "modulate:a", 1.0, 0.3).set_delay(i * 0.2)

		# Scale animation for earned stars
		if i < stars:
			star_label.scale = Vector2(0.1, 0.1)
			tween.parallel().tween_property(star_label, "scale", Vector2(1.2, 1.2), 0.3).set_delay(i * 0.2)
			tween.tween_property(star_label, "scale", Vector2(1.0, 1.0), 0.1)

func _update_rewards_display(coins: int, gems: int):
	"""Update the rewards display with current values and performance summary"""
	# Clear previous reward labels immediately (but keep the title)
	var children_to_remove = []
	for child in rewards_container.get_children():
		if child.name != "RewardsTitle":  # Keep title
			children_to_remove.append(child)

	# Remove and free immediately
	for child in children_to_remove:
		rewards_container.remove_child(child)
		child.free()

	# Add performance summary if we have level data
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and game_manager.last_level_moves_left >= 0:
		var level_manager = get_node_or_null("/root/LevelManager")
		if level_manager:
			var level_data = level_manager.get_level(level_manager.current_level_index)
			if level_data:
				var total_moves = level_data.moves
				var moves_used = total_moves - game_manager.last_level_moves_left
				var efficiency = int((float(total_moves - moves_used) / float(total_moves)) * 100)

				# Performance summary
				var performance_label = Label.new()
				performance_label.name = "PerformanceSummary"
				performance_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ThemeManager.apply_bangers_font(performance_label, 20)

				if efficiency >= 50:
					performance_label.text = "⚡ Efficient! Used %d/%d moves (%d%% saved)" % [moves_used, total_moves, efficiency]
					performance_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))  # Green
				elif efficiency >= 25:
					performance_label.text = "✓ Good! Used %d/%d moves (%d%% saved)" % [moves_used, total_moves, efficiency]
					performance_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # Yellow
				else:
					performance_label.text = "Used %d/%d moves" % [moves_used, total_moves]
					performance_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))  # Grey

				rewards_container.add_child(performance_label)

				# Small spacer
				var spacer = Control.new()
				spacer.custom_minimum_size = Vector2(0, 10)
				rewards_container.add_child(spacer)

	# Add rewards display with icons
	if coins > 0:
		var coins_display = ThemeManager.create_currency_display("coins", coins, 28, 24, Color(1.0, 0.84, 0.0, 1.0))
		coins_display.name = "RewardCoins"
		coins_display.alignment = BoxContainer.ALIGNMENT_CENTER

		# Add "Coins: +" prefix
		var prefix_label = Label.new()
		prefix_label.text = "Coins: +"
		ThemeManager.apply_bangers_font(prefix_label, 24)
		prefix_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
		coins_display.add_child(prefix_label)
		coins_display.move_child(prefix_label, 0)

		rewards_container.add_child(coins_display)

	if gems > 0:
		var gems_display = ThemeManager.create_currency_display("gems", gems, 28, 24, Color(0.3, 0.7, 1.0, 1.0))
		gems_display.name = "RewardGems"
		gems_display.alignment = BoxContainer.ALIGNMENT_CENTER

		# Add "Gems: +" prefix
		var prefix_label = Label.new()
		prefix_label.text = "Gems: +"
		ThemeManager.apply_bangers_font(prefix_label, 24)
		prefix_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1.0))
		gems_display.add_child(prefix_label)
		gems_display.move_child(prefix_label, 0)

		rewards_container.add_child(gems_display)

func _check_and_show_gallery_unlock(level: int):
	"""Check if this level unlocked a gallery image and show notification"""
	# Define gallery unlock levels
	var gallery_levels = {
		2: "Victory", 4: "Celebration", 6: "Achievement", 8: "Glory", 10: "Champion",
		12: "Master", 14: "Legend", 16: "Hero", 18: "Elite", 20: "Ultimate"
	}

	if gallery_levels.has(level):
		var image_name = gallery_levels[level]
		var image_id = "image_%02d" % (gallery_levels.keys().find(level) + 1)

		# Check if this was just unlocked (not already in unlocked list before this level)
		if RewardManager.is_gallery_image_unlocked(image_id):
			# Create gallery unlock notification
			var gallery_unlock = HBoxContainer.new()
			gallery_unlock.name = "GalleryUnlock"
			gallery_unlock.alignment = BoxContainer.ALIGNMENT_CENTER

			var unlock_label = Label.new()
			unlock_label.text = "🖼️ Gallery Unlocked: " + image_name
			ThemeManager.apply_bangers_font(unlock_label, 22)
			unlock_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.2, 1.0))
			gallery_unlock.add_child(unlock_label)

			rewards_container.add_child(gallery_unlock)
			print("[LevelTransition] Showing gallery unlock notification: ", image_name)

func _reset_multiplier_ui():
	"""Reset the multiplier UI to initial state"""
	_multiplier_active = false
	_reward_multiplied = false
	_pointer_position = 0.0
	_pointer_direction = 1.0
	_selected_multiplier = 1.0

	# Clean up any old labels from previous levels
	if multiplier_container:
		# Remove "watch ad to claim" label if it exists
		var watch_ad_label = multiplier_container.get_node_or_null("WatchAdLabel")
		if watch_ad_label:
			multiplier_container.remove_child(watch_ad_label)
			watch_ad_label.queue_free()

		# Remove old result label if it exists
		var old_result = multiplier_container.get_node_or_null("ResultLabel")
		if old_result:
			multiplier_container.remove_child(old_result)
			old_result.queue_free()

	# Hide ad trigger button (not needed - auto-start instead)
	if ad_trigger_button:
		ad_trigger_button.visible = false

	# Show the bar container immediately
	var bar_container = multiplier_container.get_node_or_null("BarContainer")
	if bar_container:
		bar_container.visible = true

	# Hide tap instruction (will show when game starts)
	if tap_instruction_label:
		tap_instruction_label.visible = false
		tap_instruction_label.text = "TAP TO STOP AND WATCH AD!"

func _start_multiplier_game():
	"""Start the multiplier mini-game automatically (no button needed)"""
	if _reward_multiplied:
		print("[LevelTransition] Multiplier already used, not starting")
		return

	print("[LevelTransition] Auto-starting multiplier challenge")

	# Show tap instruction
	if tap_instruction_label:
		tap_instruction_label.visible = true

	# Start the pointer movement immediately
	_multiplier_active = true
	_pointer_position = 0.0
	_pointer_direction = 1.0

	print("[LevelTransition] Multiplier game active - waiting for tap")

func _on_ad_trigger_pressed():
	"""Legacy button handler - no longer used since we auto-start"""
	# This function is kept for compatibility but should never be called
	# since the button is now hidden
	pass

func _on_ad_reward_earned_signal(reward_type: String, reward_amount: int):
	"""Called when user earns reward from mobile ad (via signal)"""
	print("[LevelTransition] Ad reward earned via signal: ", reward_type, " x", reward_amount)

	# Only apply multiplier if we're actually waiting for an ad reward
	# This prevents accidental multiplier application from unrelated ads
	if not visible or _reward_multiplied or _selected_multiplier <= 1.0:
		print("[LevelTransition] Ignoring ad reward - not in multiplier flow (visible=%s, multiplied=%s, multiplier=%.1fx)" % [visible, _reward_multiplied, _selected_multiplier])
		return

	_apply_multiplier()


func _on_multiplier_tapped():
	"""Handle when user taps to stop the pointer - then shows ad"""
	if not _multiplier_active:
		return

	_multiplier_active = false
	AudioManager.play_sfx("ui_click")

	# Calculate which zone the pointer is in
	var bar_width = 480.0
	var pointer_percent = _pointer_position / bar_width

	# Find the zone
	for zone_data in _multiplier_config:
		if pointer_percent >= zone_data[0] and pointer_percent < zone_data[1]:
			_selected_multiplier = zone_data[2]
			break

	print("[LevelTransition] Pointer stopped at %.2f%% - Multiplier: %.1fx" % [pointer_percent * 100, _selected_multiplier])

	# Hide tap instruction
	if tap_instruction_label:
		tap_instruction_label.visible = false

	# Show "Watch ad to claim" message
	var watch_ad_label = Label.new()
	watch_ad_label.name = "WatchAdLabel"
	watch_ad_label.text = "📺 Watch ad to claim %.1fx multiplier!" % _selected_multiplier
	watch_ad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(watch_ad_label, 20)
	watch_ad_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3, 1.0))
	multiplier_container.add_child(watch_ad_label)

	# Now trigger the ad
	print("[LevelTransition] Triggering ad to claim %.1fx multiplier" % _selected_multiplier)

	# Get AdMobManager
	var admob_manager = get_node_or_null("/root/AdMobManager")
	print("[LevelTransition] AdMobManager found: ", admob_manager != null)

	if admob_manager and admob_manager.has_method("show_rewarded_ad"):
		print("[LevelTransition] Showing rewarded ad via AdMobManager")
		print("[LevelTransition] Waiting for user_earned_reward signal...")
		admob_manager.show_rewarded_ad()
	else:
		# Fallback for desktop/testing - immediately apply
		print("[LevelTransition] AdMobManager not available - using test mode")
		_apply_multiplier()

func _apply_multiplier():
	"""Apply the selected multiplier to rewards"""
	# Prevent double application
	if _reward_multiplied:
		print("[LevelTransition] Multiplier already applied, ignoring duplicate call")
		return

	if _selected_multiplier <= 1.0:
		print("[LevelTransition] No multiplier selected (%.1fx), skipping" % _selected_multiplier)
		return

	print("[LevelTransition] Applying %.1fx multiplier to rewards" % _selected_multiplier)

	# Multiply the rewards
	_base_coins = int(_base_coins * _selected_multiplier)
	_base_gems = int(_base_gems * _selected_multiplier)
	_reward_multiplied = true

	# Update the display
	_update_rewards_display(_base_coins, _base_gems)

	# Hide tap instruction
	if tap_instruction_label:
		tap_instruction_label.visible = false

	# Remove "watch ad to claim" label if it exists
	var watch_ad_label = multiplier_container.get_node_or_null("WatchAdLabel")
	if watch_ad_label:
		multiplier_container.remove_child(watch_ad_label)
		watch_ad_label.queue_free()

	# Remove old result label if it exists (cleanup from previous)
	var old_result = multiplier_container.get_node_or_null("ResultLabel")
	if old_result:
		multiplier_container.remove_child(old_result)
		old_result.queue_free()

	# Show brief result message that will auto-fade
	var result_label = Label.new()
	result_label.name = "ResultLabel"
	result_label.text = "🎉 %.1fx Multiplier Applied! 🎉" % _selected_multiplier
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(result_label, 28)
	if _selected_multiplier >= 3.0:
		result_label.add_theme_color_override("font_color", Color(1.0, 0.5, 1.0, 1.0))  # Pink for jackpot
	elif _selected_multiplier >= 2.0:
		result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0, 1.0))  # Blue for good
	else:
		result_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))  # Gray for low

	multiplier_container.add_child(result_label)

	# Auto-remove the result label after 3 seconds with fade
	_schedule_label_fade(result_label)

	print("[LevelTransition] Rewards multiplied: %d coins, %d gems" % [_base_coins, _base_gems])

func _schedule_label_fade(label: Label):
	"""Helper function to schedule label fade and removal"""
	await get_tree().create_timer(3.0).timeout

	if label and is_instance_valid(label) and label.get_parent():
		var tween = create_tween()
		tween.tween_property(label, "modulate:a", 0.0, 0.5)
		await tween.finished

		if label and is_instance_valid(label) and label.get_parent():
			label.get_parent().remove_child(label)
			label.queue_free()

func _on_ad_reward_earned():
	"""Legacy function for compatibility - applies multiplier"""
	_apply_multiplier()

func _on_ad_closed():
	"""Called when ad is closed - may or may not have been watched completely"""
	print("[LevelTransition] Ad closed")
	# Note: Game auto-restarts on next level, so no action needed here

func _on_ad_failed(error_message: String):
	"""Called when ad fails to show"""
	print("[LevelTransition] Ad failed: ", error_message)
	# Note: Game will auto-restart on next level, pointer will move again

func _on_continue_pressed():
	"""Handle continue button press"""
	AudioManager.play_sfx("ui_click")
	print("[LevelTransition] Continue button pressed")

	# Stop any active multiplier game and prevent further ad callbacks
	_multiplier_active = false
	_selected_multiplier = 1.0

	# Claim rewards with current values (potentially multiplied)
	var rm = get_node_or_null('/root/RewardManager')
	if rm:
		rm.add_coins(_base_coins)
		rm.add_gems(_base_gems)

	# Hide this screen
	visible = false

	# Emit signal for GameUI to handle
	emit_signal("continue_pressed")

func _on_replay_pressed():
	"""Handle replay button press - restart the same level"""
	AudioManager.play_sfx("ui_click")
	print("[LevelTransition] Replay button pressed - restarting level")

	# Stop any active multiplier game and prevent further ad callbacks
	_multiplier_active = false
	_selected_multiplier = 1.0

	# Hide this screen
	visible = false

	# Get the level that was just completed
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		var level_to_replay = game_manager.last_level_number
		print("[LevelTransition] Want to replay level %d" % level_to_replay)
		print("[LevelTransition] Current GameManager.level = %d" % game_manager.level)

		# Reset GameManager state
		game_manager.level_transitioning = false
		game_manager.initialized = false

		# IMPORTANT: Set the level back to the one we want to replay
		game_manager.level = level_to_replay

		# Set level manager index to the level we want to replay (0-indexed)
		if game_manager.level_manager:
			var replay_index = level_to_replay - 1
			game_manager.level_manager.current_level_index = replay_index
			print("[LevelTransition] Set level_manager.current_level_index to %d (for level %d)" % [replay_index, level_to_replay])

		# Show the GameBoard (it was hidden during level complete)
		var game_board = get_node_or_null("/root/MainGame/GameBoard")
		if game_board:
			game_board.visible = true
			print("[LevelTransition] GameBoard set to visible")

		# Reload the level (this will emit level_loaded signal)
		game_manager.load_current_level()

		# Show the start page for this level
		var game_ui = get_node_or_null("../GameUI") if get_parent() else null
		if game_ui and game_ui.start_page:
			game_ui.start_page.visible = true
			if game_ui.start_page.has_method("set_level_info"):
				game_ui.start_page.set_level_info(level_to_replay)
	else:
		print("[LevelTransition] ERROR: GameManager not found for replay")

func _connect_admob_signals():
	"""Connect to AdMobManager signals for rewarded ads"""
	var admob_manager = get_node_or_null("/root/AdMobManager")
	if not admob_manager:
		print("[LevelTransition] AdMobManager not found - running in test mode")
		return

	print("[LevelTransition] Found AdMobManager, connecting signals...")

	# Connect user_earned_reward signal (main reward signal)
	var reward_callable = Callable(self, "_on_ad_reward_earned_signal")
	if not admob_manager.user_earned_reward.is_connected(reward_callable):
		admob_manager.user_earned_reward.connect(reward_callable)
		print("[LevelTransition] ✓ Connected user_earned_reward signal")
	else:
		print("[LevelTransition] user_earned_reward already connected")

	# Connect rewarded_ad_closed signal
	var closed_callable = Callable(self, "_on_ad_closed")
	if not admob_manager.rewarded_ad_closed.is_connected(closed_callable):
		admob_manager.rewarded_ad_closed.connect(closed_callable)
		print("[LevelTransition] ✓ Connected rewarded_ad_closed signal")
	else:
		print("[LevelTransition] rewarded_ad_closed already connected")

	# Connect rewarded_ad_failed_to_show signal
	var failed_callable = Callable(self, "_on_ad_failed")
	if not admob_manager.rewarded_ad_failed_to_show.is_connected(failed_callable):
		admob_manager.rewarded_ad_failed_to_show.connect(failed_callable)
		print("[LevelTransition] ✓ Connected rewarded_ad_failed_to_show signal")
	else:
		print("[LevelTransition] rewarded_ad_failed_to_show already connected")
