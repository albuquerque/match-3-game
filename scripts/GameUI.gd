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
@onready var menu_button = $VBoxContainer/BottomPanel/MenuButton
@onready var pause_button = $VBoxContainer/BottomPanel/PauseButton

@onready var final_score_label = $GameOverPanel/VBoxContainer/FinalScoreLabel
@onready var level_complete_score = $LevelCompletePanel/VBoxContainer/LevelScoreLabel

# Phase 2: Shop and Dialogs
@onready var shop_button = $VBoxContainer/BottomPanel/ShopButton
@onready var shop_ui = $ShopUI
@onready var out_of_lives_dialog = $OutOfLivesDialog
@onready var reward_notification = $RewardNotification

var is_paused = false
var booster_mode_active = false
var active_booster_type = ""
var swap_first_tile = null  # For swap booster - remember first selected tile
var line_blast_direction = ""  # For line blast - "horizontal" or "vertical"

func _ready():
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
	pause_button.connect("pressed", _on_pause_pressed)

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

	# Initialize UI
	game_over_panel.visible = false
	level_complete_panel.visible = false
	update_display()
	update_currency_display()
	load_booster_icons()
	update_booster_ui()

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
	final_score_label.text = "Final Score: %d" % GameManager.score
	show_panel(game_over_panel)

func _on_level_complete():
	level_complete_score.text = "Level %d Complete!\nScore: %d" % [GameManager.level - 1, GameManager.score]
	show_panel(level_complete_panel)

func show_panel(panel: Control):
	panel.visible = true
	panel.modulate = Color.TRANSPARENT

	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.WHITE, 0.3)

func hide_panel(panel: Control):
	var tween = create_tween()
	tween.tween_property(panel, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(func(): panel.visible = false)

func _on_restart_pressed():
	hide_panel(game_over_panel)
	await get_tree().create_timer(0.3).timeout
	restart_game()

func _on_continue_pressed():
	hide_panel(level_complete_panel)

func _on_menu_pressed():
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_pause_pressed():
	toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		pause_button.text = "Resume"
	else:
		pause_button.text = "Pause"

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
	if shop_ui:
		shop_ui.show_shop()
		print("[GameUI] Shop opened")

func _on_shop_closed():
	"""Handle shop close"""
	print("[GameUI] Shop closed")

func _on_item_purchased(item_type: String, cost_type: String, cost_amount: int):
	"""Handle item purchase from shop"""
	print("[GameUI] Purchased: %s for %d %s" % [item_type, cost_amount, cost_type])

	# Show reward notification
	if reward_notification:
		if item_type == "lives_refill":
			reward_notification.show_reward("lives", 5, "Lives refilled!")
		else:
			reward_notification.show_reward("booster", 1, "%s booster added!" % item_type.capitalize())

func _show_out_of_lives_dialog():
	"""Show the out of lives dialog"""
	if out_of_lives_dialog:
		out_of_lives_dialog.show_dialog()
		print("[GameUI] Showing out of lives dialog")

func _on_refill_requested(method: String):
	"""Handle life refill from dialog"""
	print("[GameUI] Lives refilled via: %s" % method)

	# Show success notification
	if reward_notification:
		reward_notification.show_reward("lives", RewardManager.get_lives(), "Lives restored!")

	# DON'T automatically start game - let the dialog close naturally
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
