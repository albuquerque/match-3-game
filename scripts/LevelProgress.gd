extends Control

signal level_selected(level)

@onready var route_map = $RouteMap
@onready var level_button_template = $RouteMap/LevelButtonTemplate

# Result panel nodes
@onready var result_panel = $ResultPanel
@onready var result_title = $ResultPanel/VBoxContainer/ResultTitle
@onready var score_label = $ResultPanel/VBoxContainer/ScoreLabel
@onready var target_label = $ResultPanel/VBoxContainer/TargetLabel
@onready var moves_label = $ResultPanel/VBoxContainer/MovesLabel
@onready var next_level_button = $ResultPanel/VBoxContainer/NextLevelButton
@onready var restart_button = $ResultPanel/VBoxContainer/RestartButton
@onready var menu_button = $ResultPanel/VBoxContainer/MenuButton

func _ready():
	print("LevelProgress scene is ready.")

	# Check if we're showing results or route map
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager and (game_manager.last_level_score > 0 or game_manager.last_level_number > 0):
		# Show results
		show_level_results()
	else:
		# Show route map for level selection
		setup_route_map()

func show_level_results():
	print("Showing level results...")
	var game_manager = get_node("/root/GameManager")

	# Hide route map, show result panel
	if route_map:
		route_map.visible = false
	if result_panel:
		result_panel.visible = true

		# Set result title
		if game_manager.last_level_won:
			result_title.text = "Level %d Complete!" % game_manager.last_level_number
			result_title.modulate = Color.GREEN
		else:
			result_title.text = "Level %d Failed" % game_manager.last_level_number
			result_title.modulate = Color.RED

		# Set score info
		score_label.text = "Score: %d" % game_manager.last_level_score
		target_label.text = "Target: %d" % game_manager.last_level_target

		if game_manager.last_level_won:
			moves_label.text = "Moves Left: %d" % game_manager.last_level_moves_left
		else:
			moves_label.text = "Out of Moves!"

		# Show appropriate buttons
		if game_manager.last_level_won:
			next_level_button.visible = true
			restart_button.visible = false
			next_level_button.connect("pressed", _on_next_level_pressed)
		else:
			next_level_button.visible = false
			restart_button.visible = true
			restart_button.connect("pressed", _on_restart_level_pressed)

		menu_button.connect("pressed", _on_menu_pressed)

func setup_route_map():
	print("Setting up route map...")

	# Hide result panel if it exists
	if result_panel:
		result_panel.visible = false
	if route_map:
		route_map.visible = true

	var level_manager = get_node("/root/LevelManager")
	if not level_manager:
		print("Error: LevelManager not found!")
		return

	print("Debug: LevelManager found. Levels available: ", level_manager.levels.size())
	for i in range(level_manager.levels.size()):
		var button = level_button_template.duplicate()
		button.text = "Level %d" % (i + 1)
		button.visible = true
		button.connect("pressed", Callable(self, "_on_level_button_pressed").bind(i))
		route_map.add_child(button)
		print("Debug: Added button for Level %d" % (i + 1))

func _on_level_button_pressed(level):
	print("Button pressed for Level: %d" % (level + 1))
	emit_signal("level_selected", level)
	# Load the selected level
	var level_manager = get_node("/root/LevelManager")
	if level_manager:
		print("LevelManager found. Setting current level to: %d" % level)
		level_manager.set_current_level(level)
		print("Transitioning to MainGame scene...")
		get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
	else:
		print("Error: LevelManager not found!")

func _on_next_level_pressed():
	print("Next level button pressed")
	# Level already advanced in GameManager, just load the game
	var game_manager = get_node("/root/GameManager")
	game_manager.level_transitioning = false
	game_manager.load_current_level()
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_restart_level_pressed():
	print("Restart level button pressed")
	var game_manager = get_node("/root/GameManager")
	var level_manager = get_node("/root/LevelManager")

	# Reset to the failed level
	level_manager.set_current_level(game_manager.last_level_number - 1)
	game_manager.level_transitioning = false
	game_manager.load_current_level()
	get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_menu_pressed():
	print("Menu button pressed")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
