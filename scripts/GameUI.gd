extends Control
class_name GameUI

# Currency UI
@onready var coins_label = $VBoxContainer/CurrencyPanel/HBoxContainer/CoinsLabel
@onready var gems_label = $VBoxContainer/CurrencyPanel/HBoxContainer/GemsLabel
@onready var lives_label = $VBoxContainer/CurrencyPanel/HBoxContainer/LivesLabel

# Game UI
@onready var score_label = $VBoxContainer/TopPanel/ScoreContainer/ScoreLabel
@onready var level_label = $VBoxContainer/TopPanel/LevelContainer/LevelLabel
@onready var moves_label = $VBoxContainer/TopPanel/MovesContainer/MovesLabel
@onready var target_progress = $VBoxContainer/TopPanel/TargetContainer/TargetProgress
@onready var target_label = $VBoxContainer/TopPanel/TargetContainer/TargetLabel

# Booster UI (optional - will be null if not added to scene yet)
@onready var booster_panel = get_node_or_null("BoosterPanel")
@onready var hammer_button = get_node_or_null("BoosterPanel/HBoxContainer/HammerButton")
@onready var shuffle_button = get_node_or_null("BoosterPanel/HBoxContainer/ShuffleButton")
@onready var swap_button = get_node_or_null("BoosterPanel/HBoxContainer/SwapButton")
@onready var chain_reaction_button = get_node_or_null("BoosterPanel/HBoxContainer/ChainReactionButton")
@onready var bomb_3x3_button = get_node_or_null("BoosterPanel/HBoxContainer/Bomb3x3Button")
@onready var line_blast_button = get_node_or_null("BoosterPanel/HBoxContainer/LineBlastButton")
@onready var tile_squasher_button = get_node_or_null("BoosterPanel/HBoxContainer/TileSquasherButton")
@onready var row_clear_button = get_node_or_null("BoosterPanel/HBoxContainer/RowClearButton")
@onready var column_clear_button = get_node_or_null("BoosterPanel/HBoxContainer/ColumnClearButton")

# Booster button icons (TextureRect children)
@onready var hammer_icon = get_node_or_null("BoosterPanel/HBoxContainer/HammerButton/Icon")
@onready var shuffle_icon = get_node_or_null("BoosterPanel/HBoxContainer/ShuffleButton/Icon")
@onready var swap_icon = get_node_or_null("BoosterPanel/HBoxContainer/SwapButton/Icon")
@onready var chain_reaction_icon = get_node_or_null("BoosterPanel/HBoxContainer/ChainReactionButton/Icon")
@onready var bomb_3x3_icon = get_node_or_null("BoosterPanel/HBoxContainer/Bomb3x3Button/Icon")
@onready var line_blast_icon = get_node_or_null("BoosterPanel/HBoxContainer/LineBlastButton/Icon")
@onready var tile_squasher_icon = get_node_or_null("BoosterPanel/HBoxContainer/TileSquasherButton/Icon")
@onready var row_clear_icon = get_node_or_null("BoosterPanel/HBoxContainer/RowClearButton/Icon")
@onready var column_clear_icon = get_node_or_null("BoosterPanel/HBoxContainer/ColumnClearButton/Icon")

# Booster count labels
@onready var hammer_count_label = get_node_or_null("BoosterPanel/HBoxContainer/HammerButton/CountLabel")
@onready var shuffle_count_label = get_node_or_null("BoosterPanel/HBoxContainer/ShuffleButton/CountLabel")
@onready var swap_count_label = get_node_or_null("BoosterPanel/HBoxContainer/SwapButton/CountLabel")
@onready var chain_reaction_count_label = get_node_or_null("BoosterPanel/HBoxContainer/ChainReactionButton/CountLabel")
@onready var bomb_3x3_count_label = get_node_or_null("BoosterPanel/HBoxContainer/Bomb3x3Button/CountLabel")
@onready var line_blast_count_label = get_node_or_null("BoosterPanel/HBoxContainer/LineBlastButton/CountLabel")
@onready var tile_squasher_count_label = get_node_or_null("BoosterPanel/HBoxContainer/TileSquasherButton/CountLabel")
@onready var row_clear_count_label = get_node_or_null("BoosterPanel/HBoxContainer/RowClearButton/CountLabel")
@onready var column_clear_count_label = get_node_or_null("BoosterPanel/HBoxContainer/ColumnClearButton/CountLabel")

# Old game over panel removed - using dynamic EnhancedGameOver screen now
# @onready var game_over_panel = $GameOverPanel  # REMOVED FROM SCENE
@onready var level_complete_panel = $LevelCompletePanel
# @onready var restart_button = $GameOverPanel/VBoxContainer/RestartButton  # REMOVED FROM SCENE
@onready var continue_button = $LevelCompletePanel/VBoxContainer/ContinueButton
# @onready var final_score_label = $GameOverPanel/VBoxContainer/FinalScoreLabel  # REMOVED FROM SCENE
@onready var level_complete_score = $LevelCompletePanel/VBoxContainer/LevelScoreLabel

# Update menu & popup references
@onready var menu_button = $VBoxContainer/TopPanel/MenuButton
@onready var main_menu_popup = $MainMenuPopup

# Phase 2: Shop and Dialogs
@onready var shop_button = get_node_or_null("VBoxContainer/BottomPanel/ShopButton")
@onready var shop_ui = get_node_or_null("ShopUI")
@onready var out_of_lives_dialog = $OutOfLivesDialog
@onready var reward_notification = $RewardNotification

# Dialog references
@onready var settings_dialog = get_node_or_null("SettingsDialog")
@onready var about_dialog = get_node_or_null("AboutDialog")

# Gallery reference
var gallery_ui = null  # Will be created when needed

# Start page reference
var start_page = null  # Will be set in _ready()

# Level transition screen
var level_transition = null  # Will be created in _ready()

# Reintroduce game over panel reference (was removed earlier)
var game_over_panel: Panel = null

var is_paused = false
var booster_mode_active = false
var active_booster_type = ""
var swap_first_tile = null  # For swap booster - remember first selected tile
var line_blast_direction = ""  # For line blast - "horizontal" or "vertical"
var _panel_to_hide = null

# New variables for side panel behavior
var board_original_position = Vector2.ZERO
var side_panel_open = false
const SIDE_PANEL_MAX_WIDTH = 480
const SIDE_PANEL_WIDTH_PERCENT = 0.40
var _shop_original_parent = null
var _shop_original_index = -1
var _side_position = "right"  # current side where the panel will open from: "left" or "right"

# Helper flag used when awaiting level_loaded signal
var _level_loaded_flag: bool = false

func _level_loaded_signal():
	_level_loaded_flag = true

func _ready():
	# Debug: print initial global state to help diagnose inadvertent Game Over
	print("[GameUI] _ready() — initial states: GameManager.score=", GameManager.score, ", moves_left=", GameManager.moves_left, ", target=", GameManager.target_score)

	# Reorganize HUD for better gameplay layout
	_reorganize_hud()

	# Connect to RewardManager signals
	RewardManager.connect("coins_changed", _on_coins_changed)
	RewardManager.connect("gems_changed", _on_gems_changed)
	RewardManager.connect("lives_changed", _on_lives_changed)
	RewardManager.connect("booster_changed", _on_booster_changed)

	# Connect to GameManager signals
	GameManager.connect("score_changed", _on_score_changed)
	GameManager.connect("level_changed", _on_level_changed)
	GameManager.connect("moves_changed", _on_moves_changed)
	GameManager.connect("game_over", _on_game_over)
	GameManager.connect("level_complete", _on_level_complete)
	GameManager.connect("collectibles_changed", _on_collectibles_changed)
	GameManager.connect("unmovables_changed", _on_unmovables_changed)

	# Connect UI buttons
	# restart_button removed - enhanced game over screen uses its own buttons
	continue_button.connect("pressed", _on_continue_pressed)
	menu_button.connect("pressed", _on_menu_pressed)

	# Ensure the menu button has its SVG texture loaded at runtime
	var menu_icon_path = "res://textures/menu_hamburger.svg"
	if menu_button:
		print("[GameUI] MenuButton found; attempting to load icon from:", menu_icon_path)
		menu_button.visible = true
		menu_button.mouse_filter = Control.MOUSE_FILTER_STOP
		menu_button.modulate = Color(1,1,1,1)
		menu_button.focus_mode = Control.FOCUS_NONE
		menu_button.custom_minimum_size = Vector2(44, 44)
		# Try loading texture
		if ResourceLoader.exists(menu_icon_path):
			var tex = load(menu_icon_path)
			if tex:
				# Prefer using an explicit child Icon TextureRect if present. This avoids the
				# TextureButton drawing the texture as background AND the child Icon also drawing
				# the same texture which results in duplicate rendering (appears as doubled lines).
				var icon_node = null
				if menu_button.has_node("Icon"):
					icon_node = menu_button.get_node("Icon")

				if icon_node and icon_node is TextureRect:
					# Use child TextureRect for icon rendering and don't set button textures
					icon_node.texture = tex
					icon_node.visible = true
					icon_node.modulate = Color(1,1,1,1)
					icon_node.custom_minimum_size = Vector2(24, 24)
					icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					print("[GameUI] Loaded menu icon into child Icon TextureRect:", tex)
				else:
					# No child Icon present — set the TextureButton textures so it displays
					if "texture_normal" in menu_button:
						menu_button.texture_normal = tex
					if "texture_pressed" in menu_button:
						menu_button.texture_pressed = tex
					print("[GameUI] Loaded menu icon into TextureButton textures:", tex)

					# Fall back: if the button still doesn't show the icon (some controls types),
					# add a runtime TextureRect under MenuButton to be safe.
					if (not menu_button.has_node("MenuIconRuntime")):
						var runtime_icon = TextureRect.new()
						runtime_icon.name = "MenuIconRuntime"
						runtime_icon.texture = tex
						runtime_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
						runtime_icon.custom_minimum_size = Vector2(28, 28)
						runtime_icon.anchor_left = 0.5
						runtime_icon.anchor_top = 0.5
						runtime_icon.anchor_right = 0.5
						runtime_icon.anchor_bottom = 0.5
						runtime_icon.offset_left = -14
						runtime_icon.offset_top = -14
						runtime_icon.offset_right = 14
						runtime_icon.offset_bottom = 14
						menu_button.add_child(runtime_icon)
						print("[GameUI] Added runtime MenuIconRuntime fallback")
			else:
				print("[GameUI] Failed to load texture from:", menu_icon_path)
		else:
			print("[GameUI] Menu icon not found at:", menu_icon_path)

	# Set up Main Menu popup
	if main_menu_popup:
		main_menu_popup.add_item("Settings", 0)
		main_menu_popup.add_item("Shop", 1)
		main_menu_popup.add_item("Gallery", 2)
		main_menu_popup.add_item("About", 3)
		main_menu_popup.add_item("Share", 4)
		main_menu_popup.id_pressed.connect(_on_main_menu_item_selected)

	# Connect booster buttons
	if hammer_button:
		hammer_button.connect("pressed", _on_hammer_pressed)
	if shuffle_button:
		shuffle_button.connect("pressed", _on_shuffle_pressed)
	if swap_button:
		swap_button.connect("pressed", _on_swap_pressed)
	if chain_reaction_button:
		chain_reaction_button.connect("pressed", _on_chain_reaction_pressed)
	if bomb_3x3_button:
		bomb_3x3_button.connect("pressed", _on_bomb_3x3_pressed)
	if line_blast_button:
		line_blast_button.connect("pressed", _on_line_blast_pressed)
	if tile_squasher_button:
		tile_squasher_button.connect("pressed", _on_tile_squasher_pressed)
	if row_clear_button:
		row_clear_button.connect("pressed", _on_row_clear_pressed)
	if column_clear_button:
		column_clear_button.connect("pressed", _on_column_clear_pressed)

	# Phase 2: Shop button
	if shop_button:
		shop_button.connect("pressed", _on_shop_pressed)

	# Connect shop and dialog signals
	if shop_ui:
		shop_ui.connect("shop_closed", _on_shop_closed)
		shop_ui.connect("item_purchased", _on_item_purchased)

	if out_of_lives_dialog:
		out_of_lives_dialog.connect("refill_requested", _on_refill_requested)
		out_of_lives_dialog.connect("dialog_closed", _on_out_of_lives_closed)

	# Connect AboutDialog closed signal if present
	var adlg_node = get_node_or_null("AboutDialog")
	if adlg_node and adlg_node.has_signal("dialog_closed"):
		adlg_node.connect("dialog_closed", Callable(self, "_on_about_dialog_closed"))

	# Initialize UI
	# game_over_panel removed - using dynamic EnhancedGameOver screen
	level_complete_panel.visible = false
	update_display()
	update_currency_display()
	load_booster_icons()
	update_booster_ui()

	# Set LevelManager's current_level_index based on saved progress BEFORE showing start page
	# This ensures the start page shows the correct level number
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		# levels_completed tracks highest level finished
		# Next level to play is at index levels_completed
		# Example: levels_completed=0 → play index 0 (Level 1)
		# Example: levels_completed=3 → play index 3 (Level 4)
		var next_level_index = RewardManager.levels_completed
		level_manager.current_level_index = next_level_index
		print("[GameUI] _ready: Set level to index ", next_level_index, " (Level ", next_level_index + 1, ") based on levels_completed=", RewardManager.levels_completed)

	# Show StartPage instead of immediately starting the level
	start_page = get_node_or_null("StartPage")
	if not start_page:
		# Try to instance the StartPage script as a Control
		var sp = load("res://scripts/StartPage.gd")
		if sp:
			start_page = sp.new()
			start_page.name = "StartPage"
			add_child(start_page)
			print("[GameUI] Instanced StartPage")

	if start_page and start_page is Control:
		# Configure fullscreen
		start_page.anchor_left = 0
		start_page.anchor_top = 0
		start_page.anchor_right = 1
		start_page.anchor_bottom = 1
		start_page.position = Vector2(0,0)
		start_page.size = get_viewport().get_visible_rect().size
		start_page.visible = true
		# populate level info if LevelManager is available
		var lm = get_node_or_null('/root/LevelManager')
		if lm:
			var lvl = lm.get_current_level()
			if lvl and start_page.has_method('set_level_info'):
				start_page.call('set_level_info', lvl.level_number, lvl.description)
		# Connect signals
		if not start_page.is_connected("start_pressed", Callable(self, "_on_startpage_start_pressed")):
			start_page.connect("start_pressed", Callable(self, "_on_startpage_start_pressed"))
		if not start_page.is_connected("booster_selected", Callable(self, "_on_startpage_booster_selected")):
			start_page.connect("booster_selected", Callable(self, "_on_startpage_booster_selected"))
		if not start_page.is_connected("exchange_pressed", Callable(self, "_on_startpage_exchange_pressed")):
			start_page.connect("exchange_pressed", Callable(self, "_on_startpage_exchange_pressed"))
		# Connect new settings signal so StartPage can open settings
		if start_page.has_signal("settings_pressed") and not start_page.is_connected("settings_pressed", Callable(self, "_on_startpage_settings_pressed")):
			start_page.connect("settings_pressed", Callable(self, "_on_startpage_settings_pressed"))
		# Connect achievements signal
	# Create LevelTransition screen
	level_transition = get_node_or_null("LevelTransition")
	if not level_transition:
		var lt_script = load("res://scripts/LevelTransition.gd")
		if lt_script:
			level_transition = lt_script.new()
			level_transition.name = "LevelTransition"
			add_child(level_transition)
			level_transition.visible = false
			level_transition.z_index = 100  # On top of everything
			print("[GameUI] Created LevelTransition screen")

	if level_transition:
		# Connect signals
		if not level_transition.is_connected("continue_pressed", Callable(self, "_on_transition_continue")):
			level_transition.connect("continue_pressed", Callable(self, "_on_transition_continue"))
		if not level_transition.is_connected("rewards_claimed", Callable(self, "_on_transition_rewards_claimed")):
			level_transition.connect("rewards_claimed", Callable(self, "_on_transition_rewards_claimed"))

		if start_page.has_signal("achievements_pressed") and not start_page.is_connected("achievements_pressed", Callable(self, "_on_startpage_achievements_pressed")):
			start_page.connect("achievements_pressed", Callable(self, "_on_startpage_achievements_pressed"))
		# Connect map signal
		if start_page.has_signal("map_pressed") and not start_page.is_connected("map_pressed", Callable(self, "_on_startpage_map_pressed")):
			start_page.connect("map_pressed", Callable(self, "_on_startpage_map_pressed"))

	# Play menu music (will be switched to game music when level starts)
	AudioManager.play_music("menu", 1.0)

func load_booster_icons():
	"""Load booster icons based on current theme"""
	var theme = ThemeManager.get_theme_name()
	var base_path = "res://textures/%s/" % theme

	# Icon size configuration (256x256 images scaled down to 48x48 to fit in 70x70 buttons)
	var icon_size = Vector2(48, 48)

	print("[GameUI] Loading booster icons for theme: ", theme)
	print("[GameUI] Base path: ", base_path)

	# Load each booster icon with scaling
	_load_and_scale_icon(hammer_icon, base_path + "booster_hammer.png", icon_size)
	_load_and_scale_icon(shuffle_icon, base_path + "booster_shuffle.png", icon_size)
	_load_and_scale_icon(swap_icon, base_path + "booster_swap.png", icon_size)
	_load_and_scale_icon(chain_reaction_icon, base_path + "booster_chain_reaction.png", icon_size)
	_load_and_scale_icon(bomb_3x3_icon, base_path + "booster_bomb_3x3.png", icon_size)
	_load_and_scale_icon(line_blast_icon, base_path + "booster_line_blast.png", icon_size)
	_load_and_scale_icon(tile_squasher_icon, base_path + "booster_tile_squasher.png", icon_size)
	_load_and_scale_icon(row_clear_icon, base_path + "booster_row_clear.png", icon_size)
	_load_and_scale_icon(column_clear_icon, base_path + "booster_column_clear.png", icon_size)

	print("[GameUI] Finished loading booster icons")

func _load_and_scale_icon(icon_node: TextureRect, path: String, size: Vector2):
	"""Helper function to load and scale a single icon"""
	if icon_node:
		if ResourceLoader.exists(path):
			icon_node.texture = load(path)
			icon_node.custom_minimum_size = size
			icon_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			print("[GameUI] Loaded and scaled: ", path)
		else:
			print("[GameUI] ERROR: Icon not found at: ", path)
	else:
		print("[GameUI] ERROR: Icon node is null for: ", path)

func update_display():
	# Clean display without redundant prefixes
	score_label.text = "%d" % GameManager.score
	level_label.text = "Lv %d" % GameManager.level
	moves_label.text = "%d" % GameManager.moves_left

	# Update progress bar and target label based on level type
	if GameManager.unmovable_target > 0:
		# Unmovable-based level
		var progress = float(GameManager.unmovables_cleared) / float(GameManager.unmovable_target)
		target_progress.value = min(progress * 100, 100)
		target_label.text = "Obstacles: %d/%d" % [GameManager.unmovables_cleared, GameManager.unmovable_target]
	elif GameManager.collectible_target > 0:
		# Collectible-based level
		var progress = float(GameManager.collectibles_collected) / float(GameManager.collectible_target)
		target_progress.value = min(progress * 100, 100)
		target_label.text = "Coins: %d/%d" % [GameManager.collectibles_collected, GameManager.collectible_target]
	else:
		# Score-based level
		var progress = float(GameManager.score) / float(GameManager.target_score)
		target_progress.value = min(progress * 100, 100)
		target_label.text = "Goal: %d" % GameManager.target_score

func _on_score_changed(new_score: int):
	score_label.text = "%d" % new_score

	# Update progress only if score-based level (not collectible or unmovable)
	if GameManager.collectible_target == 0 and GameManager.unmovable_target == 0:
		var progress = float(new_score) / float(GameManager.target_score)
		target_progress.value = min(progress * 100, 100)

	# Animate score increase
	animate_score_change()

func _on_level_changed(new_level: int):
	level_label.text = "Lv %d" % new_level

	# Update target label based on level type
	if GameManager.unmovable_target > 0:
		target_label.text = "Obstacles: %d/%d" % [GameManager.unmovables_cleared, GameManager.unmovable_target]
	elif GameManager.collectible_target > 0:
		target_label.text = "Coins: %d/%d" % [GameManager.collectibles_collected, GameManager.collectible_target]
	else:
		target_label.text = "Goal: %d" % GameManager.target_score

	target_progress.value = 0

	# Animate level change
	animate_level_change()

func _on_collectibles_changed(collected: int, target: int):
	"""Update UI when collectibles are collected"""
	if target > 0:
		target_label.text = "Coins: %d/%d" % [collected, target]
		var progress = float(collected) / float(target)
		target_progress.value = min(progress * 100, 100)

		# Animate collectible collection
		var tween = create_tween()
		tween.tween_property(target_label, "modulate", Color(1.0, 0.9, 0.2), 0.1)  # Gold flash
		tween.tween_property(target_label, "modulate", Color.WHITE, 0.1)

func _on_unmovables_changed(cleared: int, target: int):
	"""Update UI when unmovables are cleared"""
	if target > 0:
		target_label.text = "Obstacles: %d/%d" % [cleared, target]
		var progress = float(cleared) / float(target)
		target_progress.value = min(progress * 100, 100)

		# Animate unmovable clearing
		var tween = create_tween()
		tween.tween_property(target_label, "modulate", Color(1.0, 0.5, 0.3), 0.1)  # Orange flash
		tween.tween_property(target_label, "modulate", Color.WHITE, 0.1)

func _on_moves_changed(moves_left: int):
	moves_label.text = "%d" % moves_left

	# Warning color when low on moves
	if moves_left <= 5:
		moves_label.modulate = Color.RED
		animate_low_moves_warning()
	else:
		moves_label.modulate = Color.WHITE

func _on_game_over():
	# Defensive: Only show the Game Over panel when the game manager indicates a real failure
	print("=".repeat(60))
	print("[GameUI] 💔 _on_game_over() CALLED 💔")
	print("=".repeat(60))
	print("[GameUI] Game over - verifying state: moves_left=", GameManager.moves_left, ", score=", GameManager.score, ", target=", GameManager.target_score)

	# Consider it a valid game over if no moves left and score < target
	if GameManager.moves_left > 0 and GameManager.score < GameManager.target_score:
		print("[GameUI] INVALID GAME OVER (still has moves). Ignoring.")
		return

	# Show enhanced game over screen
	_show_enhanced_game_over()

# Create or show the enhanced Game Over panel (modal)
func _show_enhanced_game_over():
	# If already created, just show and return
	if game_over_panel and is_instance_valid(game_over_panel):
		show_panel(game_over_panel)
		return

	# Create a centered panel
	var screen_size = get_viewport().get_visible_rect().size
	var panel_size = Vector2(min(720, screen_size.x * 0.9), min(480, screen_size.y * 0.6))
	game_over_panel = Panel.new()
	game_over_panel.name = "EnhancedGameOverPanel"
	game_over_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_panel.rect_min_size = panel_size
	game_over_panel.rect_position = (screen_size - panel_size) / 2
	game_over_panel.z_index = 2000

	# Style container
	var vb = VBoxContainer.new()
	vb.name = "GameOverVBox"
	vb.anchor_left = 0
	vb.anchor_top = 0
	vb.anchor_right = 1
	vb.anchor_bottom = 1
	vb.margin_left = 20
	vb.margin_top = 20
	vb.margin_right = -20
	vb.margin_bottom = -20
	game_over_panel.add_child(vb)

	# Title
	var title = Label.new()
	title.name = "Title"
	title.text = "Game Over"
	ThemeManager.apply_bangers_font(title, 48)
	title.add_theme_color_override("font_color", Color(1,0.2,0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	vb.add_child(spacer)

	# Details
	var details = Label.new()
	details.name = "Details"
	details.text = "You have no moves left. Final Score: %d\nTarget: %d" % [GameManager.score, GameManager.target_score]
	details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details.valign = VERTICAL_ALIGNMENT_CENTER
	details.autowrap = true
	details.add_theme_font_size_override("font_size", 20)
	vb.add_child(details)

	# Buttons row
	var hb = HBoxContainer.new()
	hb.name = "ButtonsRow"
	hb.custom_minimum_size = Vector2(0, 16)
	hb.anchor_left = 0
	hb.anchor_right = 1
	hb.margin_left = 30
	hb.margin_right = -30
	vb.add_child(hb)

	# Retry button
	var retry_btn = Button.new()
	retry_btn.name = "RetryButton"
	retry_btn.text = "Try Again"
	retry_btn.focus_mode = Control.FOCUS_NONE
	retry_btn.connect("pressed", Callable(self, "_on_game_over_retry"))
	retry_btn.expand = true
	hb.add_child(retry_btn)

	# Quit button
	var quit_btn = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "Quit"
	quit_btn.focus_mode = Control.FOCUS_NONE
	quit_btn.connect("pressed", Callable(self, "_on_game_over_quit"))
	quit_btn.expand = true
	hb.add_child(quit_btn)

	# Add the panel to this UI and make modal
	add_child(game_over_panel)
	show_panel(game_over_panel)
	print("[GameUI] Enhanced Game Over panel created and shown")

# Handler for retry pressed on enhanced game over
func _on_game_over_retry():
	AudioManager.play_sfx("ui_click")
	if game_over_panel:
		hide_panel(game_over_panel)
		# Small delay to allow fade-out
		await get_tree().create_timer(0.25).timeout
		# Restart the current level / game
		await restart_game()

# Handler for quit pressed on enhanced game over
func _on_game_over_quit():
	AudioManager.play_sfx("ui_click")
	# Gracefully quit the application (or go back to start page)
	# If running in editor, just show start page
	if Engine.is_editor_hint():
		show_start_page()
		return
	get_tree().quit()

func _on_level_complete():
	print("=".repeat(60))
	print("[GameUI] _on_level_complete() CALLED")
	print("=".repeat(60))
	print("[GameUI] Level complete! Score: %d, Target: %d" % [GameManager.score, GameManager.target_score])
	print("[GameUI] GameManager.level = ", GameManager.level)
	print("[GameUI] GameManager.level_transitioning = ", GameManager.level_transitioning)
	print("[GameUI] GameManager.processing_moves = ", GameManager.processing_moves)
	print("[GameUI] GameManager.moves_left = ", GameManager.moves_left)
	print("[GameUI] LevelManager.current_level_index = ", get_node_or_null("/root/LevelManager").current_level_index if get_node_or_null("/root/LevelManager") else "N/A")
	print("[GameUI] RewardManager.levels_completed = ", RewardManager.levels_completed)

	# Calculate rewards based on score
	var base_coins = _calculate_level_coins()
	var base_gems = _calculate_level_gems()

	# Store rewards for potential multiplication
	_pending_reward_coins = base_coins
	_pending_reward_gems = base_gems
	_reward_multiplied = false

	# Hide the game board immediately
	var board = get_node_or_null("../GameBoard")
	if board:
		board.visible = false
		board.hide()
		print("[GameUI] Hidden game board for transition")

		await get_tree().create_timer(0.1).timeout
		if board.visible:
			print("[GameUI] WARNING: Game board still visible after hide()")
			board.visible = false
			board.hide()

	# Check if there's a next level
	var level_manager = get_node_or_null("/root/LevelManager")
	var has_next_level = true
	if level_manager:
		# Peek ahead to see if there's a next level (don't advance yet)
		var current_idx = level_manager.current_level_index
		has_next_level = (current_idx + 1) < level_manager.levels.size()

	# IMPORTANT: Use the level number that was just completed, not the current GameManager.level
	# which might have been updated already
	var completed_level_number = GameManager.last_level_number if GameManager.last_level_number > 0 else GameManager.level

	# Get star rating for the completed level
	var stars = StarRatingManager.get_level_stars(completed_level_number)
	print("[GameUI] get_level_stars returned:", stars, "for level", completed_level_number)
	if stars == 0:
		# If no stars saved yet, calculate based on current score
		var lvl_mgr = get_node_or_null("/root/LevelManager")
		if lvl_mgr:
			var level_data = lvl_mgr.get_level(lvl_mgr.current_level_index)
			var total_moves = level_data.moves if level_data else 20
			var moves_used = total_moves - GameManager.last_level_moves_left
			stars = StarRatingManager.calculate_stars(
				GameManager.last_level_score,
				GameManager.last_level_target,
				moves_used,
				total_moves
			)
			print("[GameUI] Calculated stars (fallback):", stars)

	print("[GameUI] Level %d completed with %d stars" % [completed_level_number, stars])

	# ALWAYS hide the old level complete panel (and ensure it STAYS hidden)
	if level_complete_panel:
		level_complete_panel.visible = false
		level_complete_panel.hide()  # Double-ensure it's hidden
		level_complete_panel.z_index = -1000  # Move it way behind everything
		print("[GameUI] 🚫 Hidden old level_complete_panel (visible=%s, z_index=%d)" % [level_complete_panel.visible, level_complete_panel.z_index])

	# game_over_panel has been removed from the scene - no need to hide it

	# Show the NEW enhanced transition screen with rewards and stars
	if level_transition:
		print("[GameUI] 🎯 Calling level_transition.show_transition()")
		print("[GameUI]    Level: %d, Score: %d, Coins: %d, Gems: %d, Stars: %d" % [completed_level_number, GameManager.score, base_coins, base_gems, stars])
		level_transition.show_transition(
			completed_level_number,
			GameManager.score,
			base_coins,
			base_gems,
			has_next_level,
			stars  # Pass star rating
		)
		print("[GameUI] ✅ Transition screen shown for level %d with rewards: %d coins, %d gems, %d stars" % [completed_level_number, base_coins, base_gems, stars])
		print("[GameUI] level_transition.visible = ", level_transition.visible)
		print("[GameUI] level_transition.z_index = ", level_transition.z_index)
	else:
		print("[GameUI] ❌ ERROR: LevelTransition is null! This should never happen!")
		print("[GameUI] ERROR: Cannot show level complete screen - transition screen missing")

func _calculate_level_coins() -> int:
	# Base coins from score (1 coin per 100 points)
	var score_coins = GameManager.score / 100
	# Bonus for moves remaining (10 coins per move)
	var moves_bonus = GameManager.moves_left * 10
	return score_coins + moves_bonus

func _calculate_level_gems() -> int:
	# Gems are rarer - 1 gem per 500 points
	var score_gems = GameManager.score / 500
	# Bonus gem for completing with >50% moves remaining
	var total_moves = 30  # Could get this from level data
	if GameManager.moves_left > total_moves / 2:
		score_gems += 1
	return max(score_gems, 1)  # At least 1 gem per level

# DEPRECATED FUNCTIONS REMOVED
# _show_level_complete_with_ad_option() - Replaced by LevelTransition screen
# _on_ad_multiplier_pressed() - Replaced by LevelTransition multiplier system
# _on_reward_ad_completed() - Replaced by LevelTransition ad handling

	# Play reward sound
	AudioManager.play_sfx("reward_earned")

# Tracking variables for reward multiplication
var _pending_reward_coins: int = 0
var _pending_reward_gems: int = 0
var _reward_multiplied: bool = false

func show_panel(panel: Control):
	# Make panel visible and modal (capture input) so underlying game board doesn't receive clicks
	panel.visible = true
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Ensure the panel can receive focus so button presses work reliably
	if panel.has_method("grab_focus"):
		panel.grab_focus()
	panel.modulate = Color.TRANSPARENT

	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)

func hide_panel(panel: Control):
	# Fade out then hide and release input capture
	_panel_to_hide = panel
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.TRANSPARENT, 0.3)
	# When tween finishes, call the finish handler (no extra args allowed by tween_callback)
	tween.tween_callback(Callable(self, "_finish_hide_panel"))

func _finish_hide_panel():
	if _panel_to_hide and _panel_to_hide is Control:
		_panel_to_hide.visible = false
		_panel_to_hide.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# release focus if held
		if _panel_to_hide.has_method("release_focus"):
			_panel_to_hide.release_focus()
		print("[GameUI] Panel hidden: %s" % _panel_to_hide.name)
		_panel_to_hide = null

# Old restart function removed - enhanced game over screen uses _on_game_over_retry() instead
#func _on_restart_pressed():
#	AudioManager.play_sfx("ui_click")
#	hide_panel(game_over_panel)
#	await get_tree().create_timer(0.3).timeout
#	restart_game()

func _on_continue_pressed():
	AudioManager.play_sfx("ui_click")

	# Grant the pending rewards
	if _pending_reward_coins > 0 or _pending_reward_gems > 0:
		RewardManager.add_coins(_pending_reward_coins)
		RewardManager.add_gems(_pending_reward_gems)
		print("[GameUI] Granted rewards: %d coins, %d gems" % [_pending_reward_coins, _pending_reward_gems])

		# Show reward notification
		if reward_notification:
			reward_notification.show_reward("level_complete", _pending_reward_coins, "Level Complete!")

		# Reset pending rewards
		_pending_reward_coins = 0
		_pending_reward_gems = 0
		_reward_multiplied = false

	hide_panel(level_complete_panel)

	# Advance to next level
	_advance_to_next_level()

func _on_transition_rewards_claimed():
	"""Called when rewards are claimed from the transition screen"""
	print("[GameUI] Transition rewards claimed")
	# Rewards are already granted in LevelTransition.gd
	# Just log this for tracking

func _on_transition_continue():
	"""Called when player presses continue on the transition screen"""
	print("[GameUI] Transition continue pressed")

	# Advance to next level
	_advance_to_next_level()

func _advance_to_next_level():
	print("[GameUI] Advancing to next level")

	# Move to next level in LevelManager
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		print("[GameUI] Before advance: current_level_index = ", level_manager.current_level_index, ", levels_completed = ", RewardManager.levels_completed)
		var has_next = level_manager.advance_to_next_level()
		print("[GameUI] After advance: current_level_index = ", level_manager.current_level_index, ", has_next = ", has_next)
		if not has_next:
			print("[GameUI] No more levels available")
			# Could show a "game complete" screen here
			return

	# Reload the level in GameManager (but don't consume a life since lives are removed)
	if GameManager:
		# Reset GameManager state for new level
		GameManager.level_transitioning = false
		GameManager.initialized = false

		# Load the new level
		await GameManager.load_current_level()

		print("[GameUI] Next level loaded: ", GameManager.level)

	# Show start page for next level
	show_start_page()

func show_start_page():
	"""Show the start page for the current level"""
	print("[GameUI] Showing start page for level ", GameManager.level)

	# Hide game board
	var board = get_node_or_null("../GameBoard")
	if board:
		board.visible = false

		# Also clear any drawn borders so StartPage doesn't show a board-shaped border
		if board.has_method("_clear_board_borders"):
			board._clear_board_borders()
		# Hide tile overlay if present
		if board.has_method("hide_tile_overlay"):
			board.hide_tile_overlay()

	# Hide transition screen if visible
	if level_transition:
		level_transition.visible = false

	# Show start page
	if start_page:
		start_page.visible = true
		# Update level info
		var lm = get_node_or_null('/root/LevelManager')
		if lm:
			var lvl = lm.get_current_level()
			if lvl and start_page.has_method('set_level_info'):
				start_page.set_level_info(lvl.level_number, lvl.description)

func _on_menu_pressed():
	# Play UI click sound
	AudioManager.play_sfx("ui_click")

	# Show the popup menu anchored to the menu button
	if main_menu_popup and menu_button:
		main_menu_popup.set_position(menu_button.get_global_position())
		main_menu_popup.popup()
		print("[GameUI] Main menu popup opened")

func restart_game():
	# Reset GameManager completely (just like starting fresh)
	GameManager.level_transitioning = false
	GameManager.initialized = false

	# Show the board so it can receive signals
	var board = get_node_or_null("../GameBoard")
	if board:
		board.visible = true

	# Reinitialize the game exactly like we do when starting from StartPage
	await GameManager.initialize_game()

	# Update UI
	update_display()
	update_booster_ui()


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

# ============================================
# Currency Display Functions
# ============================================

func update_currency_display():
	# Instead of using emojis, we'll update the labels to show icon+text
	# Note: For now keeping simple text, but could enhance with TextureRect icons
	_update_coins_display(RewardManager.get_coins())
	_update_gems_display(RewardManager.get_gems())

	# Hide lives display - no longer using lives system
	if lives_label:
		lives_label.visible = false

func _update_coins_display(amount: int):
	"""Update coins label - replace with icon in parent container"""
	if not coins_label:
		return

	# Get parent container
	var parent = coins_label.get_parent()
	if not parent:
		coins_label.text = "%d" % amount
		return

	# Check if we already created icon display
	var icon_display = parent.get_node_or_null("CoinsIconDisplay")
	if not icon_display:
		# Hide old label
		coins_label.visible = false

		# Create new display with icon (increased size for better visibility)
		icon_display = ThemeManager.create_currency_display("coins", amount, 32, 28, Color.WHITE)
		icon_display.name = "CoinsIconDisplay"
		parent.add_child(icon_display)
	else:
		# Update existing display
		var label = icon_display.get_child(1) as Label  # Icon is child 0, label is child 1
		if label:
			label.text = str(amount)

func _update_gems_display(amount: int):
	"""Update gems label - replace with icon in parent container"""
	if not gems_label:
		return

	# Get parent container
	var parent = gems_label.get_parent()
	if not parent:
		gems_label.text = "%d" % amount
		return

	# Check if we already created icon display
	var icon_display = parent.get_node_or_null("GemsIconDisplay")
	if not icon_display:
		# Hide old label
		gems_label.visible = false

		# Create new display with icon (increased size for better visibility)
		icon_display = ThemeManager.create_currency_display("gems", amount, 32, 28, Color.WHITE)
		icon_display.name = "GemsIconDisplay"
		parent.add_child(icon_display)
	else:
		# Update existing display
		var label = icon_display.get_child(1) as Label  # Icon is child 0, label is child 1
		if label:
			label.text = str(amount)

func _reorganize_hud():
	"""Reorganize HUD for better gameplay layout based on design spec:
	- Top bar: Moves | Score | Goal (centered, clean)
	- Currency moved to top right corner
	- Boosters on left/right edges
	- Combo text displays briefly then fades
	"""
	print("[GameUI] Reorganizing HUD for better gameplay layout")

	# Get the top panel
	var top_panel = $VBoxContainer/TopPanel
	if not top_panel:
		print("[GameUI] TopPanel not found, skipping reorganization")
		return

	# Make top panel a clean HBoxContainer for horizontal layout
	if top_panel is HBoxContainer:
		# Clear default alignment and spacing
		top_panel.alignment = BoxContainer.ALIGNMENT_CENTER
		top_panel.add_theme_constant_override("separation", 40)

	# Add header labels above the values for clarity
	_add_header_label_to_container($VBoxContainer/TopPanel/MovesContainer, "MOVES")
	_add_header_label_to_container($VBoxContainer/TopPanel/ScoreContainer, "SCORE")
	_add_header_label_to_container($VBoxContainer/TopPanel/TargetContainer, "GOAL")

	# Create a cleaner layout - hide level label (redundant with start page)
	if level_label and level_label.get_parent():
		var level_container = level_label.get_parent()
		if level_container:
			level_container.visible = false

	# Simplify labels - remove "Score:", "Moves:" prefixes for cleaner look
	if score_label:
		score_label.add_theme_font_size_override("font_size", 32)
		score_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # Gold color
	if moves_label:
		moves_label.add_theme_font_size_override("font_size", 32)
		moves_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))  # Cyan color
	if target_label:
		target_label.add_theme_font_size_override("font_size", 20)

	# Move currency to top right corner (compact display)
	var currency_panel = $VBoxContainer/CurrencyPanel
	if currency_panel:
		# Keep it compact and in the corner
		currency_panel.size_flags_horizontal = Control.SIZE_SHRINK_END

	# Move booster panel to side (we'll position it on edges in update_booster_ui)
	if booster_panel:
		booster_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		booster_panel.add_theme_constant_override("separation", 10)

	print("[GameUI] HUD reorganization complete")

func _add_header_label_to_container(container: Node, header_text: String):
	"""Add a small header label above a value in a container"""
	if not container or not container is VBoxContainer:
		return

	# Check if header already exists
	if container.get_child_count() > 0 and container.get_child(0).name == "HeaderLabel":
		return

	var header = Label.new()
	header.name = "HeaderLabel"
	header.text = header_text
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.8))

	# Move to front
	container.add_child(header)
	container.move_child(header, 0)

func _on_coins_changed(new_amount: int):
	_update_coins_display(new_amount)
	# Animate the icon display if it exists
	var parent = coins_label.get_parent() if coins_label else null
	if parent:
		var icon_display = parent.get_node_or_null("CoinsIconDisplay")
		if icon_display:
			animate_currency_change(icon_display)

func _on_gems_changed(new_amount: int):
	_update_gems_display(new_amount)
	# Animate the icon display if it exists
	var parent = gems_label.get_parent() if gems_label else null
	if parent:
		var icon_display = parent.get_node_or_null("GemsIconDisplay")
		if icon_display:
			animate_currency_change(icon_display)

func _on_lives_changed(new_amount: int):
	# Lives system removed - keeping function for compatibility
	pass

func _on_booster_changed(booster_type: String, new_amount: int):
	"""Handle booster count changes"""
	print("[GameUI] Booster changed: ", booster_type, " = ", new_amount)
	update_booster_ui()

func animate_currency_change(control: Control):
	"""Animate currency change - works with Label or HBoxContainer"""
	if not control:
		return

	var tween = create_tween()
	tween.tween_property(control, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(control, "scale", Vector2.ONE, 0.15)
	tween.tween_property(control, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(control, "modulate", Color.WHITE, 0.2)

# ============================================
# Phase 2: Shop and Dialog Functions
# ============================================

func _on_shop_pressed():
	"""Open the shop"""
	# Use the side-panel slide-in behaviour instead of the old modal shop
	_show_shop_side()
	print("[GameUI] Shop opened (side panel)")

func _on_shop_closed():
	"""Handle shop close"""
	print("[GameUI] Shop closed signal received")
	_close_fullscreen_panel(shop_ui)

func _on_settings_closed():
	print("[GameUI] Settings closed signal received")
	var inst = get_node_or_null("SettingsDialog")
	if inst:
		_close_fullscreen_panel(inst)

func _on_item_purchased(item_type: String, cost_type: String, cost_amount: int):
	"""Handle item purchase from shop"""
	print("[GameUI] Purchased: %s for %d %s" % [item_type, cost_amount, cost_type])

	# Show reward notification
	if reward_notification:
		if reward_notification.has_method("show_reward"):
			if item_type == "lives_refill":
				reward_notification.show_reward("lives", 5, "Lives refilled!")
			else:
				reward_notification.show_reward("booster", 1, "%s booster added!" % item_type.capitalize())
		else:
			print("[GameUI] reward_notification missing show_reward method")

func _show_out_of_lives_dialog():
	"""Show the out of lives dialog"""
	print("[GameUI] _show_out_of_lives_dialog called")
	if out_of_lives_dialog:
		print("[GameUI] OutOfLivesDialog node exists")
		# Bring dialog to front
		if out_of_lives_dialog.get_parent():
			out_of_lives_dialog.get_parent().move_child(out_of_lives_dialog, -1)

		if out_of_lives_dialog.has_method("show_dialog"):
			print("[GameUI] Calling show_dialog() method")
			out_of_lives_dialog.show_dialog()
		elif out_of_lives_dialog is Control:
			print("[GameUI] Manually setting visible = true")
			out_of_lives_dialog.visible = true
		else:
			print("[GameUI] OutOfLivesDialog exists but has no show_dialog")
		print("[GameUI] Dialog visible state: ", out_of_lives_dialog.visible)
	else:
		print("[GameUI] ERROR: out_of_lives_dialog is null!")

func _on_refill_requested(method: String):
	"""Handle life refill from dialog"""
	print("[GameUI] Lives refilled via: %s" % method)

	# Don't show notification - it's annoying
	# if reward_notification:
	# 	if reward_notification.has_method("show_reward"):
	# 		reward_notification.show_reward("lives", RewardManager.get_lives(), "Lives restored!")
	# 	else:
	# 		print("[GameUI] reward_notification missing show_reward method")

	# If the game wasn't initialized because player had no lives when app launched,
	# initialize/load the level now so the board appears immediately.
	if RewardManager.get_lives() > 0:
		# GameManager is an autoload singleton; check whether its grid is empty
		if Engine.has_singleton("GameManager") or true:
			# Use the global GameManager object (autoload)
			var gm = GameManager
			if gm and (not gm.grid or gm.grid.size() == 0):
				print("[GameUI] Detected uninitialized board after refill - initializing game now")
				# Re-initialize game which will consume a life and load the level
				if gm.has_method("initialize_game"):
					gm.initialize_game()
				else:
					# Fallback: try loading current level
					if gm.has_method("load_current_level"):
						gm.load_current_level()
						print("[GameUI] Called load_current_level() as fallback")
					else:
						print("[GameUI] ERROR: GameManager has no initialize/load method")
			else:
				print("[GameUI] GameManager already initialized - no action needed")

	# DON'T automatically start game - let the dialog close naturally (legacy comment preserved)
	# The player can see their lives increased and manually start when ready
	print("[GameUI] Life granted. Player now has %d lives" % RewardManager.get_lives())

func _on_out_of_lives_closed():
	"""Handle out of lives dialog close"""
	print("[GameUI] Out of lives dialog closed")

	# If still no lives, go back to menu
	if RewardManager.get_lives() <= 0:
		print("[GameUI] Still no lives, returning to menu")
		await get_tree().create_timer(0.5).timeout
		_on_menu_pressed()

func _on_hammer_pressed():
	"""Handle hammer button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("hammer") > 0:
		activate_booster("hammer")
		print("[GameUI] Hammer activated")

func _on_shuffle_pressed():
	"""Handle shuffle button press - immediately shuffles board"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("shuffle") > 0:
		print("[GameUI] Shuffle activated")
		var board = get_node("../GameBoard")
		if board:
			await board.activate_shuffle_booster()
			update_booster_ui()

func _on_swap_pressed():
	"""Handle swap button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("swap") > 0:
		activate_booster("swap")
		swap_first_tile = null  # Reset swap state
		print("[GameUI] Swap activated - select first tile")

func _on_chain_reaction_pressed():
	"""Handle chain reaction button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("chain_reaction") > 0:
		activate_booster("chain_reaction")
		print("[GameUI] Chain Reaction activated")

func _on_bomb_3x3_pressed():
	"""Handle 3x3 bomb button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("bomb_3x3") > 0:
		activate_booster("bomb_3x3")
		print("[GameUI] 3x3 Bomb activated")

func _on_line_blast_pressed():
	"""Handle line blast button press - need to choose direction first"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("line_blast") > 0:
		# Show direction selector or default to horizontal for now
		# For simplicity, we'll prompt in console and default to horizontal
		activate_booster("line_blast")
		line_blast_direction = "horizontal"  # Can be changed to show UI selector
		print("[GameUI] Line Blast activated - tap tile for center (horizontal mode)")

func _on_tile_squasher_pressed():
	"""Handle tile squasher button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("tile_squasher") > 0:
		activate_booster("tile_squasher")
		print("[GameUI] Tile Squasher activated")

func _on_row_clear_pressed():
	"""Handle row clear button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("row_clear") > 0:
		activate_booster("row_clear")
		print("[GameUI] Row clear activated")

func _on_column_clear_pressed():
	"""Handle column clear button press"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.get_booster_count("column_clear") > 0:
		activate_booster("column_clear")
		print("[GameUI] Column clear activated")

func _on_extra_moves_pressed():
	"""Handle extra moves button press - instant use, no targeting needed"""
	AudioManager.play_sfx("ui_click")
	if RewardManager.use_booster("extra_moves"):
		# Add 5 extra moves to the game
		GameManager.moves_left += 5
		GameManager.emit_signal("moves_changed", GameManager.moves_left)
		print("[GameUI] Extra moves activated - added 5 moves")

		# Show feedback to player
		if reward_notification:
			reward_notification.show_reward("extra_moves", 5, "+5 Moves!")

		# Update booster UI
		update_booster_ui()
	else:
		print("[GameUI] No extra moves available!")

func activate_booster(booster_type: String):
	"""Activate the selected booster - wait for user to select row/column/tile"""
	booster_mode_active = true
	active_booster_type = booster_type

	# Update button states to show which is active (set all to white, then active to yellow)
	var all_buttons = [hammer_button, shuffle_button, swap_button, chain_reaction_button,
					   bomb_3x3_button, line_blast_button, tile_squasher_button,
					   row_clear_button, column_clear_button]

	for btn in all_buttons:
		if btn:
			btn.modulate = Color.WHITE

	# Highlight active button
	match booster_type:
		"hammer":
			if hammer_button: hammer_button.modulate = Color.YELLOW
		"swap":
			if swap_button: swap_button.modulate = Color.YELLOW
		"chain_reaction":
			if chain_reaction_button: chain_reaction_button.modulate = Color.YELLOW
		"bomb_3x3":
			if bomb_3x3_button: bomb_3x3_button.modulate = Color.YELLOW
		"line_blast":
			if line_blast_button: line_blast_button.modulate = Color.YELLOW
		"tile_squasher":
			if tile_squasher_button: tile_squasher_button.modulate = Color.YELLOW
		"row_clear":
			if row_clear_button: row_clear_button.modulate = Color.YELLOW
		"column_clear":
			if column_clear_button: column_clear_button.modulate = Color.YELLOW

	var message = ""
	match booster_type:
		"hammer":
			message = "Hammer active. Tap a tile to destroy it."
		"swap":
			message = "Swap active. Tap first tile, then second tile to swap them."
		"chain_reaction":
			message = "Chain Reaction active. Tap a tile to start spreading explosion."
		"bomb_3x3":
			message = "3x3 Bomb active. Tap a tile to destroy 3x3 area around it."
		"line_blast":
			message = "Line Blast active (horizontal). Tap a tile for center of 3 rows."
		"tile_squasher":
			message = "Tile Squasher active. Tap a tile to destroy all tiles of that type."
		"row_clear":
			message = "Row Clear active. Tap a tile to clear its row."
		"column_clear":
			message = "Column Clear active. Tap a tile to clear its column."

	print("[GameUI] ", message)

func update_booster_ui():
	"""Update the booster panel UI to show only available boosters for this level"""
	print("[GameUI] update_booster_ui called")
	print("[GameUI] GameManager.available_boosters size: ", GameManager.available_boosters.size())
	print("[GameUI] Available boosters: ", GameManager.available_boosters)

	# Ensure booster panel exists
	if not booster_panel:
		print("[GameUI] WARNING: booster_panel not found in scene!")
		return

	# Check if we should rebuild the booster panel (on level load)
	if GameManager.available_boosters.size() > 0:
		print("[GameUI] Rebuilding dynamic booster panel with selected boosters")
		_rebuild_dynamic_booster_panel()
	else:
		print("[GameUI] No boosters selected, using legacy display")
		# Fallback: show all boosters (for compatibility)
		_update_all_boosters_legacy()

	# Always show the booster panel
	if booster_panel:
		booster_panel.visible = true
		print("[GameUI] Booster panel visible")

func _rebuild_dynamic_booster_panel():
	"""Rebuild the booster panel with only the selected boosters for this level"""
	if not booster_panel:
		print("[GameUI] ERROR: booster_panel not found, cannot rebuild")
		return

	print("[GameUI] Rebuilding booster panel with: ", GameManager.available_boosters)

	# Clear existing booster buttons
	var hbox = booster_panel.get_node_or_null("HBoxContainer")
	if not hbox:
		print("[GameUI] Creating new HBoxContainer for boosters")
		hbox = HBoxContainer.new()
		hbox.name = "HBoxContainer"
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		booster_panel.add_child(hbox)
	else:
		print("[GameUI] Found existing HBoxContainer, clearing %d children" % hbox.get_child_count())

	# Clear all children
	for child in hbox.get_children():
		child.queue_free()

	# Style the booster panel
	_style_booster_panel()

	# Add spacing between buttons
	hbox.add_theme_constant_override("separation", 16)

	# Create buttons for selected boosters
	var button_count = 0
	for booster_id in GameManager.available_boosters:
		var button = _create_booster_button(booster_id)
		if button:
			hbox.add_child(button)
			button_count += 1
			print("[GameUI]   Added button for booster: %s" % booster_id)
		else:
			print("[GameUI]   WARNING: Failed to create button for booster: %s" % booster_id)

	print("[GameUI] Booster panel rebuilt with %d boosters" % button_count)

func _style_booster_panel():
	"""Apply visual styling to the booster panel"""
	if not booster_panel:
		return

	# Add rounded background with gradient
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color(0.15, 0.15, 0.2, 0.85)  # Semi-transparent dark background
	style_box.corner_radius_top_left = 12
	style_box.corner_radius_top_right = 12
	style_box.corner_radius_bottom_left = 12
	style_box.corner_radius_bottom_right = 12
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.border_color = Color(0.4, 0.4, 0.5, 0.6)
	style_box.content_margin_left = 12
	style_box.content_margin_right = 12
	style_box.content_margin_top = 8
	style_box.content_margin_bottom = 8

	booster_panel.add_theme_stylebox_override("panel", style_box)

func _create_booster_button(booster_id: String) -> Button:
	"""Create a styled booster button with icon and count"""
	var button = Button.new()
	button.name = "%sButton" % booster_id.capitalize()
	button.custom_minimum_size = Vector2(80, 80)
	button.mouse_filter = Control.MOUSE_FILTER_STOP

	# Load icon
	var theme = ThemeManager.get_theme_name()
	var icon_path = "res://textures/%s/booster_%s.png" % [theme, booster_id]

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists(icon_path):
		icon.texture = load(icon_path)
	else:
		print("[GameUI] WARNING: Icon not found: %s" % icon_path)

	# Center icon in button
	icon.anchor_left = 0.5
	icon.anchor_top = 0.5
	icon.anchor_right = 0.5
	icon.anchor_bottom = 0.5
	icon.offset_left = -32
	icon.offset_top = -32
	icon.offset_right = 32
	icon.offset_bottom = 32

	button.add_child(icon)

	# Add count label (top-right corner)
	var count_label = Label.new()
	count_label.name = "CountLabel"
	var count = RewardManager.get_booster_count(booster_id)
	count_label.text = "%d" % count
	ThemeManager.apply_bangers_font(count_label, 18)
	count_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
	count_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	count_label.add_theme_constant_override("outline_size", 2)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Position in top-right corner
	count_label.anchor_left = 1.0
	count_label.anchor_top = 0.0
	count_label.anchor_right = 1.0
	count_label.anchor_bottom = 0.0
	count_label.offset_left = -28
	count_label.offset_top = 4
	count_label.offset_right = -4
	count_label.offset_bottom = 24
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	button.add_child(count_label)

	# Apply styling based on count
	button.disabled = (count <= 0)
	if count > 0:
		icon.modulate = Color.WHITE
		button.modulate = Color.WHITE
	else:
		icon.modulate = Color(0.5, 0.5, 0.5, 0.5)
		button.modulate = Color(0.7, 0.7, 0.7, 0.8)

	# Connect button press to booster handler
	button.pressed.connect(_on_booster_button_pressed.bind(booster_id))

	return button

func _on_booster_button_pressed(booster_id: String):
	"""Handle dynamic booster button press"""
	print("[GameUI] Booster pressed: %s" % booster_id)

	# Call appropriate handler based on booster type
	match booster_id:
		"hammer":
			_on_hammer_pressed()
		"shuffle":
			_on_shuffle_pressed()
		"swap":
			_on_swap_pressed()
		"chain_reaction":
			_on_chain_reaction_pressed()
		"bomb_3x3":
			_on_bomb_3x3_pressed()
		"line_blast":
			_on_line_blast_pressed()
		"row_clear":
			_on_row_clear_pressed()
		"column_clear":
			_on_column_clear_pressed()
		"tile_squasher":
			_on_tile_squasher_pressed()
		"extra_moves":
			_on_extra_moves_pressed()

func _update_all_boosters_legacy():
	"""Legacy function: Update all boosters (fallback when no selection is made)"""
	print("[GameUI] Using legacy booster update (all boosters)")

	# Update all boosters
	_update_single_booster(hammer_button, hammer_icon, hammer_count_label, "hammer")
	_update_single_booster(shuffle_button, shuffle_icon, shuffle_count_label, "shuffle")
	_update_single_booster(swap_button, swap_icon, swap_count_label, "swap")
	_update_single_booster(chain_reaction_button, chain_reaction_icon, chain_reaction_count_label, "chain_reaction")
	_update_single_booster(bomb_3x3_button, bomb_3x3_icon, bomb_3x3_count_label, "bomb_3x3")
	_update_single_booster(line_blast_button, line_blast_icon, line_blast_count_label, "line_blast")
	_update_single_booster(tile_squasher_button, tile_squasher_icon, tile_squasher_count_label, "tile_squasher")
	_update_single_booster(row_clear_button, row_clear_icon, row_clear_count_label, "row_clear")
	_update_single_booster(column_clear_button, column_clear_icon, column_clear_count_label, "column_clear")


func _update_single_booster(button, icon, count_label, booster_type: String):
	"""Helper function to update a single booster button"""
	var count = RewardManager.get_booster_count(booster_type)

	if count_label:
		count_label.text = "%d" % count

	if button:
		button.disabled = (count <= 0)
		# Grey out when unavailable (0 count)
		if icon:
			if count > 0:
				icon.modulate = Color.WHITE
			else:
				icon.modulate = Color(0.5, 0.5, 0.5, 0.5)
		if count > 0:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.7, 0.7, 0.7, 0.8)

func _on_booster_used(booster_type: String):
	"""Handle the event when a booster is used"""
	print("[GameUI] Booster used: %s" % booster_type)

	# Play booster animation or sound
	var animation_player = $AnimationPlayer
	animation_player.play("booster_used")

	# Reset booster mode
	booster_mode_active = false
	active_booster_type = ""

	# Update UI
	update_booster_ui()

func _on_main_menu_item_selected(id: int):
	"""Handle main menu popup item selection (robust implementation).
	This avoids match/else parsing issues and ensures we only set `visible` on Controls.
	"""
	print("[GameUI] Main menu item selected: ", id)

	# Play UI click sound
	AudioManager.play_sfx("ui_click")

	if id == 0:
		# Settings - slide-in side panel
		print("[GameUI] Open settings (side panel)")
		_show_settings_side()
	elif id == 1:
		# Shop - slide-in side panel
		print("[GameUI] Open shop (side panel)")
		_show_shop_side()
	elif id == 2:
		# Gallery - fullscreen
		print("[GameUI] Open gallery")
		_show_gallery_fullscreen()
	elif id == 3:
		# About
		print("[GameUI] Show about dialog")
		var adlg = _find_or_instance_dialog("AboutDialog", "res://scenes/AboutDialog.tscn")
		if adlg:
			if adlg.has_method("show_dialog"):
				adlg.show_dialog()
			elif adlg is Control:
				adlg.visible = true
				adlg.raise()
			else:
				print("[GameUI] AboutDialog exists but is not a Control")
			# Ensure we are connected to its dialog_closed signal so we know when it closes
			if adlg.has_signal("dialog_closed"):
				var cb = Callable(self, "_on_about_dialog_closed")
				if not adlg.is_connected("dialog_closed", cb):
					adlg.connect("dialog_closed", cb)
		else:
			print("[GameUI] Unable to open AboutDialog")
	elif id == 4:
		# Share
		print("[GameUI] Share the game")
		# TODO: Implement share functionality

func _on_menu_icon_input(event):
	"""Handle input on the runtime menu icon"""
	if event is InputEventScreenTouch and event.pressed:
		# Simulate a menu button press
		menu_button.emit_signal("pressed")
		print("[GameUI] Menu icon runtime pressed")

# New helper moved to top-level to avoid nested function lambda issue
func _find_or_instance_dialog(name: String, scene_path: String):
	var node = get_node_or_null(name)
	if node and not (node is Control):
		# Replace placeholder node (non-Control) with a real instance
		print("[GameUI] Replacing placeholder for %s" % name)
		var parent = node.get_parent()
		node.queue_free()
		node = null
	if not node:
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed and packed is PackedScene:
				node = packed.instantiate()
				node.name = name
				# attach to this UI node so dialog sits in correct tree
				add_child(node)
				print("[GameUI] Instanced %s from %s" % [name, scene_path])
				# If the dialog defines a `dialog_closed` signal, connect it to a handler
				if node.has_signal("dialog_closed"):
					node.connect("dialog_closed", Callable(self, "_on_about_dialog_closed"))
				# Also connect the dialog's CloseButton directly to a UI handler to ensure it closes
				if node.has_node("VBoxContainer/CloseButton"):
					var cb = node.get_node("VBoxContainer/CloseButton")
					if cb and cb is Button:
						# Connect using a small inline function that captures the dialog node to avoid overload ambiguity
						cb.pressed.connect(Callable(self, "_on_dialog_close_pressed"))
			else:
				print("[GameUI] Failed to load packed scene: %s" % scene_path)
		else:
			print("[GameUI] Scene not found: %s" % scene_path)
	return node

func _on_about_dialog_closed(dialog_node):
	print("[GameUI] About dialog closed: ", dialog_node)
	# If dialog was instanced dynamically, free it
	if dialog_node and dialog_node.get_parent() == self:
		dialog_node.queue_free()
		print("[GameUI] Freed runtime-instanced AboutDialog")

func _on_dialog_close_pressed(dialog_node):
	if dialog_node and dialog_node is Control:
		var t = create_tween()
		t.tween_property(dialog_node, "modulate", Color.TRANSPARENT, 0.15)
		# Wait for the tween to finish, then call the finish handler with the dialog node
		await t.finished
		_finish_hide_dialog(dialog_node)

func _finish_hide_dialog(dialog_node):
	if dialog_node and dialog_node is Control:
		dialog_node.visible = false
		print("[GameUI] Dialog closed via GameUI handler: %s" % dialog_node.name)

func _ensure_side_panel(side_pos: String = "right"):
	var side = get_node_or_null("SidePanel")
	var vp = get_viewport().get_visible_rect().size
	_side_position = side_pos
	# Compute responsive panel width (max cap)
	var panel_width = int(min(SIDE_PANEL_MAX_WIDTH, vp.x * SIDE_PANEL_WIDTH_PERCENT))
	if not side:
		side = Panel.new()
		side.name = "SidePanel"
		# Use absolute positioning: anchor to top-left and control rect_position/rect_size
		side.anchor_left = 0
		side.anchor_top = 0
		side.anchor_right = 0
		side.anchor_bottom = 0
		side.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(side)
	# Size and offscreen position (to the right or left)
	# side.rect_size = Vector2(panel_width, vp.y)
	side.custom_minimum_size = Vector2(panel_width, vp.y)
	if side_pos == "right":
		side.position = Vector2(vp.x, 0)
		# start invisible
		side.modulate = Color(1,1,1,0)
	else:
		side.position = Vector2(-panel_width, 0)
		side.modulate = Color(1,1,1,0)
	side.visible = true
	# store last panel width for animations and sizing
	side.set_meta("panel_width", panel_width)
	return side

func _show_settings_side():
	# Present Settings as a fullscreen page that slides in from the LEFT and hides the board
	var vp = get_viewport().get_visible_rect().size
	var panel_width = vp.x

	# Ensure we have a Settings node; if not, instance it
	var scene_path = "res://scenes/SettingsDialog.tscn"
	var inst = get_node_or_null("SettingsDialog")
	if not inst:
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed and packed is PackedScene:
				inst = packed.instantiate()
				inst.name = "SettingsDialog"
				add_child(inst)
				print("[GameUI] Instanced SettingsDialog (fullscreen)")
				# connect its dialog_closed signal if present to our close handler
				if inst.has_signal("dialog_closed"):
					inst.connect("dialog_closed", Callable(self, "_on_settings_closed"))
				# also try to hook a CloseButton if present
				if inst.has_node("VBoxContainer/CloseButton"):
					var cb = inst.get_node("VBoxContainer/CloseButton")
					if cb and cb is Button:
						cb.pressed.connect(Callable(self, "_on_settings_closed"))
			else:
				print("[GameUI] Failed to load SettingsDialog scene for fullscreen")
		else:
			print("[GameUI] SettingsDialog scene not found: %s" % scene_path)

	if inst and inst is Control:
		# Configure as fullscreen
		inst.anchor_left = 0
		inst.anchor_top = 0
		inst.anchor_right = 1
		inst.anchor_bottom = 1
		# start offscreen to the left (GameUI will animate position)
		inst.position = Vector2(-vp.x, 0)
		inst.size = vp
		inst.visible = true
		inst.mouse_filter = Control.MOUSE_FILTER_STOP
		# mark origin so close routine knows where to slide out
		inst.set_meta("fullscreen_origin", "left")
		# call show helper if present
		if inst.has_method("show_dialog"):
			inst.call("show_dialog")

	# Slide the board to the right and animate the settings in
	var board = get_node_or_null("../GameBoard")
	var tween = create_tween()
	if board:
		# Hide the board and its overlay completely
		board.visible = false

		# Also hide the tile area overlay using GameBoard method
		if board.has_method("hide_tile_overlay"):
			board.hide_tile_overlay()
	# animate panel in
	if inst:
		tween.tween_property(inst, "position", Vector2(0,0), 0.35)
		tween.tween_property(inst, "modulate", Color.WHITE, 0.35)
	print("[GameUI] Settings presented fullscreen")

func _show_shop_side():
	# Present Shop as a fullscreen page that slides in from the RIGHT and hides the board
	var vp = get_viewport().get_visible_rect().size
	var panel_width = vp.x

	# Ensure shop_ui exists, if not try to instance the scene into this UI
	if not shop_ui or not is_instance_valid(shop_ui):
		var scene_path = "res://scenes/ShopUI.tscn"
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed and packed is PackedScene:
				shop_ui = packed.instantiate()
				shop_ui.name = "ShopUI"
				add_child(shop_ui)
				print("[GameUI] Instanced ShopUI (fullscreen)")
				# connect shop signals to GameUI handlers
				if shop_ui.has_signal("shop_closed"):
					shop_ui.connect("shop_closed", Callable(self, "_on_shop_closed"))
				if shop_ui.has_signal("item_purchased"):
					shop_ui.connect("item_purchased", Callable(self, "_on_item_purchased"))
				# hook CloseButton fallback
				if shop_ui.has_node("Panel/VBoxContainer/TopBar/CloseButton"):
					var scb = shop_ui.get_node("Panel/VBoxContainer/TopBar/CloseButton")
					if scb and scb is Button:
						scb.pressed.connect(Callable(self, "_on_shop_closed"))
			else:
				print("[GameUI] Failed to load ShopUI scene for fullscreen")
		else:
			print("[GameUI] ShopUI scene not found: %s" % scene_path)

	if shop_ui and shop_ui is Control:
		shop_ui.anchor_left = 0
		shop_ui.anchor_top = 0
		shop_ui.anchor_right = 1
		shop_ui.anchor_bottom = 1		# start offscreen to right (GameUI will animate position)
		shop_ui.position = Vector2(vp.x, 0)
		shop_ui.size = vp
		shop_ui.visible = true
		shop_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		# mark origin so close routine knows where to slide out
		shop_ui.set_meta("fullscreen_origin", "right")
		# If the Shop has a show helper, call it
		if shop_ui.has_method("show_shop"):
			shop_ui.call("show_shop")

	# Slide the board left and animate the shop in
	var board = get_node_or_null("../GameBoard")
	var tween = create_tween()
	if board:
		# Hide the board and its overlay completely
		board.visible = false

		# Also hide the tile area overlay using GameBoard method
		if board.has_method("hide_tile_overlay"):
			board.hide_tile_overlay()
	if shop_ui:
		tween.tween_property(shop_ui, "position", Vector2(0,0), 0.35)
		tween.tween_property(shop_ui, "modulate", Color.WHITE, 0.35)
	print("[GameUI] Shop presented fullscreen")

func _show_gallery_fullscreen():
	"""Show the gallery as a fullscreen UI"""
	var vp = get_viewport().get_visible_rect().size

	# Ensure we have a gallery_ui instance
	if not gallery_ui or not is_instance_valid(gallery_ui):
		var gallery_script = load("res://scripts/GalleryUI.gd")
		if gallery_script:
			# Create Control node since GalleryUI extends Control
			gallery_ui = Control.new()
			gallery_ui.set_script(gallery_script)
			gallery_ui.name = "GalleryUI"

			# Create the UI structure manually since we don't have a scene file
			_create_gallery_ui_structure(gallery_ui)

			add_child(gallery_ui)
			print("[GameUI] Instanced GalleryUI (fullscreen)")

			# Connect close signal
			if gallery_ui.has_signal("gallery_closed"):
				gallery_ui.connect("gallery_closed", Callable(self, "_on_gallery_closed"))
		else:
			print("[GameUI] ERROR: Could not load GalleryUI script")
			return

	if gallery_ui and gallery_ui is Control:
		# Configure as fullscreen
		gallery_ui.anchor_left = 0
		gallery_ui.anchor_top = 0
		gallery_ui.anchor_right = 1
		gallery_ui.anchor_bottom = 1
		gallery_ui.position = Vector2(vp.x, 0)  # Start offscreen right
		gallery_ui.size = vp
		gallery_ui.visible = true
		gallery_ui.mouse_filter = Control.MOUSE_FILTER_STOP
		gallery_ui.set_meta("fullscreen_origin", "right")

		# Call show helper
		if gallery_ui.has_method("show_gallery"):
			gallery_ui.call("show_gallery")

	# Hide the board
	var board = get_node_or_null("../GameBoard")
	var tween = create_tween()
	if board:
		board.visible = false
		if board.has_method("hide_tile_overlay"):
			board.hide_tile_overlay()

	# Animate gallery in
	if gallery_ui:
		tween.tween_property(gallery_ui, "position", Vector2(0,0), 0.35)
		tween.tween_property(gallery_ui, "modulate", Color.WHITE, 0.35)
	print("[GameUI] Gallery presented fullscreen")

func _create_gallery_ui_structure(gallery_node: Node):
	"""Create the UI structure for gallery programmatically"""
	# Main panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_top = 0
	panel.offset_right = 0
	panel.offset_bottom = 0
	gallery_node.add_child(panel)

	# VBox container
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 20
	vbox.offset_top = 20
	vbox.offset_right = -20
	vbox.offset_bottom = -20
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# Top bar with title and close button
	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	vbox.add_child(top_bar)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "Gallery"
	title.add_theme_font_size_override("font_size", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(title)

	var close_btn = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(50, 50)
	top_bar.add_child(close_btn)

	# Scroll container
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	# Grid container
	var grid = GridContainer.new()
	grid.name = "GridContainer"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 20)
	scroll.add_child(grid)

	# Viewer panel (hidden by default)
	var viewer = Panel.new()
	viewer.name = "ViewerPanel"
	viewer.anchor_right = 1.0
	viewer.anchor_bottom = 1.0
	viewer.visible = false
	gallery_node.add_child(viewer)

	var viewer_vbox = VBoxContainer.new()
	viewer_vbox.name = "VBoxContainer"
	viewer_vbox.anchor_right = 1.0
	viewer_vbox.anchor_bottom = 1.0
	viewer_vbox.offset_left = 40
	viewer_vbox.offset_top = 40
	viewer_vbox.offset_right = -40
	viewer_vbox.offset_bottom = -40
	viewer.add_child(viewer_vbox)

	var image_rect = TextureRect.new()
	image_rect.name = "ImageRect"
	image_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer_vbox.add_child(image_rect)

	var image_title = Label.new()
	image_title.name = "ImageTitle"
	image_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_title.add_theme_font_size_override("font_size", 24)
	viewer_vbox.add_child(image_title)

	var viewer_close = Button.new()
	viewer_close.name = "CloseViewerButton"
	viewer_close.text = "Close"
	viewer_close.custom_minimum_size = Vector2(200, 60)
	viewer_vbox.add_child(viewer_close)

func _on_gallery_closed():
	"""Handle gallery close"""
	print("[GameUI] Gallery closed signal received")
	if gallery_ui:
		_close_fullscreen_panel(gallery_ui)

func _close_fullscreen_panel(panel: Control):
	"""Animate a fullscreen panel out (based on its origin meta) and restore the board."""
	if not panel or not (panel is Control):
		return
	var vp = get_viewport().get_visible_rect().size
	var origin = "right"
	if panel.has_meta("fullscreen_origin"):
		origin = panel.get_meta("fullscreen_origin")

	# Animate panel out and restore board
	var tween = create_tween()
	if origin == "right":
		tween.tween_property(panel, "position", Vector2(vp.x, 0), 0.35)
	else:
		tween.tween_property(panel, "position", Vector2(-vp.x, 0), 0.35)

	var board = get_node_or_null("../GameBoard")
	if board:
		# Restore board visibility
		board.visible = true

		# Also restore the tile area overlay using GameBoard method
		if board.has_method("show_tile_overlay"):
			board.show_tile_overlay()

	await tween.finished
	# hide the panel after animation
	panel.visible = false
	print("[GameUI] Fullscreen panel closed: %s" % panel.name)

func _on_startpage_start_pressed():
	print("[GameUI] Start pressed on StartPage - initializing game")

	# Play UI click sound and switch to game music
	AudioManager.play_sfx("ui_click")
	AudioManager.play_music("game", 1.0)

	# Immediately hide StartPage to prevent board borders being drawn on top of it
	if start_page:
		start_page.visible = false

	# Show a quick loading indicator (simple label) so user knows something is happening
	var loading_label = Label.new()
	loading_label.name = "StartLoadingLabel"
	loading_label.text = "Loading level..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.add_theme_font_size_override("font_size", 24)
	add_child(loading_label)

	# Ensure we remove any previous borders so the StartPage remains clean
	var board_check = get_node_or_null("../GameBoard")
	if board_check and board_check.has_method("_clear_board_borders"):
		board_check._clear_board_borders()

	# If GameManager already initialized, shortcut (existing code)
	if GameManager.initialized:
		# Show game board immediately
		var board = get_node_or_null("../GameBoard")
		if board:
			board.visible = true
			if board.has_method("_on_level_loaded"):
				board._on_level_loaded()
			if board.has_method("draw_board_borders"):
				board.draw_board_borders()
			if board.has_method("show_tile_overlay"):
				board.show_tile_overlay()
		# Cleanup loading indicator
		if loading_label and is_instance_valid(loading_label):
			loading_label.queue_free()
		update_display()
		update_booster_ui()
		return

	# Otherwise, trigger GameManager initialization/load and wait for level_loaded signal
	var gm = get_node_or_null("/root/GameManager")
	if not gm:
		print("[GameUI] ERROR: GameManager not found; cannot initialize game")
		# Restore start page
		if start_page:
			start_page.visible = true
		if loading_label and is_instance_valid(loading_label):
			loading_label.queue_free()
		return

	# Connect temporary signal handler to detect level_loaded
	_level_loaded_flag = false
	if not GameManager.is_connected("level_loaded", Callable(self, "_level_loaded_signal")):
		GameManager.connect("level_loaded", Callable(self, "_level_loaded_signal"))

	# Try preferred initialize method, otherwise fallback to load_current_level
	if gm.has_method("initialize_game"):
		gm.initialize_game()
	elif gm.has_method("load_current_level"):
		gm.load_current_level()
	else:
		print("[GameUI] WARNING: GameManager has no initialize/load_current_level method")

	# Wait up to 6 seconds for level_loaded
	var wait_timer = get_tree().create_timer(6.0)
	while not _level_loaded_flag and wait_timer.time_left > 0:
		await get_tree().process_frame

	# Disconnect temporary handler
	if GameManager.is_connected("level_loaded", Callable(self, "_level_loaded_signal")):
		GameManager.disconnect("level_loaded", Callable(self, "_level_loaded_signal"))

	if not _level_loaded_flag and not gm.initialized:
		print("[GameUI] ERROR: GameManager did not emit level_loaded in time; restoring StartPage")
		if start_page:
			start_page.visible = true
		if loading_label and is_instance_valid(loading_label):
			loading_label.queue_free()
		return

	# Initialization succeeded - ensure UI updates and board setup
	update_display()
	update_booster_ui()

	# After initialization, show the board and ensure borders are drawn
	var board = get_node_or_null("../GameBoard")
	if board:
		board.visible = true
		if board.has_method("_on_level_loaded"):
			board._on_level_loaded()
		if board.has_method("draw_board_borders"):
			board.draw_board_borders()
		if board.has_method("show_tile_overlay"):
			board.show_tile_overlay()

	# Cleanup loading indicator
	if loading_label and is_instance_valid(loading_label):
		loading_label.queue_free()

func _on_startpage_map_pressed():
	"""Called when StartPage requests to open the World Map."""
	AudioManager.play_sfx("ui_click")

	# Try to find existing WorldMap node
	var wm = get_node_or_null("WorldMap")
	if not wm or not is_instance_valid(wm):
		# Prefer a scene if available, otherwise attach the script to a Control
		var scene_path = "res://scenes/WorldMap.tscn"
		if ResourceLoader.exists(scene_path):
			var packed = load(scene_path)
			if packed and packed is PackedScene:
				wm = packed.instantiate()
				wm.name = "WorldMap"
				add_child(wm)
				print("[GameUI] Instanced WorldMap from scene")
			else:
				print("[GameUI] Failed to instance WorldMap scene")
		else:
			# Fallback: load script and attach to a Control
			var script = load("res://scripts/WorldMap.gd")
			if script:
				wm = Control.new()
				wm.set_script(script)
				wm.name = "WorldMap"
				add_child(wm)
				print("[GameUI] Instanced WorldMap via script fallback")
			else:
				print("[GameUI] ERROR: WorldMap resource not found")

	if not wm:
		print("[GameUI] ERROR: Could not create WorldMap")
		return

	# Configure as fullscreen control
	var vp = get_viewport().get_visible_rect().size
	wm.anchor_left = 0
	wm.anchor_top = 0
	wm.anchor_right = 1
	wm.anchor_bottom = 1
	wm.position = Vector2(0, 0)
	wm.size = vp
	wm.mouse_filter = Control.MOUSE_FILTER_STOP
	wm.visible = true

	# Connect signals from world map
	if wm.has_signal("level_selected") and not wm.is_connected("level_selected", Callable(self, "_on_worldmap_level_selected")):
		wm.connect("level_selected", Callable(self, "_on_worldmap_level_selected"))
	if wm.has_signal("back_to_menu") and not wm.is_connected("back_to_menu", Callable(self, "_on_worldmap_back_to_menu")):
		wm.connect("back_to_menu", Callable(self, "_on_worldmap_back_to_menu"))

	# Hide start page and board while map is active
	if start_page:
		start_page.visible = false
	var board = get_node_or_null("../GameBoard")
	if board:
		board.visible = false
		if board.has_method("_clear_board_borders"):
			board._clear_board_borders()

	print("[GameUI] WorldMap shown")

func _on_worldmap_level_selected(level_num: int):
	"""Handle when a level is selected from the WorldMap."""
	print("[GameUI] WorldMap level selected: %d" % level_num)
	AudioManager.play_sfx("ui_click")

	# Set LevelManager index to the selected level (1-based to 0-based)
	var lm = get_node_or_null('/root/LevelManager')
	if lm:
		lm.current_level_index = max(0, int(level_num) - 1)
		print("[GameUI] LevelManager.current_level_index set to %d" % lm.current_level_index)

	# Close the WorldMap UI and show StartPage for selected level
	var wm = get_node_or_null("WorldMap")
	if wm:
		wm.visible = false
		# remove instance to avoid duplicates
		wm.queue_free()

	# Show StartPage (will pick up LevelManager.current_level_index)
	show_start_page()

func _on_worldmap_back_to_menu():
	"""Handle closing the WorldMap and returning to previous UI (StartPage)."""
	print("[GameUI] WorldMap requested close/back to menu")
	AudioManager.play_sfx("ui_click")
	var wm = get_node_or_null("WorldMap")
	if wm:
		wm.visible = false
		wm.queue_free()

	# Show start page again
	if start_page:
		start_page.visible = true

	# Restore board if needed
	var board = get_node_or_null("../GameBoard")
	if board and board.has_method("show_tile_overlay"):
		board.show_tile_overlay()

	print("[GameUI] WorldMap closed and StartPage restored")
