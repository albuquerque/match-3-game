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

var NodeResolvers = null

func _ensure_resolvers():
	if NodeResolvers == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL:
			NodeResolvers = s
		else:
			NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

func _ready():
	print("LevelProgress scene is ready.")
	_ensure_resolvers()

	# Check if we're showing results or route map using GameRunState snapshot
	if typeof(GameRunState) != TYPE_NIL and (GameRunState.last_level_score > 0 or GameRunState.last_level_number > 0):
		show_level_results()
	else:
		setup_route_map()

func show_level_results():
	print("Showing level results...")
	var game_manager = NodeResolvers._get_gm()

	# Hide route map, show result panel
	if route_map:
		route_map.visible = false
	if result_panel:
		result_panel.visible = true

		# Set result title from GameRunState
		if GameRunState.last_level_won:
			result_title.text = "Level %d Complete!" % GameRunState.last_level_number
			result_title.modulate = Color.GREEN
		else:
			result_title.text = "Level %d Failed" % GameRunState.last_level_number
			result_title.modulate = Color.RED

		# Set score info
		score_label.text = "Score: %d" % GameRunState.last_level_score
		target_label.text = "Target: %d" % GameRunState.last_level_target

		if GameRunState.last_level_won:
			moves_label.text = "Moves Left: %d" % GameRunState.last_level_moves_left
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

	var level_manager = NodeResolvers._get_lm()
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
	var level_manager = NodeResolvers._get_lm()
	if level_manager:
		print("LevelManager found. Setting current level to: %d" % level)
		level_manager.set_current_level(level)
		print("Transitioning to MainGame scene...")
		get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
	else:
		print("Error: LevelManager not found!")

func _on_next_level_pressed():
    print("Next level button pressed")
    # Use GameStateBridge to attempt level load and reset flags
    var bridge = load("res://games/match3/services/GameStateBridge.gd")
    if bridge != null and bridge.has_method("initialize_game"):
        GameRunState.level_transitioning = false
        bridge.initialize_game()
        get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
    else:
        var gm = NodeResolvers._get_gm()
        if gm:
            gm.level_transitioning = false
            gm.load_current_level()
            get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_restart_level_pressed():
    print("Restart level button pressed")
    var level_manager = NodeResolvers._get_lm()
    if level_manager:
        level_manager.set_current_level(GameRunState.last_level_number - 1)
    # Use bridge to load
    var bridge = load("res://games/match3/services/GameStateBridge.gd")
    if bridge != null and bridge.has_method("initialize_game"):
        GameRunState.level_transitioning = false
        bridge.initialize_game()
        get_tree().change_scene_to_file("res://scenes/MainGame.tscn")
    else:
        var gm = NodeResolvers._get_gm()
        if gm:
            gm.level_transitioning = false
            gm.load_current_level()
            get_tree().change_scene_to_file("res://scenes/MainGame.tscn")

func _on_menu_pressed():
	print("Menu button pressed")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
