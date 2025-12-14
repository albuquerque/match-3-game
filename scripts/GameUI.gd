extends Control
class_name GameUI

# Currency UI
@onready var coins_label = $VBoxContainer/CurrencyPanel/HBoxContainer/CoinsLabel
@onready var gems_label = $VBoxContainer/CurrencyPanel/HBoxContainer/GemsLabel
@onready var lives_label = $VBoxContainer/CurrencyPanel/HBoxContainer/LivesLabel

# Game UI
@onready var score_label = $VBoxContainer/TopPanel/ScoreContainer/ScoreLabel
@onready var level_label = $VBoxContainer/TopPanel/LevelContainer/LevelLabel
@onready var moves_label = $VBoxContainer/TopPanel/MovesContainer/MovesLabel
@onready var target_progress = $VBoxContainer/TopPanel/TargetContainer/TargetProgress
@onready var target_label = $VBoxContainer/TopPanel/TargetContainer/TargetLabel

@onready var game_over_panel = $GameOverPanel
@onready var level_complete_panel = $LevelCompletePanel
@onready var restart_button = $GameOverPanel/VBoxContainer/RestartButton
@onready var continue_button = $LevelCompletePanel/VBoxContainer/ContinueButton
@onready var menu_button = $VBoxContainer/BottomPanel/MenuButton
@onready var pause_button = $VBoxContainer/BottomPanel/PauseButton

@onready var final_score_label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var level_complete_score = $LevelCompletePanel/VBoxContainer/LevelScoreLabel

# Phase 2: Shop and Dialogs
@onready var shop_button = $VBoxContainer/BottomPanel/ShopButton
@onready var shop_ui = $ShopUI
@onready var out_of_lives_dialog = $OutOfLivesDialog
@onready var reward_notification = $RewardNotification

var is_paused = false

func _ready():
	# Connect to RewardManager signals
	RewardManager.connect("coins_changed", _on_coins_changed)
	RewardManager.connect("gems_changed", _on_gems_changed)
	RewardManager.connect("lives_changed", _on_lives_changed)

	# Connect to GameManager signals
	GameManager.connect("score_changed", _on_score_changed)
	GameManager.connect("level_changed", _on_level_changed)
	GameManager.connect("moves_changed", _on_moves_changed)
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("level_complete", _on_level_complete)

	# Connect UI buttons
	restart_button.connect("pressed", _on_restart_pressed)
	continue_button.connect("pressed", _on_continue_pressed)
	menu_button.connect("pressed", _on_menu_pressed)
	pause_button.connect("pressed", _on_pause_pressed)

	# Phase 2: Shop button
	if shop_button:
		shop_button.connect("pressed", _on_shop_pressed)

	# Connect shop and dialog signals
	if shop_ui:
		shop_ui.connect("shop_closed", _on_shop_closed)
		shop_ui.connect("item_purchased", _on_item_purchased)

	if out_of_lives_dialog:
		out_of_lives_dialog.connect("refill_requested", _on_refill_requested)
		out_of_lives_dialog.connect("dialog_closed", _on_out_of_lives_closed)

	# Initialize UI
	game_over_panel.visible = false
	level_complete_panel.visible = false
	update_display()
	update_currency_display()

	# Check if player has lives
	if RewardManager.get_lives() <= 0:
		_show_out_of_lives_dialog()

func update_display():
	score_label.text = "Score: %d" % GameManager.score
	level_label.text = "Level %d" % GameManager.level
	moves_label.text = "Moves: %d" % GameManager.moves_left

	# Update progress bar
	var progress = float(GameManager.score) / float(GameManager.target_score)
	target_progress.value = min(progress * 100, 100)
	target_label.text = "Target: %d" % GameManager.target_score

func _on_score_changed(new_score: int):
	score_label.text = "Score: %d" % new_score

	# Update progress
	var progress = float(new_score) / float(GameManager.target_score)
	target_progress.value = min(progress * 100, 100)

	# Animate score increase
	animate_score_change()

func _on_level_changed(new_level: int):
	level_label.text = "Level %d" % new_level
	target_label.text = "Target: %d" % GameManager.target_score
	target_progress.value = 0

	# Animate level change
	animate_level_change()

func _on_moves_changed(moves_left: int):
	moves_label.text = "Moves: %d" % moves_left

	# Warning color when low on moves
	if moves_left <= 5:
		moves_label.modulate = Color.RED
		animate_low_moves_warning()
	else:
		moves_label.modulate = Color.WHITE

func _on_game_over():
	final_score_label.text = "Final Score: %d" % GameManager.score
	show_panel(game_over_panel)

func _on_level_complete():
	level_complete_score.text = "Level %d Complete!\nScore: %d" % [GameManager.level - 1, GameManager.score]
	show_panel(level_complete_panel)

func show_panel(panel: Control):
	panel.visible = true
	panel.modulate = Color.TRANSPARENT

	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)

func hide_panel(panel: Control):
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(func(): panel.visible = false)

func _on_restart_pressed():
	hide_panel(game_over_panel)
	await get_tree().create_timer(0.3).timeout
	restart_game()

func _on_continue_pressed():
	hide_panel(level_complete_panel)

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_pause_pressed():
	toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		pause_button.text = "Resume"
	else:
		pause_button.text = "Pause"

func restart_game():
	var game_board = get_node("../GameBoard")
	if game_board:
		game_board.restart_game()
	update_display()

func animate_score_change():
	var tween = create_tween()
	tween.tween_property(score_label, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(score_label, "modulate", Color.WHITE, 0.1)

func animate_level_change():
	var tween = create_tween()
	tween.tween_property(level_label, "scale", Vector2(1.3, 1.3), 0.2)
	tween.tween_property(level_label, "scale", Vector2.ONE, 0.2)

func animate_low_moves_warning():
	var tween = create_tween()
	tween.set_loops(3)
	tween.tween_property(moves_label, "scale", Vector2(1.2, 1.2), 0.2)
	tween.tween_property(moves_label, "scale", Vector2.ONE, 0.2)

# ============================================
# Currency Display Functions
# ============================================

func update_currency_display():
	coins_label.text = "💰 %d" % RewardManager.get_coins()
	gems_label.text = "💎 %d" % RewardManager.get_gems()

	var lives = RewardManager.get_lives()
	var max_lives = RewardManager.MAX_LIVES
	lives_label.text = "❤️ %d/%d" % [lives, max_lives]

func _on_coins_changed(new_amount: int):
	coins_label.text = "💰 %d" % new_amount
	animate_currency_change(coins_label)

func _on_gems_changed(new_amount: int):
	gems_label.text = "💎 %d" % new_amount
	animate_currency_change(gems_label)

func _on_lives_changed(new_amount: int):
	var max_lives = RewardManager.MAX_LIVES
	lives_label.text = "❤️ %d/%d" % [new_amount, max_lives]
	animate_currency_change(lives_label)

func animate_currency_change(label: Label):
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)
	tween.tween_property(label, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)

# ============================================
# Phase 2: Shop and Dialog Functions
# ============================================

func _on_shop_pressed():
	"""Open the shop"""
	if shop_ui:
		shop_ui.show_shop()
		print("[GameUI] Shop opened")

func _on_shop_closed():
	"""Handle shop close"""
	print("[GameUI] Shop closed")

func _on_item_purchased(item_type: String, cost_type: String, cost_amount: int):
	"""Handle item purchase from shop"""
	print("[GameUI] Purchased: %s for %d %s" % [item_type, cost_amount, cost_type])

	# Show reward notification
	if reward_notification:
		if item_type == "lives_refill":
			reward_notification.show_reward("lives", 5, "Lives refilled!")
		else:
			reward_notification.show_reward("booster", 1, "%s booster added!" % item_type.capitalize())

func _show_out_of_lives_dialog():
	"""Show the out of lives dialog"""
	if out_of_lives_dialog:
		out_of_lives_dialog.show_dialog()
		print("[GameUI] Showing out of lives dialog")

func _on_refill_requested(method: String):
	"""Handle life refill from dialog"""
	print("[GameUI] Lives refilled via: %s" % method)

	# Show success notification
	if reward_notification:
		reward_notification.show_reward("lives", RewardManager.get_lives(), "Lives restored!")

	# DON'T automatically start game - let the dialog close naturally
	# The player can see their lives increased and manually start when ready
	print("[GameUI] Life granted. Player now has %d lives" % RewardManager.get_lives())

func _on_out_of_lives_closed():
	"""Handle out of lives dialog close"""
	print("[GameUI] Out of lives dialog closed")

	# If still no lives, go back to menu
	if RewardManager.get_lives() <= 0:
		print("[GameUI] Still no lives, returning to menu")
		await get_tree().create_timer(0.5).timeout
		_on_menu_pressed()
