extends Control
class_name SimpleRewardUI

## Simple Reward UI for Phase 2
## Displays score, stars, rewards and a Continue button

signal continue_pressed

@onready var background: ColorRect
@onready var title_label: Label
@onready var score_label: Label
@onready var stars_container: HBoxContainer
@onready var rewards_label: Label
@onready var continue_button: Button

var level_number: int = 0
var score: int = 0
var stars: int = 0
var coins: int = 0
var gems: int = 0

# Theme colors
var title_color: Color = Color(1.0, 0.9, 0.3, 1.0)  # Gold
var text_color: Color = Color(1.0, 1.0, 1.0, 1.0)  # White

func _ready():
	# Get theme colors from ThemeManager if available
	if ThemeManager:
		var theme_name = ThemeManager.get_theme_name()
		if theme_name == "legacy":
			title_color = Color(1.0, 0.8, 0.2, 1.0)  # Warm gold
			text_color = Color(0.95, 0.9, 0.8, 1.0)  # Warm white

	_create_ui()
	visible = false
	z_index = 150  # Above everything

func _create_ui():
	"""Create a simple but functional reward display"""

	# Background
	background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.85)  # Darker overlay
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	add_child(background)

	# Center container
	var center = CenterContainer.new()
	center.anchor_right = 1.0
	center.anchor_bottom = 1.0
	background.add_child(center)

	# Main panel - larger and more prominent
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 500)  # Larger panel
	center.add_child(panel)

	# VBox for content with more spacing
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 30)  # More spacing
	panel.add_child(vbox)

	# Add top padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(top_spacer)

	# Title - larger and more prominent
	title_label = Label.new()
	title_label.text = "Level Complete!"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 48)  # Bigger title
	title_label.add_theme_color_override("font_color", title_color)  # Theme color
	vbox.add_child(title_label)

	# Score - larger font
	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 32)  # Bigger score
	score_label.add_theme_color_override("font_color", text_color)  # Theme color
	vbox.add_child(score_label)

	# Stars - larger
	stars_container = HBoxContainer.new()
	stars_container.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_container.add_theme_constant_override("separation", 20)  # More spacing between stars
	vbox.add_child(stars_container)

	for i in range(3):
		var star = Label.new()
		star.text = "⭐"
		star.add_theme_font_size_override("font_size", 64)  # Bigger stars
		stars_container.add_child(star)

	# Rewards - larger font
	rewards_label = Label.new()
	rewards_label.text = "Rewards: 0 coins, 0 gems"
	rewards_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rewards_label.add_theme_font_size_override("font_size", 28)  # Bigger rewards text
	rewards_label.add_theme_color_override("font_color", text_color)  # Theme color
	vbox.add_child(rewards_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)  # More space before button
	vbox.add_child(spacer)

	# Continue button - larger and more prominent
	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(300, 80)  # Much larger button
	continue_button.add_theme_font_size_override("font_size", 32)  # Bigger button text
	continue_button.pressed.connect(_on_continue_pressed)
	continue_button.mouse_entered.connect(_on_button_hover)
	continue_button.mouse_exited.connect(_on_button_unhover)

	var button_container = CenterContainer.new()
	button_container.add_child(continue_button)
	vbox.add_child(button_container)

	# Bottom padding
	var bottom_spacer = Control.new()
	bottom_spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_spacer)

	print("[SimpleRewardUI] UI created")

func show_rewards(data: Dictionary):
	"""Display the reward screen with given data"""
	level_number = data.get("level_number", 0)
	score = data.get("score", 0)
	stars = data.get("stars", 0)
	coins = data.get("coins", 0)
	gems = data.get("gems", 0)

	print("[SimpleRewardUI] Showing rewards - Level: %d, Score: %d, Stars: %d, Coins: %d, Gems: %d" % [level_number, score, stars, coins, gems])

	# Update static UI elements
	title_label.text = "🎉 Level %d Complete! 🎉" % level_number
	score_label.text = "Score: %d" % score

	# Start with 0 rewards shown
	rewards_label.text = "Rewards: 0 coins, 0 gems"

	# Dim all stars initially
	for i in range(stars_container.get_child_count()):
		var star_label = stars_container.get_child(i)
		star_label.modulate = Color(0.3, 0.3, 0.3, 1)
		star_label.scale = Vector2(0.1, 0.1)  # Start small

	# Animate in
	modulate = Color(1, 1, 1, 0)  # Start transparent
	visible = true

	# Fade in animation
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

	# After fade-in, start animating stars and rewards
	tween.tween_callback(_animate_stars.bind(stars))
	tween.tween_callback(_animate_rewards.bind(coins, gems))

	print("[SimpleRewardUI] Screen now visible with fade-in")

func _animate_stars(star_count: int):
	"""Animate stars popping in one by one"""
	for i in range(star_count):
		var star_label = stars_container.get_child(i)

		# Delay based on star index
		await get_tree().create_timer(i * 0.15).timeout

		# Create tween AFTER delay
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)

		# Pop in with scale and brighten
		star_label.modulate = Color(1, 1, 1, 1)
		tween.tween_property(star_label, "scale", Vector2(1, 1), 0.2)

		# Play star pop sound
		if AudioManager:
			AudioManager.play_sfx("match")  # Use match chime for stars

func _animate_rewards(target_coins: int, target_gems: int):
	"""Count up coins and gems from 0 to target values"""
	var duration = 0.8  # Total animation time in seconds

	# Play counting start sound
	if AudioManager:
		AudioManager.play_sfx("combo")

	# Count up using a simple loop
	var steps = 30  # Number of steps in animation
	var step_duration = duration / steps

	for i in range(steps + 1):
		var progress = float(i) / float(steps)
		var current_coins = int(target_coins * progress)
		var current_gems = int(target_gems * progress)
		rewards_label.text = "Rewards: %d coins, %d gems" % [current_coins, current_gems]
		await get_tree().create_timer(step_duration).timeout

	# Ensure final values are exact
	rewards_label.text = "Rewards: %d coins, %d gems" % [target_coins, target_gems]

	# Play completion chime
	if AudioManager:
		AudioManager.play_sfx("combo")

func hide_screen():
	"""Hide the reward screen"""
	visible = false
	print("[SimpleRewardUI] Screen hidden")

func _on_continue_pressed():
	"""Handle Continue button press"""
	print("[SimpleRewardUI] Continue pressed!")

	# Play button click sound
	if AudioManager:
		AudioManager.play_sfx("ui_click")

	continue_pressed.emit()
	hide_screen()

func _on_button_hover():
	"""Handle button mouse enter - scale up slightly"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(continue_button, "scale", Vector2(1.05, 1.05), 0.1)

func _on_button_unhover():
	"""Handle button mouse exit - scale back to normal"""
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(continue_button, "scale", Vector2(1, 1), 0.1)

