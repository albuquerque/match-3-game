extends Control

# Reward notification popup that appears when player receives rewards

signal notification_closed

@onready var animation_player = $AnimationPlayer
@onready var reward_label = $Panel/VBoxContainer/RewardLabel
@onready var description_label = $Panel/VBoxContainer/DescriptionLabel
@onready var icon_container = $Panel/VBoxContainer/IconContainer
@onready var close_button = $Panel/VBoxContainer/CloseButton

var reward_queue: Array = []
var is_showing: bool = false
# Preload gold star texture for consistent display
var gold_star_texture = preload("res://textures/gold_star.svg")

func _ready():
	visible = false
	close_button.pressed.connect(_on_close_pressed)

func show_reward(reward_type: String, amount: int, description: String = ""):
	"""Show a reward notification"""
	var reward_data = {
		"type": reward_type,
		"amount": amount,
		"description": description
	}

	if is_showing:
		# Queue the reward if one is already showing
		reward_queue.append(reward_data)
	else:
		_display_reward(reward_data)

func _display_reward(reward_data: Dictionary):
	is_showing = true
	visible = true

	# Set reward text and icon based on type
	match reward_data.type:
		"coins":
			reward_label.text = "+%d Coins" % reward_data.amount
		"gems":
			reward_label.text = "+%d Gems" % reward_data.amount
		"lives":
			# Keep emoji for lives as we don't have an SVG
			reward_label.text = "❤️ +%d Lives" % reward_data.amount
		"booster":
			# Keep emoji for booster as we don't have a generic SVG
			reward_label.text = "🚀 Booster Unlocked!"
		"stars":
			# Use gold star SVG texture for star rewards
			reward_label.text = "%d Stars!" % reward_data.amount
		_:
			# Keep emoji for generic rewards
			reward_label.text = "🎁 Reward!"

	# Update description
	if reward_data.description != "":
		description_label.text = reward_data.description
		description_label.visible = true
	else:
		description_label.visible = false

	# Create icon
	for child in icon_container.get_children():
		child.queue_free()

	# Directly create the icon node based on reward type to avoid type/assignment issues
	if reward_data.type == "coins":
		var coin_tex = ThemeManager.load_coin_icon()
		if coin_tex:
			var icon_rect = TextureRect.new()
			icon_rect.texture = coin_tex
			icon_rect.custom_minimum_size = Vector2(80, 80)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_container.add_child(icon_rect)
		else:
			var icon_label = Label.new()
			icon_label.text = "💰"
			icon_label.add_theme_font_size_override("font_size", 48)
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_container.add_child(icon_label)
	elif reward_data.type == "gems":
		var gem_tex = ThemeManager.load_gem_icon()
		if gem_tex:
			var icon_rect = TextureRect.new()
			icon_rect.texture = gem_tex
			icon_rect.custom_minimum_size = Vector2(80, 80)
			icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_container.add_child(icon_rect)
		else:
			var icon_label = Label.new()
			icon_label.text = "💎"
			icon_label.add_theme_font_size_override("font_size", 48)
			icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			icon_container.add_child(icon_label)
	elif reward_data.type == "stars":
		# Use gold_star_texture directly
		var icon_rect = TextureRect.new()
		icon_rect.texture = gold_star_texture
		icon_rect.custom_minimum_size = Vector2(80, 80)
		icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(icon_rect)
	else:
		# Use Label for emoji fallback (lives, boosters, generic)
		var icon_label = Label.new()
		var icon_text = ""
		match reward_data.type:
			"lives":
				icon_text = "❤️"
			"booster":
				icon_text = "🚀"
			_:
				icon_text = "🎁"
		icon_label.text = icon_text
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 72)
		icon_container.add_child(icon_label)

	# Play animation
	if animation_player.has_animation("show_reward"):
		animation_player.play("show_reward")
	else:
		# Fallback manual animation
		modulate = Color.TRANSPARENT
		var tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_close_pressed():
	_close_notification()

func _close_notification():
	is_showing = false

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(_on_notification_close_complete)

func _on_notification_close_complete():
	visible = false
	notification_closed.emit()

	# Show next queued reward if any
	if reward_queue.size() > 0:
		var next_reward = reward_queue.pop_front()
		await get_tree().create_timer(0.2).timeout
		_display_reward(next_reward)

func show_level_complete_rewards(level: int, stars: int, coins_earned: int, bonus_gems: int = 0):
	"""Show comprehensive level completion rewards"""
	var desc = "Level %d Complete!\n" % level
	if bonus_gems > 0:
		desc += "First 3-star bonus!"

	show_reward("stars", stars, desc)

	# Queue additional rewards
	if coins_earned > 0:
		reward_queue.append({
			"type": "coins",
			"amount": coins_earned,
			"description": "Level completion reward"
		})

	if bonus_gems > 0:
		reward_queue.append({
			"type": "gems",
			"amount": bonus_gems,
			"description": "3-Star Bonus!"
		})

func show_daily_login_reward(day: int, coins: int, gems: int = 0, booster: String = ""):
	"""Show daily login reward"""
	var desc = "Day %d Login Reward!" % day

	show_reward("coins", coins, desc)

	if gems > 0:
		reward_queue.append({
			"type": "gems",
			"amount": gems,
			"description": "Bonus gems!"
		})

	if booster != "":
		reward_queue.append({
			"type": "booster",
			"amount": 1,
			"description": "Free %s booster!" % booster.capitalize()
		})
