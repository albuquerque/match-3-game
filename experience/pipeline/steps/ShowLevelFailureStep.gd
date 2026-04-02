extends "res://experience/pipeline/PipelineStep.gd"

## ShowLevelFailureStep
## Shows level failure screen with retry/quit options
## Follows ARCHITECTURE_GUARDRAILS: < 150 lines, atomic step

var level_number: int = 0
var score: int = 0
var target: int = 0
var moves_used: int = 0
var failure_screen: Control = null
var _retry_pressed: bool = false
var _quit_pressed: bool = false

func _init(lvl_num: int = 0):
	super("show_level_failure")
	level_number = lvl_num

func execute(context) -> bool:
	"""Show level failure screen and wait for user input"""
	print("[ShowLevelFailureStep] Level %d failed" % level_number)

	score = context.get_result("score", 0)
	target = context.get_result("target_score", 0)
	moves_used = context.get_result("moves_used", 0)

	_create_failure_screen(context)

	# Wait for user input using context's tree
	var game_ui = context.game_ui
	if not game_ui:
		step_completed.emit(true)
		return false

	while not _retry_pressed and not _quit_pressed:
		await game_ui.get_tree().create_timer(0.1).timeout

	# Store user choice
	if _retry_pressed:
		context.set_result("retry_level", true)
		context.set_result("return_to_map", false)
		print("[ShowLevelFailureStep] User chose RETRY")
	else:
		context.set_result("retry_level", false)
		context.set_result("return_to_map", true)
		print("[ShowLevelFailureStep] User chose EXIT TO MAP")

	_cleanup_screen()
	step_completed.emit(true)
	return true

func _create_failure_screen(context):
	"""Create failure UI overlay"""
	var game_ui = context.game_ui
	if not game_ui:
		_quit_pressed = true
		return

	# Create fullscreen overlay
	failure_screen = Control.new()
	failure_screen.name = "LevelFailureScreen"
	failure_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	failure_screen.z_index = 1000
	failure_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	game_ui.add_child(failure_screen)

	# Semi-transparent background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	failure_screen.add_child(bg)

	# Centered panel
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 400)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -300
	panel.offset_top = -200
	panel.offset_right = 300
	panel.offset_bottom = 200
	failure_screen.add_child(panel)

	# Style panel with red border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
	style.border_width_left = 4
	style.border_width_right = 4
	style.border_width_top = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.8, 0.2, 0.2, 1.0)
	style.corner_radius_top_left = 15
	style.corner_radius_top_right = 15
	style.corner_radius_bottom_left = 15
	style.corner_radius_bottom_right = 15
	panel.add_theme_stylebox_override("panel", style)

	# Content
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = tr("UI_LEVEL_FAILED")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Stats
	var stats = Label.new()
	stats.text = tr("UI_SCORE_STATS") % [score, target, moves_used]
	stats.add_theme_font_size_override("font_size", 22)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats)

	# Retry button
	var retry_btn = Button.new()
	retry_btn.text = tr("UI_RETRY_LEVEL")
	retry_btn.custom_minimum_size = Vector2(250, 60)
	retry_btn.add_theme_font_size_override("font_size", 24)
	retry_btn.pressed.connect(_on_retry_pressed)

	var hbox1 = HBoxContainer.new()
	hbox1.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox1.add_child(retry_btn)
	vbox.add_child(hbox1)

	# Exit button
	var quit_btn = Button.new()
	quit_btn.text = tr("UI_EXIT_TO_MAP")
	quit_btn.custom_minimum_size = Vector2(250, 50)
	quit_btn.add_theme_font_size_override("font_size", 20)
	quit_btn.pressed.connect(_on_quit_pressed)

	var hbox2 = HBoxContainer.new()
	hbox2.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox2.add_child(quit_btn)
	vbox.add_child(hbox2)

func _on_retry_pressed():
	"""Handle retry button press"""
	_retry_pressed = true

func _on_quit_pressed():
	"""Handle quit button press"""
	_quit_pressed = true

func _cleanup_screen():
	"""Remove failure screen from scene"""
	if is_instance_valid(failure_screen):
		failure_screen.queue_free()
		failure_screen = null

func cleanup():
	"""Pipeline cleanup"""
	_cleanup_screen()
