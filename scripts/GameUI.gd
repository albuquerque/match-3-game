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

@onready var game_over_panel = $GameOverPanel
@onready var level_complete_panel = $LevelCompletePanel
@onready var restart_button = $GameOverPanel/VBoxContainer/RestartButton
@onready var continue_button = $LevelCompletePanel/VBoxContainer/ContinueButton
@onready var final_score_label = $GameOverPanel/VBoxContainer/FinalScoreLabel
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

func _ready():
	# Debug: print initial global state to help diagnose inadvertent Game Over
	print("[GameUI] _ready() — initial states: GameManager.score=", GameManager.score, ", moves_left=", GameManager.moves_left, ", target=", GameManager.target_score, ", RewardManager.lives=", RewardManager.get_lives())

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

	# Connect UI buttons
	restart_button.connect("pressed", _on_restart_pressed)
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
		main_menu_popup.add_item("About", 2)
		main_menu_popup.add_item("Share", 3)
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
	game_over_panel.visible = false
	level_complete_panel.visible = false
	update_display()
	update_currency_display()
	load_booster_icons()
	update_booster_ui()

	# Show StartPage instead of immediately starting the level
	var start_page = get_node_or_null("StartPage")
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

	# Check if player has lives
	if RewardManager.get_lives() <= 0:
		_show_out_of_lives_dialog()

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
	score_label.text = "Score: %d" % GameManager.score
	level_label.text = "Level %d" % GameManager.level
	moves_label.text = "Moves: %d" % GameManager.moves_left

	# Update progress bar
	var progress = float(GameManager.score) / float(GameManager.target_score)
	target_progress.value = min(progress * 100, 100)
	target_label.text = "Target: %d" % GameManager.target_score

func _on_score_changed(new_score: int):
	score_label.text = "Score: %d" % new_score

	# Update progress
	var progress = float(new_score) / float(GameManager.target_score)
	target_progress.value = min(progress * 100, 100)

	# Animate score increase
	animate_score_change()

func _on_level_changed(new_level: int):
	level_label.text = "Level %d" % new_level
	target_label.text = "Target: %d" % GameManager.target_score
	target_progress.value = 0

	# Animate level change
	animate_level_change()

func _on_moves_changed(moves_left: int):
	moves_label.text = "Moves: %d" % moves_left

	# Warning color when low on moves
	if moves_left <= 5:
		moves_label.modulate = Color.RED
		animate_low_moves_warning()
	else:
		moves_label.modulate = Color.WHITE

func _on_game_over():
	# Defensive: Only show the Game Over panel when the game manager indicates a real failure
	print("[GameUI] _on_game_over() called - verifying state: moves_left=", GameManager.moves_left, ", score=", GameManager.score, ", target=", GameManager.target_score)
	# Consider it a valid game over if no moves left and score < target
	if GameManager.moves_left > 0 and GameManager.score < GameManager.target_score:
		print("[GameUI] Ignoring game_over: moves remain or target not reached - false positive")
		return
	# Fallback: if score already >= target, treat as level complete instead
	if GameManager.score >= GameManager.target_score:
		print("[GameUI] Score >= target on game_over signal - routing to level complete")
		_on_level_complete()
		return
	final_score_label.text = "Final Score: %d" % GameManager.score
	show_panel(game_over_panel)

func _on_level_complete():
	level_complete_score.text = "Level %d Complete!\nScore: %d" % [GameManager.level - 1, GameManager.score]
	show_panel(level_complete_panel)

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

func _on_restart_pressed():
	hide_panel(game_over_panel)
	await get_tree().create_timer(0.3).timeout
	restart_game()

func _on_continue_pressed():
	hide_panel(level_complete_panel)

func _on_menu_pressed():
	# Show the popup menu anchored to the menu button
	if main_menu_popup and menu_button:
		main_menu_popup.set_position(menu_button.get_global_position())
		main_menu_popup.popup()
		print("[GameUI] Main menu popup opened")

func restart_game():
	var game_board = get_node("../GameBoard")
	if game_board:
		game_board.restart_game()
	update_display()

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
	coins_label.text = "💰 %d" % RewardManager.get_coins()
	gems_label.text = "💎 %d" % RewardManager.get_gems()

	var lives = RewardManager.get_lives()
	var max_lives = RewardManager.MAX_LIVES
	lives_label.text = "❤️ %d/%d" % [lives, max_lives]

func _on_coins_changed(new_amount: int):
	coins_label.text = "💰 %d" % new_amount
	animate_currency_change(coins_label)

func _on_gems_changed(new_amount: int):
	gems_label.text = "💎 %d" % new_amount
	animate_currency_change(gems_label)

func _on_lives_changed(new_amount: int):
	var max_lives = RewardManager.MAX_LIVES
	lives_label.text = "❤️ %d/%d" % [new_amount, max_lives]
	animate_currency_change(lives_label)

func _on_booster_changed(booster_type: String, new_amount: int):
	"""Handle booster count changes"""
	print("[GameUI] Booster changed: ", booster_type, " = ", new_amount)
	update_booster_ui()

func animate_currency_change(label: Label):
	var tween = create_tween()
	tween.tween_property(label, "scale", Vector2(1.3, 1.3), 0.15)
	tween.tween_property(label, "scale", Vector2.ONE, 0.15)
	tween.tween_property(label, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(label, "modulate", Color.WHITE, 0.2)

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
	if out_of_lives_dialog:
		if out_of_lives_dialog.has_method("show_dialog"):
			out_of_lives_dialog.show_dialog()
		elif out_of_lives_dialog is Control:
			out_of_lives_dialog.visible = true
		else:
			print("[GameUI] OutOfLivesDialog exists but has no show_dialog")
		print("[GameUI] Showing out of lives dialog")

func _on_refill_requested(method: String):
	"""Handle life refill from dialog"""
	print("[GameUI] Lives refilled via: %s" % method)

	# Show success notification
	if reward_notification:
		if reward_notification.has_method("show_reward"):
			reward_notification.show_reward("lives", RewardManager.get_lives(), "Lives restored!")
		else:
			print("[GameUI] reward_notification missing show_reward method")

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
	if RewardManager.get_booster_count("hammer") > 0:
		activate_booster("hammer")
		print("[GameUI] Hammer activated")

func _on_shuffle_pressed():
	"""Handle shuffle button press - immediately shuffles board"""
	if RewardManager.get_booster_count("shuffle") > 0:
		print("[GameUI] Shuffle activated")
		var board = get_node("../GameBoard")
		if board:
			await board.activate_shuffle_booster()
			update_booster_ui()

func _on_swap_pressed():
	"""Handle swap button press"""
	if RewardManager.get_booster_count("swap") > 0:
		activate_booster("swap")
		swap_first_tile = null  # Reset swap state
		print("[GameUI] Swap activated - select first tile")

func _on_chain_reaction_pressed():
	"""Handle chain reaction button press"""
	if RewardManager.get_booster_count("chain_reaction") > 0:
		activate_booster("chain_reaction")
		print("[GameUI] Chain Reaction activated")

func _on_bomb_3x3_pressed():
	"""Handle 3x3 bomb button press"""
	if RewardManager.get_booster_count("bomb_3x3") > 0:
		activate_booster("bomb_3x3")
		print("[GameUI] 3x3 Bomb activated")

func _on_line_blast_pressed():
	"""Handle line blast button press - need to choose direction first"""
	if RewardManager.get_booster_count("line_blast") > 0:
		# Show direction selector or default to horizontal for now
		# For simplicity, we'll prompt in console and default to horizontal
		activate_booster("line_blast")
		line_blast_direction = "horizontal"  # Can be changed to show UI selector
		print("[GameUI] Line Blast activated - tap tile for center (horizontal mode)")

func _on_tile_squasher_pressed():
	"""Handle tile squasher button press"""
	if RewardManager.get_booster_count("tile_squasher") > 0:
		activate_booster("tile_squasher")
		print("[GameUI] Tile Squasher activated")

func _on_row_clear_pressed():
	"""Handle row clear button press"""
	if RewardManager.get_booster_count("row_clear") > 0:
		activate_booster("row_clear")
		print("[GameUI] Row clear activated")

func _on_column_clear_pressed():
	"""Handle column clear button press"""
	if RewardManager.get_booster_count("column_clear") > 0:
		activate_booster("column_clear")
		print("[GameUI] Column clear activated")

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
	"""Update the booster panel UI"""
	print("[GameUI] update_booster_ui called")

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

	# Always show the booster panel
	if booster_panel:
		booster_panel.visible = true
		print("[GameUI] Booster panel always visible")

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

	if id == 0:
		# Settings - slide-in side panel
		print("[GameUI] Open settings (side panel)")
		_show_settings_side()
	elif id == 1:
		# Shop - slide-in side panel
		print("[GameUI] Open shop (side panel)")
		_show_shop_side()
	elif id == 2:
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
	elif id == 3:
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
						cb.pressed.connect(func(node=node): _on_dialog_close_pressed(node))
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
		board_original_position = board.position
		tween.tween_property(board, "position", board_original_position + Vector2(panel_width,0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(board, "scale", Vector2(0.95,0.95), 0.35)
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
		shop_ui.anchor_bottom = 1
		# start offscreen to right (GameUI will animate position)
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
		board_original_position = board.position
		tween.tween_property(board, "position", board_original_position + Vector2(-panel_width,0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(board, "scale", Vector2(0.95,0.95), 0.35)
	if shop_ui:
		tween.tween_property(shop_ui, "position", Vector2(0,0), 0.35)
		tween.tween_property(shop_ui, "modulate", Color.WHITE, 0.35)
	print("[GameUI] Shop presented fullscreen")

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
		tween.tween_property(board, "position", board_original_position, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(board, "scale", Vector2(1,1), 0.35)

	await tween.finished
	# hide the panel after animation
	panel.visible = false
	print("[GameUI] Fullscreen panel closed: %s" % panel.name)

func _on_startpage_start_pressed():
	print("[GameUI] Start pressed on StartPage - initializing game")
	# Initialize game manager and then remove the StartPage
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_method("initialize_game"):
		gm.initialize_game()
	elif typeof(GameManager) != TYPE_NIL and GameManager and GameManager.has_method("initialize_game"):
		# Fallback to the global autoload name
		GameManager.initialize_game()
	else:
		print("[GameUI] ERROR: GameManager not found; cannot initialize game")

	# Refresh UI to reflect loaded level and moves
	update_display()
	update_booster_ui()

	# Ensure the GameBoard is created once the level is loaded.
	var board = get_node_or_null("../GameBoard")
	print("[GameUI] After initialize_game: GameManager.initialized=", GameManager.initialized, ", GameManager.grid size=", GameManager.grid.size())
	if GameManager.initialized:
		# If GameManager reports initialized (level already loaded), create visual grid deferred
		if board:
			print("[GameUI] Deferring board layout and create_visual_grid() calls")
			board.call_deferred("calculate_responsive_layout")
			board.call_deferred("setup_background")
			board.call_deferred("create_visual_grid")
			print("[GameUI] Deferred create_visual_grid scheduled")
			# Also print a small grid snapshot for diagnostics
			for y in range(GameManager.GRID_HEIGHT):
				var row = []
				for x in range(GameManager.GRID_WIDTH):
					row.append(GameManager.grid[x][y])
				print("[GameUI] Grid row[", y, "] = ", row)
	else:
		# If level load is asynchronous (e.g., lives consumed prevented immediate load), connect to the level_loaded signal once
		if not GameManager.is_connected("level_loaded", Callable(self, "_on_game_manager_level_loaded")):
			GameManager.connect("level_loaded", Callable(self, "_on_game_manager_level_loaded"))
			print("[GameUI] Connected to GameManager.level_loaded to create grid when ready")

	var sp = get_node_or_null("StartPage")
	if sp:
		sp.visible = false
		sp.queue_free()

func _on_game_manager_level_loaded():
	print("[GameUI] Received GameManager.level_loaded — creating visual grid")
	# Called when GameManager finishes loading a level
	var board = get_node_or_null("../GameBoard")
	if board:
		print("[GameUI] Deferred calls to create visual grid (level_loaded). Grid size=", GameManager.grid.size())
		board.call_deferred("calculate_responsive_layout")
		board.call_deferred("setup_background")
		board.call_deferred("create_visual_grid")
		print("[GameUI] Deferred visual grid creation scheduled on level_loaded")
	# Disconnect to avoid duplicate handling
	if GameManager.is_connected("level_loaded", Callable(self, "_on_game_manager_level_loaded")):
		GameManager.disconnect("level_loaded", Callable(self, "_on_game_manager_level_loaded"))
