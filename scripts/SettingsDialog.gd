extends Panel

@onready var title_label = $VBoxContainer/Title
@onready var close_button = $VBoxContainer/CloseButton
@onready var music_label = $VBoxContainer/MusicHBox/MusicLabel
@onready var music_slider = $VBoxContainer/MusicHBox/MusicSlider
@onready var music_toggle = $VBoxContainer/MusicHBox/MusicToggle
@onready var music_volume_label = $VBoxContainer/MusicHBox/VolumeLabel
@onready var sfx_label = $VBoxContainer/SfxHBox/SfxLabel
@onready var sfx_slider = $VBoxContainer/SfxHBox/SfxSlider
@onready var sfx_toggle = $VBoxContainer/SfxHBox/SfxToggle
@onready var sfx_volume_label = $VBoxContainer/SfxHBox/VolumeLabel

# Vibration toggle (created dynamically)
var vibration_toggle: CheckButton = null

# Language selector (created dynamically)
var language_dropdown: OptionButton = null

const MUSIC_SETTING = "match3/audio/music_volume"
const SFX_SETTING = "match3/audio/sfx_volume"
const MUSIC_ENABLED_SETTING = "match3/audio/music_enabled"
const SFX_ENABLED_SETTING = "match3/audio/sfx_enabled"

func _ready():
	visible = false

	# Set translated labels
	_initialize_ui_labels()

	# Create vibration toggle if on mobile or for testing
	_create_vibration_toggle()

	# Create language selector
	_create_language_selector()

	# Connect close
	close_button.pressed.connect(_on_close_pressed)

	# Prefer reading current runtime state from AudioManager so UI reflects actual game audio
	var am = get_node_or_null('/root/AudioManager')
	var rm = get_node_or_null('/root/RewardManager')

	var initial_music_vol = 70
	var initial_sfx_vol = 80
	var initial_music_enabled = true
	var initial_sfx_enabled = true

	if am:
		# Use live audio manager values as the source of truth
		initial_music_vol = int(clamp(am.music_volume * 100.0, 0, 100))
		initial_sfx_vol = int(clamp(am.sfx_volume * 100.0, 0, 100))
		initial_music_enabled = am.music_enabled
		initial_sfx_enabled = am.sfx_enabled
		# If RewardManager marks the user as muted, reflect that too (but prefer AudioManager)
		if rm and rm.audio_muted:
			initial_music_enabled = false
			initial_sfx_enabled = false
	elif rm:
		# Fallback to saved user progress if AudioManager isn't available yet
		initial_music_vol = int(clamp(rm.audio_music_volume * 100.0, 0, 100))
		initial_sfx_vol = int(clamp(rm.audio_sfx_volume * 100.0, 0, 100))
		initial_music_enabled = rm.audio_music_enabled
		initial_sfx_enabled = rm.audio_sfx_enabled
		if rm.audio_muted:
			initial_music_enabled = false
			initial_sfx_enabled = false

	# Apply to controls (do NOT push these back to AudioManager automatically)
	music_slider.value = initial_music_vol
	sfx_slider.value = initial_sfx_vol
	music_toggle.set_pressed(initial_music_enabled)
	sfx_toggle.set_pressed(initial_sfx_enabled)

	# Update volume labels
	music_volume_label.text = "%d%%" % initial_music_vol
	sfx_volume_label.text = "%d%%" % initial_sfx_vol

	# Update toggle visuals
	_update_toggle_visual(music_toggle, initial_music_enabled)
	_update_toggle_visual(sfx_toggle, initial_sfx_enabled)

	# Connect signals - these will apply only when user interacts
	music_slider.connect("value_changed", Callable(self, "_on_music_slider_changed"))
	music_toggle.toggled.connect(_on_music_toggled)
	sfx_slider.connect("value_changed", Callable(self, "_on_sfx_slider_changed"))
	sfx_toggle.toggled.connect(_on_sfx_toggled)

	# Do NOT call _apply_audio_settings() here to avoid muting the game on open
	# Controls now reflect the current runtime state; changes will be applied by handlers

func _initialize_ui_labels():
	"""Set UI labels with translated text"""
	if title_label:
		title_label.text = tr("UI_SETTINGS")
	if music_label:
		music_label.text = tr("UI_MUSIC")
	if sfx_label:
		sfx_label.text = tr("UI_SFX")
	if close_button:
		close_button.text = tr("UI_CLOSE")

func _create_vibration_toggle():
	"""Create vibration toggle UI dynamically"""
	var vbox = get_node_or_null("VBoxContainer")
	if not vbox:
		print("[SettingsDialog] WARNING: VBoxContainer not found, can't add vibration toggle")
		return

	# Create HBoxContainer for vibration setting
	var vibration_hbox = HBoxContainer.new()
	vibration_hbox.name = "VibrationHBox"

	# Add label
	var label = Label.new()
	label.text = "📳 " + tr("UI_VIBRATION") + ":"
	label.custom_minimum_size = Vector2(150, 0)
	ThemeManager.apply_bangers_font(label, 18)
	vibration_hbox.add_child(label)

	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vibration_hbox.add_child(spacer)

	# Create toggle button
	vibration_toggle = CheckButton.new()
	vibration_toggle.name = "VibrationToggle"
	vibration_toggle.text = tr("UI_ON") if VibrationManager.is_vibration_enabled() else tr("UI_OFF")
	vibration_toggle.button_pressed = VibrationManager.is_vibration_enabled()
	ThemeManager.apply_bangers_font_to_button(vibration_toggle, 16)
	vibration_toggle.toggled.connect(_on_vibration_toggled)
	vibration_hbox.add_child(vibration_toggle)

	# Add to VBox (after SFX controls)
	vbox.add_child(vibration_hbox)
	vbox.move_child(vibration_hbox, vbox.get_child_count() - 2)  # Before close button

	print("[SettingsDialog] Vibration toggle created")

func _create_language_selector():
	"""Create language selector UI dynamically"""
	var vbox = get_node_or_null("VBoxContainer")
	if not vbox:
		print("[SettingsDialog] WARNING: VBoxContainer not found, can't add language selector")
		return

	# Create HBoxContainer for language setting
	var language_hbox = HBoxContainer.new()
	language_hbox.name = "LanguageHBox"

	# Add label
	var label = Label.new()
	label.text = tr("UI_LANGUAGE") + ":"
	label.custom_minimum_size = Vector2(150, 0)
	ThemeManager.apply_bangers_font(label, 18)
	language_hbox.add_child(label)

	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_hbox.add_child(spacer)

	# Create dropdown
	language_dropdown = OptionButton.new()
	language_dropdown.name = "LanguageDropdown"
	language_dropdown.custom_minimum_size = Vector2(150, 0)
	ThemeManager.apply_bangers_font_to_button(language_dropdown, 16)

	# Add language options
	var languages = {
		"en": "English",
		"es": "Español",
		"pt": "Português",
		"fr": "Français"
	}

	var current_locale = TranslationServer.get_locale()
	var selected_index = 0
	var index = 0

	for lang_code in languages.keys():
		language_dropdown.add_item(languages[lang_code])
		language_dropdown.set_item_metadata(index, lang_code)

		if lang_code == current_locale:
			selected_index = index

		index += 1

	language_dropdown.selected = selected_index
	language_dropdown.item_selected.connect(_on_language_changed)
	language_hbox.add_child(language_dropdown)

	# Add to VBox (before close button)
	vbox.add_child(language_hbox)
	vbox.move_child(language_hbox, vbox.get_child_count() - 2)

	print("[SettingsDialog] Language selector created - current locale: %s" % current_locale)

func show_dialog():
	visible = true
	modulate = Color.TRANSPARENT
	var t = create_tween()
	t.tween_property(self, "modulate", Color.WHITE, 0.15)

func _on_close_pressed():
	_save_settings()
	# Ensure saved settings are applied (in case user changed them)
	_apply_audio_settings()
	var t = create_tween()
	t.tween_property(self, "modulate", Color.TRANSPARENT, 0.15)
	t.tween_callback(func(): visible = false)

func _save_settings():
	# Persist to RewardManager save (user://player_progress.json)
	var rm = get_node_or_null('/root/RewardManager')
	if rm:
		rm.audio_music_volume = float(music_slider.value) / 100.0
		rm.audio_sfx_volume = float(sfx_slider.value) / 100.0
		rm.audio_music_enabled = bool(music_toggle.is_pressed())
		rm.audio_sfx_enabled = bool(sfx_toggle.is_pressed())
		# If either disabled, ensure muted flag is false unless both disabled manually
		rm.audio_muted = (not rm.audio_music_enabled) and (not rm.audio_sfx_enabled)
		rm.save_progress()
	else:
		# Fallback to ProjectSettings if RewardManager missing (shouldn't happen)
		ProjectSettings.set_setting(MUSIC_SETTING, int(music_slider.value))
		ProjectSettings.set_setting(SFX_SETTING, int(sfx_slider.value))
		ProjectSettings.set_setting(MUSIC_ENABLED_SETTING, bool(music_toggle.is_pressed()))
		ProjectSettings.set_setting(SFX_ENABLED_SETTING, bool(sfx_toggle.is_pressed()))
		ProjectSettings.save()

func _apply_audio_settings():
	var am = get_node_or_null("/root/AudioManager")
	if not am:
		return
	# Slider values are 0..100; AudioManager expects 0.0..1.0
	am.set_music_volume(float(music_slider.value) / 100.0)
	am.set_sfx_volume(float(sfx_slider.value) / 100.0)
	am.set_music_enabled(bool(music_toggle.is_pressed()))
	am.set_sfx_enabled(bool(sfx_toggle.is_pressed()))
	# Also update RewardManager in-memory so other UIs reflect change immediately
	var rm2 = get_node_or_null('/root/RewardManager')
	if rm2:
		rm2.audio_music_volume = float(music_slider.value) / 100.0
		rm2.audio_sfx_volume = float(sfx_slider.value) / 100.0
		rm2.audio_music_enabled = bool(music_toggle.is_pressed())
		rm2.audio_sfx_enabled = bool(sfx_toggle.is_pressed())
		rm2.audio_muted = (not rm2.audio_music_enabled) and (not rm2.audio_sfx_enabled)

# Signal handlers
func _on_music_slider_changed(value):
	# value is 0..100
	music_volume_label.text = "%d%%" % int(value)
	_apply_audio_settings()

func _on_sfx_slider_changed(value):
	sfx_volume_label.text = "%d%%" % int(value)
	_apply_audio_settings()
	# Play a short preview click so user can hear change
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("ui_click", 0.8)

func _on_music_toggled(pressed: bool):
	_update_toggle_visual(music_toggle, pressed)
	_apply_audio_settings()

func _on_sfx_toggled(pressed: bool):
	_update_toggle_visual(sfx_toggle, pressed)
	_apply_audio_settings()

func _on_vibration_toggled(pressed: bool):
	"""Handle vibration toggle"""
	if VibrationManager:
		VibrationManager.set_vibration_enabled(pressed)
		vibration_toggle.text = tr("UI_ON") if pressed else tr("UI_OFF")
		# Give haptic feedback when toggling on
		if pressed:
			VibrationManager.vibrate_button_press()
		print("[SettingsDialog] Vibration %s" % ("enabled" if pressed else "disabled"))

func _on_language_changed(index: int):
	"""Handle language selection change"""
	if not language_dropdown:
		return

	var lang_code = language_dropdown.get_item_metadata(index)
	print("[SettingsDialog] Language changed to: %s" % lang_code)

	# Change the active language
	TranslationServer.set_locale(lang_code)

	# Save language preference
	var rm = get_node_or_null('/root/RewardManager')
	if rm:
		# Set language property
		rm.language = lang_code
		rm.save_progress()
		print("[SettingsDialog] Saved language preference: %s" % lang_code)

	# Play feedback sound
	AudioManager.play_sfx("ui_click")

	# Broadcast language change to all listeners
	EventBus.emit_language_changed(lang_code)

	# Update UI text immediately by recreating labels
	_update_ui_after_language_change()

func _update_ui_after_language_change():
	"""Update UI labels after language change"""
	# Update main labels
	if title_label:
		title_label.text = tr("UI_SETTINGS")
	if music_label:
		music_label.text = tr("UI_MUSIC")
	if sfx_label:
		sfx_label.text = tr("UI_SFX")
	if close_button:
		close_button.text = tr("UI_CLOSE")

	var vbox = get_node_or_null("VBoxContainer")
	if not vbox:
		return

	# Update language label
	var language_hbox = vbox.get_node_or_null("LanguageHBox")
	if language_hbox:
		var label = language_hbox.get_child(0)  # First child is the label
		if label and label is Label:
			label.text = tr("UI_LANGUAGE") + ":"

	# Update vibration label
	var vibration_hbox = vbox.get_node_or_null("VibrationHBox")
	if vibration_hbox:
		var label = vibration_hbox.get_child(0)  # First child is the label
		if label and label is Label:
			label.text = "📳 " + tr("UI_VIBRATION") + ":"

	# Update vibration toggle text
	if vibration_toggle:
		vibration_toggle.text = tr("UI_ON") if vibration_toggle.button_pressed else tr("UI_OFF")

	print("[SettingsDialog] UI updated for new language")

func get_volume() -> float:
	return music_slider.value

# Helper to update toggle button visual when state changes
func _update_toggle_visual(toggle_btn: TextureButton, enabled: bool):
	if not toggle_btn:
		return

	# Modulate the icon based on state - dim when disabled/muted
	if enabled:
		toggle_btn.modulate = Color(1, 1, 1, 1)
	else:
		toggle_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)

	# Add or update cross overlay for muted state
	var cross = toggle_btn.get_node_or_null("CrossOverlay")
	if not enabled:
		if not cross:
			cross = Label.new()
			cross.name = "CrossOverlay"
			cross.text = "✖"
			cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cross.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cross.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
			ThemeManager.apply_bangers_font(cross, 24)
			cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cross.anchor_left = 0
			cross.anchor_top = 0
			cross.anchor_right = 1
			cross.anchor_bottom = 1
			toggle_btn.add_child(cross)
		cross.visible = true
	else:
		if cross:
			cross.visible = false
