extends "res://scripts/ui/ScreenBase.gd"

# SettingsDialog UI (migrated from root `scripts/SettingsDialog.gd`)
# Creates a Panel/VBoxContainer layout if not present so the UI is visually identical.

# Cached resolved singletons for this instance
var _cached_am: Node = null
var _cached_rm: Node = null
var _cached_tm: Node = null
var _cached_vm: Node = null
var _cached_evbus: Node = null

func _am():
	if is_instance_valid(_cached_am): return _cached_am
	_cached_am = AudioManager if AudioManager else get_node_or_null("/root/AudioManager")
	return _cached_am

func _rm():
	if is_instance_valid(_cached_rm): return _cached_rm
	_cached_rm = RewardManager if RewardManager else get_node_or_null("/root/RewardManager")
	return _cached_rm

func _tm():
	if is_instance_valid(_cached_tm): return _cached_tm
	_cached_tm = ThemeManager if ThemeManager else get_node_or_null("/root/ThemeManager")
	return _cached_tm

func _vm():
	if is_instance_valid(_cached_vm): return _cached_vm
	_cached_vm = VibrationManager if VibrationManager else get_node_or_null("/root/VibrationManager")
	return _cached_vm

func _evbus():
	if is_instance_valid(_cached_evbus): return _cached_evbus
	_cached_evbus = EventBus if EventBus else get_node_or_null("/root/EventBus")
	return _cached_evbus

# Local runtime resolver helper
func _resolve(name: String) -> Node:
	if has_method("get_tree") and get_tree() != null:
		var rt = get_tree().root
		if rt:
			return rt.get_node_or_null(name)
	return null

# UI node references (initialized in _create_ui_if_missing)
var title_label: Label = null
var close_button: Button = null
var music_label: Label = null
var music_slider: HSlider = null
var music_toggle: CheckButton = null
var music_volume_label: Label = null
var sfx_label: Label = null
var sfx_slider: HSlider = null
var sfx_toggle: CheckButton = null
var sfx_volume_label: Label = null

# Dynamic controls created by helpers
var vibration_toggle: CheckButton = null
var language_dropdown: OptionButton = null

const MUSIC_SETTING = "match3/audio/music_volume"
const SFX_SETTING = "match3/audio/sfx_volume"
const MUSIC_ENABLED_SETTING = "match3/audio/music_enabled"
const SFX_ENABLED_SETTING = "match3/audio/sfx_enabled"

func _ready():
	# Ensure UI nodes exist (creates Panel/VBoxContainer/etc if missing)
	_create_ui_if_missing()

	visible = false

	# Initialize labels, toggles and create dynamic UI
	_initialize_ui_labels()
	_create_vibration_toggle()
	_create_language_selector()

	# Connect close button (use the close_button var assigned by _create_ui_if_missing)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)

	# Read runtime state from AudioManager or RewardManager
	var am = _resolve("AudioManager")
	var rm = _resolve("RewardManager")

	var initial_music_vol = 70
	var initial_sfx_vol = 80
	var initial_music_enabled = true
	var initial_sfx_enabled = true

	if am:
		initial_music_vol = int(clamp(am.music_volume * 100.0, 0, 100))
		initial_sfx_vol = int(clamp(am.sfx_volume * 100.0, 0, 100))
		initial_music_enabled = am.music_enabled
		initial_sfx_enabled = am.sfx_enabled
		if rm and rm.audio_muted:
			initial_music_enabled = false
			initial_sfx_enabled = false
	elif rm:
		initial_music_vol = int(clamp(rm.audio_music_volume * 100.0, 0, 100))
		initial_sfx_vol = int(clamp(rm.audio_sfx_volume * 100.0, 0, 100))
		initial_music_enabled = rm.audio_music_enabled
		initial_sfx_enabled = rm.audio_sfx_enabled
		if rm.audio_muted:
			initial_music_enabled = false
			initial_sfx_enabled = false

	# Apply values to controls (guarded)
	if music_slider:
		music_slider.value = initial_music_vol
	if sfx_slider:
		sfx_slider.value = initial_sfx_vol
	if music_toggle:
		music_toggle.button_pressed = initial_music_enabled
	if sfx_toggle:
		sfx_toggle.button_pressed = initial_sfx_enabled

	# Update visible labels
	if music_volume_label:
		music_volume_label.text = "%d%%" % initial_music_vol
	if sfx_volume_label:
		sfx_volume_label.text = "%d%%" % initial_sfx_vol

	# Update toggle visuals
	_update_toggle_visual(music_toggle, initial_music_enabled)
	_update_toggle_visual(sfx_toggle, initial_sfx_enabled)

	# Signal connects are handled where nodes are created to make analyzer happier

func _create_ui_if_missing():
	# If the scene already provides a Panel/VBoxContainer layout, keep it; otherwise create it to match original visuals.
	if get_node_or_null("Panel"):
		return

	# Panel as root visual container
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	# Ensure this Control (the script owner) consumes mouse input so clicks don't pass through to underlying pages
	if self is Control:
		self.mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	panel.add_child(vbox)

	# Title label
	var title = Label.new()
	title.name = "Title"
	title.text = tr("UI_SETTINGS")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Close button (top right)
	var top_h = HBoxContainer.new()
	top_h.name = "TopBar"
	vbox.add_child(top_h)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_h.add_child(spacer)

	var close = Button.new()
	close.name = "CloseButton"
	close.text = tr("UI_CLOSE") if has_method("tr") else "Close"
	close.custom_minimum_size = Vector2(100, 40)
	top_h.add_child(close)

	# Music HBox (label, slider, toggle, volume label)
	var music_h = HBoxContainer.new()
	music_h.name = "MusicHBox"
	music_h.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(music_h)

	var mlabel = Label.new()
	mlabel.name = "MusicLabel"
	mlabel.text = tr("UI_MUSIC") if has_method("tr") else "Music"
	music_h.add_child(mlabel)

	var mslider = HSlider.new()
	mslider.name = "MusicSlider"
	mslider.min_value = 0
	mslider.max_value = 100
	mslider.value = 70
	mslider.step = 1
	mslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	music_h.add_child(mslider)
	mslider.value_changed.connect(_on_music_slider_changed)

	var mvol = Label.new()
	mvol.name = "VolumeLabel"
	mvol.text = "70%"
	music_h.add_child(mvol)

	var mtoggle = CheckButton.new()
	mtoggle.name = "MusicToggle"
	mtoggle.text = tr("UI_ON") if true else tr("UI_OFF")
	music_h.add_child(mtoggle)
	mtoggle.toggled.connect(_on_music_toggled)

	# SFX HBox
	var sfx_h = HBoxContainer.new()
	sfx_h.name = "SfxHBox"
	sfx_h.custom_minimum_size = Vector2(0, 48)
	vbox.add_child(sfx_h)

	var slabel = Label.new()
	slabel.name = "SfxLabel"
	slabel.text = tr("UI_SFX") if has_method("tr") else "SFX"
	sfx_h.add_child(slabel)

	var sslider = HSlider.new()
	sslider.name = "SfxSlider"
	sslider.min_value = 0
	sslider.max_value = 100
	sslider.value = 80
	sslider.step = 1
	sslider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sfx_h.add_child(sslider)
	sslider.value_changed.connect(_on_sfx_slider_changed)

	var svol = Label.new()
	svol.name = "VolumeLabel"
	svol.text = "80%"
	sfx_h.add_child(svol)

	var stoggle = CheckButton.new()
	stoggle.name = "SfxToggle"
	stoggle.text = tr("UI_ON") if true else tr("UI_OFF")
	sfx_h.add_child(stoggle)
	stoggle.toggled.connect(_on_sfx_toggled)

	# Keep ready refs updated
	title_label = title
	close_button = close
	music_label = mlabel
	music_slider = mslider
	music_toggle = mtoggle
	music_volume_label = mvol
	sfx_label = slabel
	sfx_slider = sslider
	sfx_toggle = stoggle
	sfx_volume_label = svol

func _initialize_ui_labels():
	if title_label:
		title_label.text = tr("UI_SETTINGS")
	if music_label:
		music_label.text = tr("UI_MUSIC")
	if sfx_label:
		sfx_label.text = tr("UI_SFX")
	if close_button:
		close_button.text = tr("UI_CLOSE")

func _create_vibration_toggle():
	var vbox = get_node_or_null("Panel/VBoxContainer")
	if not vbox:
		return
	# Avoid duplicate
	if vbox.get_node_or_null("VibrationHBox"):
		vibration_toggle = vbox.get_node_or_null("VibrationHBox/VibrationToggle")
		return

	var vibration_hbox = HBoxContainer.new()
	vibration_hbox.name = "VibrationHBox"

	var label = Label.new()
	label.text = tr("UI_VIBRATION") + ":"
	var tm = _tm()
	if tm and tm.has_method("apply_bangers_font"):
		tm.apply_bangers_font(label, 18)
	vibration_hbox.add_child(label)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(20, 0)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vibration_hbox.add_child(spacer)

	vibration_toggle = CheckButton.new()
	vibration_toggle.name = "VibrationToggle"
	var vm = _vm()
	var vib_on = false
	if vm and vm.has_method("is_vibration_enabled"):
		vib_on = vm.is_vibration_enabled()
	if vib_on:
		label.text = tr("UI_ON")
	else:
		label.text = tr("UI_OFF")
	vibration_toggle.button_pressed = vib_on
	var _tm_local = _tm()
	if _tm_local and _tm_local.has_method("apply_bangers_font_to_button"):
		_tm_local.apply_bangers_font_to_button(vibration_toggle, 16)
	if vibration_toggle:
		vibration_toggle.toggled.connect(_on_vibration_toggled)
	vibration_hbox.add_child(vibration_toggle)

	vbox.add_child(vibration_hbox)
	vbox.move_child(vibration_hbox, vbox.get_child_count() - 0)

	print("[SettingsDialog] Vibration toggle created")

func _create_language_selector():
	var vbox = get_node_or_null("Panel/VBoxContainer")
	if not vbox:
		return
	# Avoid duplicate
	if vbox.get_node_or_null("LanguageHBox"):
		language_dropdown = vbox.get_node_or_null("LanguageHBox/LanguageDropdown")
		return

	var language_hbox = HBoxContainer.new()
	language_hbox.name = "LanguageHBox"

	var label = Label.new()
	label.text = tr("UI_LANGUAGE") + ":"
	language_hbox.add_child(label)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_hbox.add_child(spacer)

	language_dropdown = OptionButton.new()
	language_dropdown.name = "LanguageDropdown"

	# Language list: code + human-readable fallback. We'll attempt to translate the label via tr("LANG_<CODE>") if available.
	var languages = [["en", "English"], ["es", "Spanish"], ["pt", "Portuguese"], ["fr", "French"]]
	var current_locale = TranslationServer.get_locale()
	var selected_index = 0
	var i = 0
	for pair in languages:
		var code = pair[0]
		var fallback = pair[1]
		# Try a translation key like LANG_EN, LANG_ES etc. If translation not present, fall back to English name
		var key = "LANG_%s" % code.to_upper()
		var translated = tr(key)
		var label_text = translated
		if typeof(label_text) != TYPE_STRING or label_text == key:
			label_text = fallback
		language_dropdown.add_item(label_text)
		language_dropdown.set_item_metadata(i, code)
		if code == current_locale:
			selected_index = i
		i += 1

	language_dropdown.selected = selected_index
	if language_dropdown:
		language_dropdown.item_selected.connect(_on_language_changed)
	language_hbox.add_child(language_dropdown)

	vbox.add_child(language_hbox)

	print("[SettingsDialog] Language selector created - current locale: %s" % current_locale)

func show_dialog():
	visible = true
	modulate = Color(1,1,1,0)
	var t = get_tree().create_tween()
	t.tween_property(self, "modulate", Color(1,1,1,1), 0.15)
	if close_button and close_button is Node:
		close_button.grab_focus()

func _on_close_pressed():
	print("[SettingsDialog] _on_close_pressed - saving and closing")
	_save_settings()
	_apply_audio_settings()
	close_screen()

func _save_settings():
	var rm = _resolve("RewardManager")
	if rm:
		rm.audio_music_volume = float(music_slider.value) / 100.0 if music_slider else rm.audio_music_volume
		rm.audio_sfx_volume = float(sfx_slider.value) / 100.0 if sfx_slider else rm.audio_sfx_volume
		rm.audio_music_enabled = bool(music_toggle.button_pressed) if music_toggle else rm.audio_music_enabled
		rm.audio_sfx_enabled = bool(sfx_toggle.button_pressed) if sfx_toggle else rm.audio_sfx_enabled
		rm.audio_muted = (not rm.audio_music_enabled) and (not rm.audio_sfx_enabled)
		rm.save_progress()
	else:
		ProjectSettings.set_setting(MUSIC_SETTING, int(music_slider.value) if music_slider else 70)
		ProjectSettings.set_setting(SFX_SETTING, int(sfx_slider.value) if sfx_slider else 80)
		ProjectSettings.set_setting(MUSIC_ENABLED_SETTING, bool(music_toggle.button_pressed) if music_toggle else true)
		ProjectSettings.set_setting(SFX_ENABLED_SETTING, bool(sfx_toggle.button_pressed) if sfx_toggle else true)
		ProjectSettings.save()

func _apply_audio_settings():
	var am = _resolve("AudioManager")
	if am == null:
		return
	if music_slider:
		if am.has_method("set_music_volume"):
			am.set_music_volume(float(music_slider.value) / 100.0)
		else:
			am.music_volume = float(music_slider.value) / 100.0
	if sfx_slider:
		if am.has_method("set_sfx_volume"):
			am.set_sfx_volume(float(sfx_slider.value) / 100.0)
		else:
			am.sfx_volume = float(sfx_slider.value) / 100.0
	if music_toggle:
		if am.has_method("set_music_enabled"):
			am.set_music_enabled(bool(music_toggle.button_pressed))
		else:
			am.music_enabled = bool(music_toggle.button_pressed)
	if sfx_toggle:
		if am.has_method("set_sfx_enabled"):
			am.set_sfx_enabled(bool(sfx_toggle.button_pressed))
		else:
			am.sfx_enabled = bool(sfx_toggle.button_pressed)

	var rm = _resolve("RewardManager")
	if rm:
		rm.audio_music_volume = float(music_slider.value) / 100.0 if music_slider else rm.audio_music_volume
		rm.audio_sfx_volume = float(sfx_slider.value) / 100.0 if sfx_slider else rm.audio_sfx_volume
		rm.audio_music_enabled = bool(music_toggle.button_pressed) if music_toggle else rm.audio_music_enabled
		rm.audio_sfx_enabled = bool(sfx_toggle.button_pressed) if sfx_toggle else rm.audio_sfx_enabled
		rm.save_progress()

func _update_toggle_visual(toggle_btn: Control, enabled: bool):
	if toggle_btn == null:
		return
	if toggle_btn is CheckButton:
		toggle_btn.button_pressed = enabled
		toggle_btn.text = tr("UI_ON") if enabled else tr("UI_OFF")

func _on_music_slider_changed(value):
	if music_volume_label:
		music_volume_label.text = "%d%%" % int(value)
	_apply_audio_settings()

func _on_sfx_slider_changed(value):
	sfx_volume_label.text = "%d%%" % int(value)
	_apply_audio_settings()
	var am_preview = _resolve("AudioManager")
	if am_preview:
		am_preview.play_sfx("ui_click", 0.8)

func _on_music_toggled(pressed: bool):
	_update_toggle_visual(music_toggle, pressed)
	_apply_audio_settings()

func _on_sfx_toggled(pressed: bool):
	_update_toggle_visual(sfx_toggle, pressed)
	_apply_audio_settings()

func _on_vibration_toggled(pressed: bool):
	var _vm_local = _vm()
	if _vm_local:
		_vm_local.set_vibration_enabled(pressed)
		vibration_toggle.text = tr("UI_ON") if pressed else tr("UI_OFF")
		if pressed and _vm_local.has_method("vibrate_button_press"):
			_vm_local.vibrate_button_press()
		print("[SettingsDialog] Vibration %s" % ("enabled" if pressed else "disabled"))

func _on_language_changed(index: int):
	if not language_dropdown:
		return
	var lang_code = language_dropdown.get_item_metadata(index)
	print("[SettingsDialog] Language changed to: %s" % lang_code)
	TranslationServer.set_locale(lang_code)
	var rm = _resolve("RewardManager")
	if rm:
		rm.language = lang_code
		rm.save_progress()
		print("[SettingsDialog] Saved language preference: %s" % lang_code)
	var _am_local = _resolve("AudioManager")
	if _am_local:
		_am_local.play_sfx("ui_click")
	var _ev = _evbus()
	if _ev and _ev.has_method("emit_language_changed"):
		_ev.emit_language_changed(lang_code)
	_update_ui_after_language_change()

func _update_ui_after_language_change():
	if title_label:
		title_label.text = tr("UI_SETTINGS")
	if music_label:
		music_label.text = tr("UI_MUSIC")
	if sfx_label:
		sfx_label.text = tr("UI_SFX")
	if close_button:
		close_button.text = tr("UI_CLOSE")
	# Update dynamic labels that depend on values
	if music_volume_label and music_slider:
		music_volume_label.text = "%d%%" % int(music_slider.value)
	if sfx_volume_label and sfx_slider:
		sfx_volume_label.text = "%d%%" % int(sfx_slider.value)
	# Update toggle text/buttons
	if music_toggle:
		_update_toggle_visual(music_toggle, bool(music_toggle.button_pressed))
	if sfx_toggle:
		_update_toggle_visual(sfx_toggle, bool(sfx_toggle.button_pressed))
	var vbox = get_node_or_null("Panel/VBoxContainer")
	if not vbox:
		return
	var language_hbox = vbox.get_node_or_null("LanguageHBox")
	if language_hbox:
		var label = language_hbox.get_child(0)
		if label and label is Label:
			label.text = tr("UI_LANGUAGE") + ":"
	var vibration_hbox = vbox.get_node_or_null("VibrationHBox")
	if vibration_hbox:
		var label = vibration_hbox.get_child(0)
		if label and label is Label:
			label.text = tr("UI_VIBRATION") + ":"
	if vibration_toggle:
		vibration_toggle.text = tr("UI_ON") if vibration_toggle.button_pressed else tr("UI_OFF")
	# Refresh language dropdown labels to reflect translations if any
	if language_dropdown:
		for idx in range(language_dropdown.get_item_count()):
			var code = language_dropdown.get_item_metadata(idx)
			var key = "LANG_%s" % str(code).to_upper()
			var translated = tr(key)
			if typeof(translated) == TYPE_STRING and translated != key:
				language_dropdown.set_item_text(idx, translated)
	print("[SettingsDialog] UI updated for new language")

func get_volume() -> float:
	return music_slider.value
