extends Panel

@onready var close_button = $VBoxContainer/CloseButton
@onready var music_slider = $VBoxContainer/MusicHBox/MusicSlider
@onready var music_toggle = $VBoxContainer/MusicHBox/MusicToggle
@onready var music_volume_label = $VBoxContainer/MusicHBox/VolumeLabel
@onready var sfx_slider = $VBoxContainer/SfxHBox/SfxSlider
@onready var sfx_toggle = $VBoxContainer/SfxHBox/SfxToggle
@onready var sfx_volume_label = $VBoxContainer/SfxHBox/VolumeLabel

const MUSIC_SETTING = "match3/audio/music_volume"
const SFX_SETTING = "match3/audio/sfx_volume"
const MUSIC_ENABLED_SETTING = "match3/audio/music_enabled"
const SFX_ENABLED_SETTING = "match3/audio/sfx_enabled"

func _ready():
	visible = false
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
			cross.add_theme_font_size_override("font_size", 24)
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
