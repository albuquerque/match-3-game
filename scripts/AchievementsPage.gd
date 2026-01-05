extends Control

# Achievements page showing badges and daily login streak

signal back_pressed

@onready var streak_label: Label
@onready var badges_container: VBoxContainer
@onready var claim_reward_button: Button
@onready var back_button: Button

func _ready():
	# Create UI programmatically for flexibility
	_setup_ui()
	_update_display()

func _setup_ui():
	# Add opaque background
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.05, 0.05, 0.05, 1.0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Main container
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.95
	add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "Achievements"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Daily Streak Section
	var streak_panel = Panel.new()
	var streak_style = StyleBoxFlat.new()
	streak_style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	streak_style.corner_radius_top_left = 10
	streak_style.corner_radius_top_right = 10
	streak_style.corner_radius_bottom_left = 10
	streak_style.corner_radius_bottom_right = 10
	streak_panel.add_theme_stylebox_override("panel", streak_style)
	streak_panel.custom_minimum_size = Vector2(0, 150)
	vbox.add_child(streak_panel)

	var streak_vbox = VBoxContainer.new()
	streak_vbox.anchor_right = 1.0
	streak_vbox.anchor_bottom = 1.0
	streak_vbox.offset_left = 20
	streak_vbox.offset_top = 20
	streak_vbox.offset_right = -20
	streak_vbox.offset_bottom = -20
	streak_panel.add_child(streak_vbox)

	var streak_title = Label.new()
	streak_title.text = "🔥 Daily Login Streak"
	streak_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_title.add_theme_font_size_override("font_size", 28)
	streak_title.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	streak_vbox.add_child(streak_title)

	streak_label = Label.new()
	streak_label.name = "StreakLabel"
	streak_label.text = "Current Streak: 0 days"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	streak_label.add_theme_font_size_override("font_size", 24)
	streak_vbox.add_child(streak_label)

	var reward_info = Label.new()
	reward_info.text = "Login daily to earn rewards!"
	reward_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_info.add_theme_font_size_override("font_size", 16)
	reward_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	streak_vbox.add_child(reward_info)

	# Claim reward button
	claim_reward_button = Button.new()
	claim_reward_button.name = "ClaimRewardButton"
	claim_reward_button.text = "Claim Daily Reward"
	claim_reward_button.custom_minimum_size = Vector2(250, 50)
	claim_reward_button.disabled = true
	claim_reward_button.pressed.connect(_on_claim_reward_pressed)
	streak_vbox.add_child(claim_reward_button)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer2)

	# Badges section
	var badges_title = Label.new()
	badges_title.text = "Milestone Badges"
	badges_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badges_title.add_theme_font_size_override("font_size", 28)
	badges_title.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	vbox.add_child(badges_title)

	# Scroll container for badges
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	badges_container = VBoxContainer.new()
	badges_container.name = "BadgesContainer"
	scroll.add_child(badges_container)

	# Back button
	back_button = Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(150, 50)
	back_button.pressed.connect(_on_back_pressed)
	vbox.add_child(back_button)

func _update_display():
	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return

	# Update streak display
	var streak = rm.daily_streak
	if streak_label:
		streak_label.text = "Current Streak: %d days" % streak

		# Add visual flair for milestones
		if streak >= 7:
			streak_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
		elif streak >= 4:
			streak_label.add_theme_color_override("font_color", Color(0.8, 1, 0.4))
		else:
			streak_label.add_theme_color_override("font_color", Color(1, 1, 1))

	# Check if reward can be claimed
	var can_claim = _can_claim_daily_reward()
	if claim_reward_button:
		claim_reward_button.disabled = not can_claim
		if can_claim:
			claim_reward_button.text = "🎁 Claim Daily Reward"
		else:
			claim_reward_button.text = "✓ Reward Claimed Today"

	# Update badges
	_update_badges(streak)

func _can_claim_daily_reward() -> bool:
	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return false

	# Check if reward was claimed today
	var last_claim = rm.last_daily_reward_claim if "last_daily_reward_claim" in rm else ""
	var today = Time.get_date_string_from_system()

	return last_claim != today

func _update_badges(streak: int):
	if not badges_container:
		return

	# Clear existing badges
	for child in badges_container.get_children():
		child.queue_free()

	# Define badge milestones
	var badges = [
		{"days": 3, "title": "🌟 Consistent Player", "desc": "Login 3 days in a row"},
		{"days": 7, "title": "🔥 Week Warrior", "desc": "Login 7 days in a row"},
		{"days": 14, "title": "💎 Dedicated", "desc": "Login 14 days in a row"},
		{"days": 30, "title": "👑 Legend", "desc": "Login 30 days in a row"}
	]

	for badge in badges:
		var badge_panel = _create_badge_panel(badge["days"], badge["title"], badge["desc"], streak >= badge["days"])
		badges_container.add_child(badge_panel)

func _create_badge_panel(required_days: int, title: String, desc: String, unlocked: bool) -> Panel:
	var panel = Panel.new()
	var style = StyleBoxFlat.new()

	if unlocked:
		style.bg_color = Color(0.2, 0.4, 0.2, 1.0)
		style.border_color = Color(0.4, 0.8, 0.4, 1.0)
	else:
		style.bg_color = Color(0.15, 0.15, 0.15, 1.0)
		style.border_color = Color(0.3, 0.3, 0.3, 1.0)

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()
	hbox.anchor_right = 1.0
	hbox.anchor_bottom = 1.0
	hbox.offset_left = 15
	hbox.offset_top = 10
	hbox.offset_right = -15
	hbox.offset_bottom = -10
	panel.add_child(hbox)

	var badge_vbox = VBoxContainer.new()
	badge_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(badge_vbox)

	var title_label = Label.new()
	title_label.text = title if unlocked else "🔒 " + title
	title_label.add_theme_font_size_override("font_size", 20)
	if unlocked:
		title_label.add_theme_color_override("font_color", Color(1, 1, 0.5))
	else:
		title_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	badge_vbox.add_child(title_label)

	var desc_label = Label.new()
	desc_label.text = desc
	desc_label.add_theme_font_size_override("font_size", 14)
	if not unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	badge_vbox.add_child(desc_label)

	var status_label = Label.new()
	if unlocked:
		status_label.text = "✓ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.5, 1, 0.5))
	else:
		status_label.text = "LOCKED"
		status_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	status_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(status_label)

	return panel

func _on_claim_reward_pressed():
	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return

	if not _can_claim_daily_reward():
		return

	var streak = rm.daily_streak
	var rewards = _get_daily_rewards(streak)

	# Grant rewards
	for reward_type in rewards:
		var amount = rewards[reward_type]
		if reward_type == "coins":
			rm.add_coins(amount)
		elif reward_type == "gems":
			rm.add_gems(amount)
		else:
			# It's a booster
			rm.add_booster(reward_type, amount)

	# Mark reward as claimed
	rm.last_daily_reward_claim = Time.get_date_string_from_system()
	rm.save_progress()

	# Show notification
	_show_reward_notification(rewards, streak)

	# Update display
	_update_display()

func _get_daily_rewards(streak: int) -> Dictionary:
	var rewards = {}

	# Base coin reward
	rewards["coins"] = 50 + (streak * 10)

	# Streak-based booster rewards
	if streak >= 1 and streak <= 3:
		# Days 1-3: Small boosters
		rewards["hammer"] = 1
		if streak >= 2:
			rewards["swap"] = 1
		if streak >= 3:
			rewards["shuffle"] = 1
	elif streak >= 4 and streak <= 6:
		# Days 4-6: Medium boosters
		rewards["row_clear"] = 1
		rewards["column_clear"] = 1
		if streak >= 5:
			rewards["bomb_3x3"] = 1
		if streak >= 6:
			rewards["gems"] = 5
	elif streak >= 7:
		# Day 7+: Special boosters
		rewards["line_blast"] = 2
		rewards["bomb_3x3"] = 2
		rewards["chain_reaction"] = 1
		rewards["gems"] = 10

		# Bonus for every week
		var weeks = int(streak / 7)
		if weeks > 1:
			rewards["gems"] = 10 + (weeks * 5)

	return rewards

func _show_reward_notification(rewards: Dictionary, streak: int):
	# Create a fullscreen overlay popup
	var popup_overlay = Control.new()
	popup_overlay.name = "RewardPopup"
	popup_overlay.anchor_right = 1.0
	popup_overlay.anchor_bottom = 1.0
	popup_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	popup_overlay.add_child(bg)

	# Main panel
	var panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 1.0)
	style.border_color = Color(0.8, 0.6, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", style)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -250
	panel.offset_top = -200
	panel.offset_right = 250
	panel.offset_bottom = 200
	popup_overlay.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "🎁 Day %d Reward Claimed!" % streak
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Rewards list
	var rewards_label = Label.new()
	rewards_label.text = "You received:"
	rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(rewards_label)

	# Spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer2)

	# Create scrollable container for rewards
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var rewards_vbox = VBoxContainer.new()
	scroll.add_child(rewards_vbox)

	# Add each reward as a nicely formatted line
	for reward_type in rewards:
		var amount = rewards[reward_type]
		var name = reward_type.capitalize().replace("_", " ")

		var reward_line = HBoxContainer.new()
		reward_line.alignment = BoxContainer.ALIGNMENT_CENTER
		rewards_vbox.add_child(reward_line)

		var icon_label = Label.new()
		if reward_type == "coins":
			icon_label.text = "💰"
		elif reward_type == "gems":
			icon_label.text = "💎"
		else:
			icon_label.text = "⭐"
		icon_label.add_theme_font_size_override("font_size", 28)
		reward_line.add_child(icon_label)

		var reward_text = Label.new()
		reward_text.text = " %s x%d" % [name, amount]
		reward_text.add_theme_font_size_override("font_size", 24)
		reward_text.add_theme_color_override("font_color", Color(0.9, 1, 0.9))
		reward_line.add_child(reward_text)

	# Spacer
	var spacer3 = Control.new()
	spacer3.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer3)

	# Close button
	var close_btn = Button.new()
	close_btn.text = "Awesome!"
	close_btn.custom_minimum_size = Vector2(200, 50)
	close_btn.pressed.connect(func(): popup_overlay.queue_free())
	vbox.add_child(close_btn)

	# Add to scene
	add_child(popup_overlay)

	# Play sound effect
	AudioManager.play_sfx("ui_click")

	# Animate popup appearance
	popup_overlay.modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_property(popup_overlay, "modulate", Color.WHITE, 0.3)

	print("[AchievementsPage] Reward notification shown: ", rewards)

func _on_back_pressed():
	emit_signal("back_pressed")
	queue_free()

func show_page():
	visible = true
	_update_display()

