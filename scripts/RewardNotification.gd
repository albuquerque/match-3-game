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

	# Set reward text based on type
	var icon_text = ""
	match reward_data.type:
		"coins":
			icon_text = "💰"
			reward_label.text = "+%d Coins" % reward_data.amount
		"gems":
			icon_text = "💎"
			reward_label.text = "+%d Gems" % reward_data.amount
		"lives":
			icon_text = "❤️"
			reward_label.text = "+%d Lives" % reward_data.amount
		"booster":
			icon_text = "🚀"
			reward_label.text = "Booster Unlocked!"
		"stars":
			icon_text = "⭐"
			reward_label.text = "%d Stars!" % reward_data.amount
		_:
			icon_text = "🎁"
			reward_label.text = "Reward!"

	# Update description
	if reward_data.description != "":
		description_label.text = reward_data.description
		description_label.visible = true
	else:
		description_label.visible = false

	# Create icon label
	for child in icon_container.get_children():
		child.queue_free()

	var icon_label = Label.new()
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

