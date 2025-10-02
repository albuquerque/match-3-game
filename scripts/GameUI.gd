extends Control
class_name GameUI

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

var is_paused = false

func _ready():
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

	# Initialize UI
	game_over_panel.visible = false
	level_complete_panel.visible = false
	update_display()

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
