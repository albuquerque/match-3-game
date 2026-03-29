extends "res://scripts/ui/ScreenBase.gd"

signal start_pressed
signal booster_selected(booster_id: String)
signal exchange_pressed
signal settings_pressed
signal achievements_pressed
signal map_pressed

var NodeRes = null

func _ensure_resolvers():
	if NodeRes == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL:
			NodeRes = s
		else:
			NodeRes = load("res://scripts/helpers/node_resolvers_shim.gd")

func _ready():
	# Call ScreenBase ready setup
	ensure_fullscreen()
	_ensure_resolvers()
	# Create a simple layout programmatically so the scene file isn't required here
	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.anchor_left = 0.1
	vbox.anchor_top = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_bottom = 0.9
	# don't set margins/offsets here; anchors are sufficient
	add_child(vbox)

	# Create a theme_manager resolver for font helpers
	var theme_manager = NodeRes._get_tm() if typeof(NodeRes) != TYPE_NIL else null
	var level_label = Button.new()
	level_label.name = "LevelButton"
	level_label.text = "Level: --"
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(level_label, 36)
	# Clicking the level button starts the level
	level_label.pressed.connect(self._on_start_pressed)
	vbox.add_child(level_label)

	# Add lives display
	var lives_label = Label.new()
	lives_label.name = "LivesLabel"
	lives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if theme_manager and theme_manager.has_method("apply_bangers_font"):
		theme_manager.apply_bangers_font(lives_label, 20)
	vbox.add_child(lives_label)

	# Hide lives display - no longer using lives system
	lives_label.visible = false

	# Description label below level button
	var desc_label = Label.new()
	desc_label.name = "LevelDescription"
	desc_label.text = ""
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if theme_manager and theme_manager.has_method("apply_bangers_font"):
		theme_manager.apply_bangers_font(desc_label, 18)
	vbox.add_child(desc_label)

	var actions_h = HBoxContainer.new()
	actions_h.name = "ActionsH"
	vbox.add_child(actions_h)

	var start_btn = Button.new()
	start_btn.name = "StartButton"
	start_btn.text = tr("UI_BUTTON_START")
	start_btn.custom_minimum_size = Vector2(200, 64)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(start_btn, 24)
	start_btn.pressed.connect(self._on_start_pressed)
	actions_h.add_child(start_btn)

	var exchange_btn = Button.new()
	exchange_btn.name = "ExchangeButton"
	exchange_btn.text = tr("UI_BUTTON_EXCHANGE")
	exchange_btn.custom_minimum_size = Vector2(200, 64)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(exchange_btn, 20)
	exchange_btn.pressed.connect(self._on_exchange_pressed)
	actions_h.add_child(exchange_btn)

	# Quick-access Gallery button in the primary action row for convenience
	var gallery_quick = Button.new()
	gallery_quick.name = "GalleryQuickButton"
	gallery_quick.text = "🖼️ " + tr("UI_BUTTON_GALLERY")
	gallery_quick.custom_minimum_size = Vector2(200, 64)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(gallery_quick, 20)
	gallery_quick.pressed.connect(self._on_gallery_pressed)
	actions_h.add_child(gallery_quick)
	print("[StartPage] Gallery quick button added to ActionsH")

	# Create a second row for navigation buttons
	var settings_h = HBoxContainer.new()
	settings_h.name = "SettingsH"
	settings_h.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(settings_h)

	var settings_btn = Button.new()
	settings_btn.name = "SettingsButton"
	settings_btn.text = "⚙️ " + tr("UI_BUTTON_SETTINGS")
	settings_btn.custom_minimum_size = Vector2(150, 48)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(settings_btn, 16)
	settings_btn.pressed.connect(self._on_settings_pressed)
	settings_h.add_child(settings_btn)

	var map_btn = Button.new()
	map_btn.name = "MapButton"
	map_btn.text = "🗺️ " + tr("UI_BUTTON_MAP")
	map_btn.custom_minimum_size = Vector2(150, 48)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(map_btn, 16)
	map_btn.pressed.connect(self._on_map_pressed)
	settings_h.add_child(map_btn)

	var achievements_btn = Button.new()
	achievements_btn.name = "AchievementsButton"
	achievements_btn.text = "🏆 " + tr("UI_BUTTON_ACHIEVEMENTS")
	achievements_btn.custom_minimum_size = Vector2(150, 48)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(achievements_btn, 16)
	achievements_btn.pressed.connect(self._on_achievements_pressed)
	settings_h.add_child(achievements_btn)

	# Gallery button (quick access from StartPage)
	var gallery_btn = Button.new()
	gallery_btn.name = "GalleryButton"
	gallery_btn.text = "🖼️ " + tr("UI_BUTTON_GALLERY")
	gallery_btn.custom_minimum_size = Vector2(150, 48)
	if theme_manager and theme_manager.has_method("apply_bangers_font_to_button"):
		theme_manager.apply_bangers_font_to_button(gallery_btn, 16)
	gallery_btn.pressed.connect(self._on_gallery_pressed)
	settings_h.add_child(gallery_btn)
	print("[StartPage] Gallery button added to SettingsH")

	# Lives system removed - no checks needed
	print("[StartPage] Start button enabled - no lives restrictions")
	# ensure hidden until explicitly shown
	visible = false
	modulate = Color(1,1,1,0)

	# Listen for language changes via NarrativeStageRenderer (or TranslationBootstrap signal)
	# PR 5d: EventBus.language_changed removed — TranslationBootstrap emits locale_changed directly
	# TODO PR 6: wire locale_changed from TranslationBootstrap when needed

	# If a level is already active when StartPage starts, hide immediately
	if GameRunState and GameRunState.initialized:
		print("[StartPage] Level already active at _ready() — hiding StartPage")
		visible = false
		modulate = Color(1,1,1,0)

func set_level_info(level_number: int, description: String):
	var btn = get_node_or_null("VBox/LevelButton")
	if btn and btn is Button:
		btn.text = tr("UI_LABEL_LEVEL") + " %d" % level_number
	var dl = get_node_or_null("VBox/LevelDescription")
	if dl and dl is Label:
		dl.text = description

func close():
	hide_screen()
	# queue_free delegated to caller when desired

func _get_pm() -> Node:
	# PR 5c: resolve PageManager directly — no EventBus needed for navigation
	if has_method("get_tree") and get_tree():
		return get_tree().root.get_node_or_null("PageManager")
	return null

func _open_page(page_name: String) -> void:
	var pm := _get_pm()
	if pm and pm.has_method("open"):
		pm.open(page_name, {})
	else:
		push_warning("[StartPage] PageManager not found; cannot open %s" % page_name)

func _on_start_pressed():
	emit_signal("start_pressed")

func _on_booster_button_pressed(bid: String):
	emit_signal("booster_selected", bid)

func _on_exchange_pressed():
	emit_signal("exchange_pressed")
	_open_page("ShopUI")

func _on_settings_pressed():
	emit_signal("settings_pressed")
	_open_page("SettingsDialog")

func _on_map_pressed():
	emit_signal("map_pressed")
	_open_page("WorldMap")

func _on_achievements_pressed():
	emit_signal("achievements_pressed")
	_open_page("AchievementsPage")

func _on_gallery_pressed():
	_open_page("GalleryPage")

func _on_language_changed(locale: String):
	"""Refresh UI text when language changes"""
	print("[StartPage] Refreshing UI for language: %s" % locale)

	# Update all buttons with translated text
	var start_btn = get_node_or_null("VBox/ActionsH/StartButton")
	if start_btn and start_btn is Button:
		start_btn.text = tr("UI_BUTTON_START")

	var exchange_btn = get_node_or_null("VBox/ActionsH/ExchangeButton")
	if exchange_btn and exchange_btn is Button:
		exchange_btn.text = tr("UI_BUTTON_EXCHANGE")

	var settings_btn = get_node_or_null("VBox/SettingsH/SettingsButton")
	if settings_btn and settings_btn is Button:
		settings_btn.text = "⚙️ " + tr("UI_BUTTON_SETTINGS")

	var map_btn = get_node_or_null("VBox/SettingsH/MapButton")
	if map_btn and map_btn is Button:
		map_btn.text = "🗺️ " + tr("UI_BUTTON_MAP")

	var achievements_btn = get_node_or_null("VBox/SettingsH/AchievementsButton")
	if achievements_btn and achievements_btn is Button:
		achievements_btn.text = "🏆 " + tr("UI_BUTTON_ACHIEVEMENTS")

	var gallery_btn = get_node_or_null("VBox/SettingsH/GalleryButton")
	if gallery_btn and gallery_btn is Button:
		gallery_btn.text = "🖼️ " + tr("UI_BUTTON_GALLERY")

	# Refresh level info if it was set
	var level_btn = get_node_or_null("VBox/LevelButton")
	if level_btn and level_btn is Button:
		# Extract level number from current text if possible
		var current_text = level_btn.text
		var number_match = current_text.split(" ")
		if number_match.size() > 1:
			var level_num = number_match[-1]
			level_btn.text = tr("UI_LABEL_LEVEL") + " " + level_num

func _on_level_loaded(level_id: String, context: Dictionary = {}) -> void:
	"""Hide and remove the StartPage immediately when a level is loaded so it doesn't appear behind gameplay.
	The EventBus.level_loaded signal provides (level_id, context) so accept both params.
	"""
	print("[StartPage] Received level_loaded: ", level_id, " context=", context, " - hiding+removing StartPage")
	# Immediate hide to avoid any visual bleed-through
	visible = false
	modulate = Color(1,1,1,0)
	# Schedule removal - deferred to avoid mutating tree during signal dispatch
	call_deferred("queue_free")
