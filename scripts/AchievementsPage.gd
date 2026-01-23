extends Control

# Achievements page showing badges and daily login streak

signal back_pressed

@onready var streak_label: Label
@onready var badges_container: VBoxContainer
@onready var claim_reward_button: Button
@onready var back_button: Button

# Preload gold star texture for consistent display
var gold_star_texture = preload("res://textures/gold_star.svg")

func _ready():
	# Create UI programmatically for flexibility
	_setup_ui()
	_update_display()

func _setup_ui():
	# Try to add background image first, fallback to solid color
	_setup_background()

	# Main container
	var vbox = VBoxContainer.new()
	vbox.name = "MainVBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.05
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.95
	add_child(vbox)

	# Title with warm biblical colors
	var title = Label.new()
	title.text = "Achievements"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(title, 40)
	title.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))  # Deep warm brown
	vbox.add_child(title)

	# Spacer
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer1)

	# Daily Streak Section (increased transparency)
	var streak_panel = Panel.new()
	var streak_style = StyleBoxFlat.new()
	streak_style.bg_color = Color(0.15, 0.15, 0.2, 0.8)  # Reduced opacity from 1.0 to 0.8
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
	ThemeManager.apply_bangers_font(streak_title, 28)
	streak_title.add_theme_color_override("font_color", Color(1, 0.6, 0.2))
	streak_vbox.add_child(streak_title)

	streak_label = Label.new()
	streak_label.name = "StreakLabel"
	streak_label.text = "Current Streak: 0 days"
	streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(streak_label, 24)
	streak_vbox.add_child(streak_label)

	var reward_info = Label.new()
	reward_info.text = "Login daily to earn rewards!"
	reward_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(reward_info, 16)
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
	ThemeManager.apply_bangers_font(badges_title, 28)
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

	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return

	# Define all achievements with categories (expanded for long-term engagement)
	var achievement_categories = [
		{
			"title": "📈 Match Master",
			"achievements": [
				{"id": "matches_100", "title": "First Century", "desc": "Make 100 matches"},
				{"id": "matches_500", "title": "Match Veteran", "desc": "Make 500 matches"},
				{"id": "matches_1000", "title": "Match Legend", "desc": "Make 1000 matches"},
				{"id": "matches_2500", "title": "Match Hero", "desc": "Make 2500 matches"},
				{"id": "matches_5000", "title": "Match Master", "desc": "Make 5000 matches"},
				{"id": "matches_10000", "title": "Match God", "desc": "Make 10,000 matches"},
			]
		},
		{
			"title": "🏆 Level Progress",
			"achievements": [
				{"id": "levels_10", "title": "Explorer", "desc": "Complete 10 levels"},
				{"id": "levels_25", "title": "Adventurer", "desc": "Complete 25 levels"},
				{"id": "levels_50", "title": "Champion", "desc": "Complete 50 levels"},
				{"id": "levels_100", "title": "Conqueror", "desc": "Complete 100 levels"},
				{"id": "levels_250", "title": "Crusader", "desc": "Complete 250 levels"},
				{"id": "levels_500", "title": "Legendary", "desc": "Complete 500 levels"},
			]
		},
		{
			"title": "Star Collector",
			"achievements": [
				{"id": "stars_10", "title": "Rising Star", "desc": "Earn 10 stars"},
				{"id": "stars_25", "title": "Star Seeker", "desc": "Earn 25 stars"},
				{"id": "stars_50", "title": "Star Master", "desc": "Earn 50 stars"},
				{"id": "stars_100", "title": "Star Lord", "desc": "Earn 100 stars"},
				{"id": "stars_250", "title": "Star Emperor", "desc": "Earn 250 stars"},
				{"id": "stars_500", "title": "Celestial Being", "desc": "Earn 500 stars"},
			]
		},
		{
			"title": "🔥 Daily Streak",
			"achievements": [
				{"id": "streak_3", "title": "Consistent Player", "desc": "Login 3 days in a row"},
				{"id": "streak_7", "title": "Week Warrior", "desc": "Login 7 days in a row"},
				{"id": "streak_14", "title": "Dedicated", "desc": "Login 14 days in a row"},
				{"id": "streak_30", "title": "Legend", "desc": "Login 30 days in a row"},
				{"id": "streak_60", "title": "Devoted", "desc": "Login 60 days in a row"},
				{"id": "streak_100", "title": "Saint", "desc": "Login 100 days in a row"},
			]
		},
		{
			"title": "🎯 Special Challenges",
			"achievements": [
				{"id": "booster_explorer", "title": "Tool Master", "desc": "Use 5 different booster types"},
				{"id": "combo_master", "title": "Combo King", "desc": "Reach a 10+ combo"},
				{"id": "perfect_streak", "title": "Perfectionist", "desc": "Get 3 levels with 3 stars"},
				{"id": "score_hunter", "title": "Score Hunter", "desc": "Earn 100,000 total points"},
				{"id": "score_legend", "title": "Score Legend", "desc": "Earn 1,000,000 total points"},
				{"id": "combo_god", "title": "Combo God", "desc": "Reach a 20+ combo"},
				{"id": "perfect_master", "title": "Perfect Master", "desc": "Get 10 levels with 3 stars"},
				{"id": "booster_addict", "title": "Booster Addict", "desc": "Use 100 boosters total"},
			]
		},
		{
			"title": "📅 Weekly Challenges",
			"achievements": [
				{"id": "weekly_matches", "title": "Weekly Matcher", "desc": "Make 100 matches this week"},
				{"id": "weekly_levels", "title": "Weekly Explorer", "desc": "Complete 10 levels this week"},
				{"id": "weekly_perfect", "title": "Weekly Perfectionist", "desc": "Get 5 perfect levels this week"},
				{"id": "weekly_streak", "title": "Weekly Warrior", "desc": "Play 7 days this week"},
			]
		},
		{
			"title": "🌟 Monthly Milestones",
			"achievements": [
				{"id": "monthly_dedication", "title": "Monthly Devotee", "desc": "Play 20 days this month"},
				{"id": "monthly_scorer", "title": "Monthly Champion", "desc": "Earn 50,000 points this month"},
				{"id": "monthly_collector", "title": "Monthly Star Hunter", "desc": "Earn 25 stars this month"},
			]
		},
		{
			"title": "🎄 Seasonal Events",
			"achievements": [
				{"id": "christmas_spirit", "title": "Christmas Spirit", "desc": "Play during Christmas season"},
				{"id": "easter_joy", "title": "Easter Joy", "desc": "Complete 20 levels during Easter"},
				{"id": "harvest_blessing", "title": "Harvest Blessing", "desc": "Collect 1000 coins in autumn"},
			]
		}
	]

	# Create categories and achievements
	for category in achievement_categories:
		# Category header with biblical theme colors
		var category_header = Label.new()
		category_header.text = category["title"]
		category_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		ThemeManager.apply_bangers_font(category_header, 24)
		category_header.add_theme_color_override("font_color", Color(0.4, 0.2, 0.1))  # Rich brown
		category_header.custom_minimum_size = Vector2(0, 40)
		badges_container.add_child(category_header)

		# Create achievements in this category
		for achievement_data in category["achievements"]:
			var achievement_panel

			if achievement_data["id"].begins_with("streak_"):
				# Handle daily streak achievements differently
				var required_days = int(achievement_data["id"].split("_")[1])
				achievement_panel = _create_achievement_panel(
					achievement_data["id"],
					achievement_data["title"],
					achievement_data["desc"],
					streak,
					required_days,
					streak >= required_days
				)
			else:
				# Handle progress-based achievements
				var progress_data = rm.get_achievement_progress(achievement_data["id"])
				achievement_panel = _create_achievement_panel(
					achievement_data["id"],
					achievement_data["title"],
					achievement_data["desc"],
					progress_data["progress"],
					progress_data["target"],
					progress_data["progress"] >= progress_data["target"]
				)

			badges_container.add_child(achievement_panel)

		# Add spacer between categories
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		badges_container.add_child(spacer)

func _create_achievement_panel(achievement_id: String, title: String, desc: String, current_progress: int, target_progress: int, unlocked: bool) -> Panel:
	var panel = Panel.new()

	# Style the panel with warm biblical theme colors (increased transparency)
	var style = StyleBoxFlat.new()
	if unlocked:
		# Warm golden/cream for completed - more transparent to show background
		style.bg_color = Color(0.95, 0.92, 0.82, 0.75)  # Reduced opacity from 0.95 to 0.75
		style.border_color = Color(0.8, 0.65, 0.3, 0.9)  # Slightly transparent border
	else:
		# Soft sky blue for incomplete - more transparent
		style.bg_color = Color(0.85, 0.9, 0.95, 0.7)    # Reduced opacity from 0.9 to 0.7
		style.border_color = Color(0.6, 0.7, 0.8, 0.8)  # Slightly transparent border

	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(450, 100)  # Ensure minimum width for progress bar + button
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # Allow panel to expand to full width

	var main_hbox = HBoxContainer.new()
	main_hbox.anchor_right = 1.0
	main_hbox.anchor_bottom = 1.0
	main_hbox.offset_left = 15
	main_hbox.offset_top = 10
	main_hbox.offset_right = -15
	main_hbox.offset_bottom = -10
	panel.add_child(main_hbox)

	# Achievement info section
	var achievement_vbox = VBoxContainer.new()
	achievement_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_vbox.custom_minimum_size = Vector2(300, 0)  # Ensure minimum space for content
	main_hbox.add_child(achievement_vbox)

	# Title with appropriate colors for light backgrounds
	var title_label = Label.new()
	title_label.text = title if unlocked else "🔒 " + title
	ThemeManager.apply_bangers_font(title_label, 20)
	if unlocked:
		title_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))  # Warm brown for completed
	else:
		title_label.add_theme_color_override("font_color", Color(0.3, 0.4, 0.6))  # Deep blue for locked
	achievement_vbox.add_child(title_label)

	# Description with readable colors
	var desc_label = Label.new()
	desc_label.text = desc
	ThemeManager.apply_bangers_font(desc_label, 14)
	if unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.5, 0.3, 0.1))   # Darker brown
	else:
		desc_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))   # Muted blue-gray
	achievement_vbox.add_child(desc_label)

	# Progress bar
	var progress_container = HBoxContainer.new()
	progress_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_vbox.add_child(progress_container)

	var progress_bar = ProgressBar.new()
	progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_bar.custom_minimum_size = Vector2(150, 20)  # Reduced minimum width, will expand to fill
	progress_bar.max_value = target_progress
	progress_bar.value = current_progress
	progress_container.add_child(progress_bar)

	var progress_label = Label.new()
	progress_label.text = "%d/%d" % [current_progress, target_progress]
	progress_label.custom_minimum_size = Vector2(60, 0)  # Fixed width for consistent alignment
	ThemeManager.apply_bangers_font(progress_label, 16)
	if unlocked:
		progress_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))  # Warm brown
	else:
		progress_label.add_theme_color_override("font_color", Color(0.3, 0.4, 0.6))  # Deep blue
	progress_container.add_child(progress_label)

	# Right side - Status and reward button
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(110, 0)  # Slightly reduced for better balance
	right_vbox.size_flags_horizontal = Control.SIZE_SHRINK_END  # Keep buttons compact
	main_hbox.add_child(right_vbox)

	# Status/reward section
	var rm = get_node_or_null("/root/RewardManager")
	if unlocked and rm:
		var achievement_progress = rm.get_achievement_progress(achievement_id)
		if not achievement_progress.get("claimed", false):
			# Show claim button with biblical theme colors
			var claim_button = Button.new()
			claim_button.text = "🎁 CLAIM"
			claim_button.custom_minimum_size = Vector2(100, 40)
			ThemeManager.apply_bangers_font_to_button(claim_button, 16)
			claim_button.add_theme_color_override("font_color", Color(0.8, 0.5, 0.1))  # Golden orange
			claim_button.pressed.connect(_on_claim_achievement.bind(achievement_id, claim_button))
			right_vbox.add_child(claim_button)

			# Show reward preview with golden color
			var reward = _get_reward_text(achievement_id)
			var reward_label = Label.new()
			reward_label.text = reward
			reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ThemeManager.apply_bangers_font(reward_label, 12)
			reward_label.add_theme_color_override("font_color", Color(0.7, 0.45, 0.1))  # Darker gold
			right_vbox.add_child(reward_label)
		else:
			# Already claimed
			var claimed_label = Label.new()
			claimed_label.text = "✓ CLAIMED"
			claimed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			ThemeManager.apply_bangers_font(claimed_label, 18)
			claimed_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))  # Warm brown
			right_vbox.add_child(claimed_label)
	else:
		# Locked or no reward manager
		var status_label = Label.new()
		if unlocked:
			status_label.text = "✓ COMPLETE"
			status_label.add_theme_color_override("font_color", Color(0.6, 0.4, 0.1))  # Warm brown
		else:
			status_label.text = "LOCKED"
			status_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))  # Soft blue-gray
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ThemeManager.apply_bangers_font(status_label, 18)
		right_vbox.add_child(status_label)

	return panel

func _get_reward_text(achievement_id: String) -> String:
	"""Get reward preview text for an achievement"""
	var rewards = {
		# Match-based achievements (escalating rewards)
		"matches_100": "100💰 + 1💎",
		"matches_500": "300💰 + 3💎",
		"matches_1000": "500💰 + 5💎",
		"matches_2500": "800💰 + 8💎",
		"matches_5000": "1200💰 + 12💎",
		"matches_10000": "2000💰 + 20💎",

		# Level-based achievements
		"levels_10": "200💰 + 2💎",
		"levels_25": "500💰 + 5💎",
		"levels_50": "1000💰 + 10💎",
		"levels_100": "1500💰 + 15💎",
		"levels_250": "2500💰 + 25💎",
		"levels_500": "4000💰 + 40💎",

		# Star-based achievements
		"stars_10": "150💰 + 2💎",
		"stars_25": "400💰 + 4💎",
		"stars_50": "800💰 + 8💎",
		"stars_100": "1200💰 + 12💎",
		"stars_250": "2000💰 + 20💎",
		"stars_500": "3500💰 + 35💎",

		# Daily streak achievements
		"streak_3": "50💰 + 1💎",
		"streak_7": "100💰 + 2💎",
		"streak_14": "200💰 + 3💎",
		"streak_30": "500💰 + 5💎",
		"streak_60": "800💰 + 8💎",
		"streak_100": "1500💰 + 15💎",

		# Special challenges (high-value rewards)
		"booster_explorer": "300💰 + 5💎",
		"combo_master": "250💰 + 3💎",
		"perfect_streak": "500💰 + 10💎",
		"score_hunter": "600💰 + 8💎",
		"score_legend": "1200💰 + 20💎",
		"combo_god": "800💰 + 15💎",
		"perfect_master": "1000💰 + 20💎",
		"booster_addict": "400💰 + 8💎",

		# Weekly challenges (medium rewards, renewable)
		"weekly_matches": "200💰 + 3💎",
		"weekly_levels": "250💰 + 4💎",
		"weekly_perfect": "300💰 + 5💎",
		"weekly_streak": "150💰 + 2💎",

		# Monthly milestones (high rewards, exclusive)
		"monthly_dedication": "500💰 + 10💎",
		"monthly_scorer": "600💰 + 12💎",
		"monthly_collector": "400💰 + 8💎",

		# Seasonal events (special rewards with limited items)
		"christmas_spirit": "300💰 + 5💎 + 🎄",
		"easter_joy": "400💰 + 8💎 + 🐰",
		"harvest_blessing": "350💰 + 6💎 + 🌾",
	}
	return rewards.get(achievement_id, "50💰 + 1💎")

func _on_claim_achievement(achievement_id: String, button: Button):
	"""Handle claiming achievement reward"""
	AudioManager.play_sfx("ui_click")

	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return

	var result = rm.claim_achievement_reward(achievement_id)
	if result["success"]:
		button.text = "✓ CLAIMED"
		button.disabled = true
		button.add_theme_color_override("font_color", Color(0.5, 1, 0.5))

		# Show reward notification (if available)
		print("[AchievementsPage] Claimed %s: %d coins, %d gems" % [achievement_id, result["coins"], result["gems"]])

		# Refresh the display to show updated state
		_update_display()
	else:
		print("[AchievementsPage] Failed to claim %s: %s" % [achievement_id, result["reason"]])

func _on_claim_reward_pressed():
	var rm = get_node_or_null("/root/RewardManager")
	if not rm:
		return

	if not _can_claim_daily_reward():
		return

	var streak = rm.daily_streak
	var rewards = _get_daily_rewards(streak)

	# Grant rewards
	for reward_type in rewards.keys():
		var amount = rewards[reward_type]
		if str(reward_type) == "coins":
			rm.add_coins(amount)
		elif str(reward_type) == "gems":
			rm.add_gems(amount)
		else:
			# It's a booster
			rm.add_booster(str(reward_type), amount)

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
	ThemeManager.apply_bangers_font(title, 32)
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
	ThemeManager.apply_bangers_font(rewards_label, 20)
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
	for reward_type in rewards.keys():
		var amount = rewards[reward_type]
		var name = str(reward_type).capitalize().replace("_", " ")

		var reward_line = HBoxContainer.new()
		reward_line.alignment = BoxContainer.ALIGNMENT_CENTER
		rewards_vbox.add_child(reward_line)

		# Create icon based on reward type
		if str(reward_type) == "coins" or str(reward_type) == "gems":
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			if str(reward_type) == "coins":
				icon_rect.texture = ThemeManager.load_coin_icon()
			else:
				icon_rect.texture = ThemeManager.load_gem_icon()
			reward_line.add_child(icon_rect)
		else:
			# Use gold star texture instead of emoji for cross-platform consistency
			var icon_rect = TextureRect.new()
			icon_rect.custom_minimum_size = Vector2(28, 28)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = gold_star_texture
			reward_line.add_child(icon_rect)

		var reward_text = Label.new()
		reward_text.text = " %s x%d" % [name, amount]
		ThemeManager.apply_bangers_font(reward_text, 24)
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
	close_btn.pressed.connect(popup_overlay.queue_free)
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

func _setup_background():
	"""Setup background with image support and fallback"""

	# Try different biblical-themed background image paths
	var potential_backgrounds = [
		"res://textures/backgrounds/achievements_bg.jpg",
		"res://textures/backgrounds/achievements_bg.png",
		"res://textures/backgrounds/parchment_bg.jpg",
		"res://textures/backgrounds/parchment_bg.png",
		"res://textures/backgrounds/scroll_bg.jpg",
		"res://textures/backgrounds/scroll_bg.png",
		"res://textures/achievement_background.jpg",
		"res://textures/achievement_background.png",
		"res://textures/biblical_background.jpg",
		"res://textures/biblical_background.png"
	]

	var background_loaded = false

	# Try to load a background image
	for bg_path in potential_backgrounds:
		if FileAccess.file_exists(bg_path):
			var texture = load(bg_path)
			if texture:
				print("[AchievementsPage] Loading background image: ", bg_path)
				var bg_image = TextureRect.new()
				bg_image.name = "BackgroundImage"
				bg_image.texture = texture
				bg_image.anchor_right = 1.0
				bg_image.anchor_bottom = 1.0
				bg_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
				bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(bg_image)

				# Add semi-transparent overlay for better text readability (reduced opacity)
				var overlay = ColorRect.new()
				overlay.name = "BackgroundOverlay"
				overlay.color = Color(0.96, 0.94, 0.88, 0.4)  # Reduced opacity from 0.7 to 0.4
				overlay.anchor_right = 1.0
				overlay.anchor_bottom = 1.0
				overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(overlay)

				background_loaded = true
				print("[AchievementsPage] Background image loaded successfully")
				break

	# Fallback to solid color background if no image found
	if not background_loaded:
		print("[AchievementsPage] No background image found, using solid color")
		var bg = ColorRect.new()
		bg.name = "BackgroundColor"
		bg.color = Color(0.96, 0.94, 0.88, 1.0)  # Warm parchment color
		bg.anchor_right = 1.0
		bg.anchor_bottom = 1.0
		bg.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(bg)

# Helper function to set custom background image
func set_background_image(image_path: String) -> bool:
	"""Set a custom background image for achievements page"""

	if not FileAccess.file_exists(image_path):
		print("[AchievementsPage] Background image not found: ", image_path)
		return false

	var texture = load(image_path)
	if not texture:
		print("[AchievementsPage] Failed to load background image: ", image_path)
		return false

	# Remove existing background
	var existing_bg = get_node_or_null("BackgroundImage")
	if existing_bg:
		existing_bg.queue_free()

	var existing_overlay = get_node_or_null("BackgroundOverlay")
	if existing_overlay:
		existing_overlay.queue_free()

	var existing_color = get_node_or_null("BackgroundColor")
	if existing_color:
		existing_color.queue_free()

	# Add new background image
	var bg_image = TextureRect.new()
	bg_image.name = "BackgroundImage"
	bg_image.texture = texture
	bg_image.anchor_right = 1.0
	bg_image.anchor_bottom = 1.0
	bg_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	bg_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_image)
	move_child(bg_image, 0)  # Move to back

	# Add overlay for readability (reduced transparency)
	var overlay = ColorRect.new()
	overlay.name = "BackgroundOverlay"
	overlay.color = Color(0.96, 0.94, 0.88, 0.4)  # Reduced from 0.7 to 0.4
	overlay.anchor_right = 1.0
	overlay.anchor_bottom = 1.0
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	move_child(overlay, 1)  # Move behind UI but in front of image

	print("[AchievementsPage] Custom background image set: ", image_path)
	return true
