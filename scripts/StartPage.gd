extends Control

signal start_pressed
signal booster_selected(booster_id: String)
signal exchange_pressed
signal settings_pressed

func _ready():
	# Fullscreen anchors
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	visible = true

	# Add opaque background so StartPage is an independent screen
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.04, 0.04, 0.04, 1.0)
	bg.anchor_left = 0
	bg.anchor_top = 0
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

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
	level_label.add_theme_font_size_override("font_size", 36)
	# Clicking the level button starts the level
	level_label.pressed.connect(Callable(self, "_on_start_pressed"))
	vbox.add_child(level_label)

	# Add lives display
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lives_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(lives_label)

	# Update lives display
	var rm = get_node_or_null('/root/RewardManager')
	var lives = 0
	if rm:
		lives = rm.get_lives()
	lives_label.text = "Lives: %d / %d" % [lives, rm.MAX_LIVES if rm else 5]
	if lives <= 0:
		lives_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	else:
		lives_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))

	# Description label below level button
	var desc_label = Label.new()
	desc_label.name = "LevelDescription"
	desc_label.text = ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(desc_label)

	var actions_h = HBoxContainer.new()
	actions_h.name = "ActionsH"
	vbox.add_child(actions_h)

	var start_btn = Button.new()
	start_btn.name = "StartButton"
	start_btn.text = "Start Level"
	start_btn.custom_minimum_size = Vector2(200, 64)
	start_btn.pressed.connect(Callable(self, "_on_start_pressed"))
	actions_h.add_child(start_btn)

	var exchange_btn = Button.new()
	exchange_btn.name = "ExchangeButton"
	exchange_btn.text = "Exchange Gems"
	exchange_btn.custom_minimum_size = Vector2(200, 64)
	exchange_btn.pressed.connect(Callable(self, "_on_exchange_pressed"))
	actions_h.add_child(exchange_btn)

	# Mute toggle button using TextureButton with volume icon
	var volume_icon = load("res://textures/legacy/icons/volume.png")
	var mute_btn = TextureButton.new()
	mute_btn.name = "MuteButton"
	mute_btn.toggle_mode = true
	mute_btn.button_pressed = true  # Start as unmuted
	mute_btn.texture_normal = volume_icon
	mute_btn.ignore_texture_size = true
	mute_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	mute_btn.custom_minimum_size = Vector2(48, 48)
	mute_btn.toggled.connect(_on_mute_toggled)

	# Place mute button to the right in the actions HBox
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_h.add_child(spacer)
	actions_h.add_child(mute_btn)

	# Load persisted mute state if present from RewardManager
	var muted = false
	if rm:
		muted = rm.audio_muted
	else:
		if ProjectSettings.has_setting("match3/audio/muted"):
			muted = ProjectSettings.get_setting("match3/audio/muted")

	if muted:
		mute_btn.set_pressed(true)
		# Apply to AudioManager
		var am = get_node_or_null('/root/AudioManager')
		if am:
			am.set_music_enabled(false)
			am.set_sfx_enabled(false)

	# Update initial visual state
	_update_mute_visual(mute_btn, not muted)

	# Also add a prominent top-right mute toggle placed in a CanvasLayer so it's always visible
	var mute_layer = CanvasLayer.new()
	mute_layer.name = "MuteLayer"
	add_child(mute_layer)

	var top_mute = TextureButton.new()
	top_mute.name = "TopMuteButton"
	top_mute.toggle_mode = true
	top_mute.button_pressed = mute_btn.button_pressed
	top_mute.texture_normal = volume_icon
	top_mute.ignore_texture_size = true
	top_mute.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	top_mute.custom_minimum_size = Vector2(48, 48)
	top_mute.toggled.connect(_on_mute_toggled)

	# Position it relative to the viewport size so it's visible
	var vp_size = get_viewport().get_visible_rect().size
	top_mute.position = Vector2(vp_size.x - 72, 12)
	mute_layer.add_child(top_mute)

	# Update initial visual state
	_update_mute_visual(top_mute, not muted)

	# After creating actions_h and exchange_btn, add Settings button
	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(140, 48)
	settings_btn.pressed.connect(Callable(self, "_on_settings_pressed"))
	actions_h.add_child(settings_btn)

	# Check if player has lives and update UI accordingly (lives already retrieved above)
	if lives <= 0:
		# No lives - change button text but keep it clickable so dialog can show
		start_btn.text = "Out of Lives - Refill?"

		# Add a message label to inform the user
		var no_lives_label = Label.new()
		no_lives_label.text = "Click the button above to refill your lives!"
		no_lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_lives_label.add_theme_color_override("font_color", Color(1, 0.7, 0.3))
		no_lives_label.add_theme_font_size_override("font_size", 16)
		vbox.add_child(no_lives_label)
		vbox.move_child(no_lives_label, 2)  # Place after description

		print("[StartPage] No lives available - button will trigger refill dialog")
	else:
		print("[StartPage] Player has %d lives - Start button enabled" % lives)

func set_level_info(level_number: int, description: String):
	var btn = get_node_or_null("VBox/LevelButton")
	if btn and btn is Button:
		btn.text = "Level %d" % level_number
	var dl = get_node_or_null("VBox/LevelDescription")
	if dl and dl is Label:
		dl.text = description

func close():
	visible = false
	queue_free()

func _on_start_pressed():
	emit_signal("start_pressed")

func _on_booster_button_pressed(bid: String):
	emit_signal("booster_selected", bid)

func _on_exchange_pressed():
	emit_signal("exchange_pressed")

func _on_settings_pressed():
	emit_signal("settings_pressed")

func _on_mute_toggled(pressed: bool):
	# pressed=true means muted -> set enabled=false
	var am = get_node_or_null('/root/AudioManager')
	if am:
		am.set_music_enabled(not pressed)
		am.set_sfx_enabled(not pressed)

	# persist in RewardManager
	var rm2 = get_node_or_null('/root/RewardManager')
	if rm2:
		rm2.audio_muted = pressed
		rm2.audio_music_enabled = not pressed
		rm2.audio_sfx_enabled = not pressed
		rm2.save_progress()
	else:
		ProjectSettings.set_setting("match3/audio/muted", pressed)
		ProjectSettings.save()

	# Sync both UI elements and update visuals
	var mb = get_node_or_null("VBox/ActionsH/MuteButton")
	if mb and mb is TextureButton:
		mb.set_pressed(pressed)
		_update_mute_visual(mb, not pressed)

	var tm = get_node_or_null("MuteLayer/TopMuteButton")
	if tm and tm is TextureButton:
		tm.set_pressed(pressed)
		_update_mute_visual(tm, not pressed)


# Helper to update mute button visual when state changes
func _update_mute_visual(mute_btn: TextureButton, enabled: bool):
	if not mute_btn:
		return

	# Modulate the icon based on state - dim when disabled/muted
	if enabled:
		mute_btn.modulate = Color(1, 1, 1, 1)
	else:
		mute_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Add or update cross overlay for muted state
	var cross = mute_btn.get_node_or_null("CrossOverlay")
	if not enabled:
		if not cross:
			cross = Label.new()
			cross.name = "CrossOverlay"
			cross.text = "✖"
			cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cross.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
			cross.add_theme_font_size_override("font_size", 28)
			cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cross.anchor_left = 0
			cross.anchor_top = 0
			cross.anchor_right = 1
			cross.anchor_bottom = 1
			mute_btn.add_child(cross)
		cross.visible = true
	else:
		if cross:
			cross.visible = false
