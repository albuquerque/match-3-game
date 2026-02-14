extends "res://scripts/ui/ScreenBase.gd"

signal start_pressed
signal booster_selected(booster_id: String)
signal exchange_pressed
signal settings_pressed
signal achievements_pressed
signal map_pressed

func _ready():
	# Call ScreenBase ready setup
	ensure_fullscreen()
	# Create a simple layout programmatically so the scene file isn't required here
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.9
	# don't set margins/offsets here; anchors are sufficient
	add_child(vbox)

	var level_label = Button.new()
	level_label.name = "LevelButton"
	level_label.text = "Level: --"
	ThemeManager.apply_bangers_font_to_button(level_label, 36)
	# Clicking the level button starts the level
	level_label.pressed.connect(Callable(self, "_on_start_pressed"))
	vbox.add_child(level_label)

	# Add lives display
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(lives_label, 20)
	vbox.add_child(lives_label)

	# Hide lives display - no longer using lives system
	lives_label.visible = false

	# Description label below level button
	var desc_label = Label.new()
	desc_label.name = "LevelDescription"
	desc_label.text = ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(desc_label, 18)
	vbox.add_child(desc_label)

	var actions_h = HBoxContainer.new()
	actions_h.name = "ActionsH"
	vbox.add_child(actions_h)

	var start_btn = Button.new()
	start_btn.name = "StartButton"
	start_btn.text = "Start Level"
	start_btn.custom_minimum_size = Vector2(200, 64)
	ThemeManager.apply_bangers_font_to_button(start_btn, 24)
	start_btn.pressed.connect(Callable(self, "_on_start_pressed"))
	actions_h.add_child(start_btn)

	var exchange_btn = Button.new()
	exchange_btn.name = "ExchangeButton"
	exchange_btn.text = "Exchange Gems"
	exchange_btn.custom_minimum_size = Vector2(200, 64)
	ThemeManager.apply_bangers_font_to_button(exchange_btn, 20)
	exchange_btn.pressed.connect(Callable(self, "_on_exchange_pressed"))
	actions_h.add_child(exchange_btn)


	# Create a second row for navigation buttons
	var settings_h = HBoxContainer.new()
	settings_h.name = "SettingsH"
	settings_h.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(settings_h)

	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙️ Settings"
	settings_btn.custom_minimum_size = Vector2(150, 48)
	ThemeManager.apply_bangers_font_to_button(settings_btn, 16)
	settings_btn.pressed.connect(Callable(self, "_on_settings_pressed"))
	settings_h.add_child(settings_btn)

	var map_btn = Button.new()
	map_btn.name = "MapButton"
	map_btn.text = "🗺️ Map"
	map_btn.custom_minimum_size = Vector2(150, 48)
	ThemeManager.apply_bangers_font_to_button(map_btn, 16)
	map_btn.pressed.connect(Callable(self, "_on_map_pressed"))
	settings_h.add_child(map_btn)

	var achievements_btn = Button.new()
	achievements_btn.name = "AchievementsButton"
	achievements_btn.text = "🏆 Achievements"
	achievements_btn.custom_minimum_size = Vector2(150, 48)
	ThemeManager.apply_bangers_font_to_button(achievements_btn, 16)
	achievements_btn.pressed.connect(Callable(self, "_on_achievements_pressed"))
	settings_h.add_child(achievements_btn)

	# Lives system removed - no checks needed
	print("[StartPage] Start button enabled - no lives restrictions")
	# ensure hidden until explicitly shown
	visible = false
	modulate = Color(1,1,1,0)

func set_level_info(level_number: int, description: String):
	var btn = get_node_or_null("VBox/LevelButton")
	if btn and btn is Button:
		btn.text = "Level %d" % level_number
	var dl = get_node_or_null("VBox/LevelDescription")
	if dl and dl is Label:
		dl.text = description

func close():
	hide_screen()
	# queue_free delegated to caller when desired

func _on_start_pressed():
	emit_signal("start_pressed")

func _on_booster_button_pressed(bid: String):
	emit_signal("booster_selected", bid)

func _on_exchange_pressed():
	emit_signal("exchange_pressed")

func _on_settings_pressed():
	emit_signal("settings_pressed")

func _on_map_pressed():
	emit_signal("map_pressed")

func _on_achievements_pressed():
	emit_signal("achievements_pressed")
