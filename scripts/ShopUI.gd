extends "res://scripts/ui/ScreenBase.gd"

# Shop UI for purchasing boosters and lives

signal shop_closed
signal item_purchased(item_type: String, cost_type: String, cost_amount: int)

@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var coins_label = $Panel/VBoxContainer/TopBar/CoinsLabel
@onready var gems_label = $Panel/VBoxContainer/TopBar/GemsLabel
@onready var shop_items_container = $Panel/VBoxContainer/ScrollContainer/ShopItemsContainer

# Booster prices (coins)
const BOOSTER_PRICES = {
	"hammer": 150,
	"shuffle": 100,
	"swap": 175,
	"chain_reaction": 325,
	"bomb_3x3": 275,
	"line_blast": 400,
	"row_clear": 250,
	"column_clear": 250,
	"extra_moves": 200,
	"tile_squasher": 400
}

# Lives refill price (gems)
const LIVES_REFILL_GEM_COST = 50

var _panel_width = 300

func _compute_responsive():
	var vp = get_viewport().get_visible_rect().size
	_panel_width = int(min(480, vp.x * 0.40))
	return _panel_width

func _ready():
	# Base class handles fullscreen anchors and background
	ensure_fullscreen()

	visible = false

	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	# Connect to RewardManager signals for currency updates
	RewardManager.coins_changed.connect(_update_currency_display)
	RewardManager.gems_changed.connect(_update_currency_display)

	_setup_shop_items()

func _setup_shop_items():
	"""Create shop item buttons"""
	# Clear existing items
	for child in shop_items_container.get_children():
		child.queue_free()

	# Determine responsive sizes
	var panel_width = _panel_width
	var icon_font = int(clamp(panel_width * 0.12, 24, 72))
	var name_font = int(clamp(panel_width * 0.07, 16, 28))
	var desc_font = int(clamp(panel_width * 0.05, 12, 18))
	var buy_button_width = int(clamp(panel_width * 0.28, 80, 180))

	# Add lives refill option
	_add_shop_item("Lives Refill", "❤️", "Refill all 5 lives", LIVES_REFILL_GEM_COST, "gems", "lives_refill", icon_font, name_font, desc_font, buy_button_width)

	# Add booster items
	_add_shop_item("Hammer", "🔨", "Destroy any tile", BOOSTER_PRICES["hammer"], "coins", "hammer", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Shuffle", "🔀", "Reorganize board", BOOSTER_PRICES["shuffle"], "coins", "shuffle", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Swap Tiles", "🔄", "Swap any 2 tiles", BOOSTER_PRICES["swap"], "coins", "swap", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Chain Reaction", "⚡", "Spreading explosion", BOOSTER_PRICES["chain_reaction"], "coins", "chain_reaction", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("3x3 Bomb", "💣", "Destroy 3x3 area", BOOSTER_PRICES["bomb_3x3"], "coins", "bomb_3x3", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Line Blast", "📏", "Clear 3 rows or columns", BOOSTER_PRICES["line_blast"], "coins", "line_blast", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Row Clear", "↔️", "Clear entire row", BOOSTER_PRICES["row_clear"], "coins", "row_clear", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Column Clear", "↕️", "Clear entire column", BOOSTER_PRICES["column_clear"], "coins", "column_clear", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Extra Moves", "➕", "Add 10 moves instantly", BOOSTER_PRICES["extra_moves"], "coins", "extra_moves", icon_font, name_font, desc_font, buy_button_width)
	_add_shop_item("Tile Squasher", "💥", "Remove all tiles of same type", BOOSTER_PRICES["tile_squasher"], "coins", "tile_squasher", icon_font, name_font, desc_font, buy_button_width)

func _add_shop_item(item_name: String, icon: String, description: String, cost: int, cost_type: String, item_id: String, icon_font: int=48, name_font: int=20, desc_font: int=14, buy_width: int=100):
	"""Add a shop item to the container"""
	var item_panel = PanelContainer.new()
	item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_panel.custom_minimum_size = Vector2(_panel_width - 16, 80)

	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = icon
	ThemeManager.apply_bangers_font(icon_label, icon_font)
	icon_label.custom_minimum_size = Vector2(int(_panel_width * 0.16), 60)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# Info (name + description)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = item_name
	ThemeManager.apply_bangers_font(name_label, name_font)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = description
	ThemeManager.apply_bangers_font(desc_label, desc_font)
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	info_vbox.add_child(desc_label)

	# Check if player owns any of this booster (skip for instant-use items)
	if item_id != "lives_refill" and item_id != "extra_moves":
		var owned = RewardManager.get_booster_count(item_id)
		if owned > 0:
			var owned_label = Label.new()
			owned_label.text = "Owned: %d" % owned
			ThemeManager.apply_bangers_font(owned_label, int(max(10, name_font * 0.6)))
			owned_label.modulate = Color(0.5, 1.0, 0.5)
			info_vbox.add_child(owned_label)

	# Buy button - create with icon
	var buy_button = Button.new()
	buy_button.text = "Buy\n%d" % cost
	buy_button.custom_minimum_size = Vector2(buy_width, 60)

	# Add icon to button (will be positioned by button's internal layout)
	var cost_icon = TextureRect.new()
	cost_icon.custom_minimum_size = Vector2(16, 16)
	cost_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	cost_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if cost_type == "coins":
		cost_icon.texture = ThemeManager.load_coin_icon()
	else:
		cost_icon.texture = ThemeManager.load_gem_icon()

	# Note: Button doesn't support adding children cleanly in this way
	# So we'll use a simple text-only approach for now
	# TODO: Could create a custom button with icon later

	# Bind the purchase arguments to the callable so the signal receives them when pressed
	var buy_callable = Callable(self, "_on_buy_pressed").bind(item_id, cost, cost_type)
	buy_button.pressed.connect(buy_callable)
	hbox.add_child(buy_button)

	shop_items_container.add_child(item_panel)

func show_shop():
	"""Show the shop dialog"""
	# compute responsive sizing
	_compute_responsive()
	# Ensure this Control is fullscreen so GameUI can animate it easily
	if self is Control:
		var vp = get_viewport().get_visible_rect().size
		self.anchor_left = 0
		self.anchor_top = 0
		self.anchor_right = 1
		self.anchor_bottom = 1
		# offsets not required; GameUI will control slide position
		# self.offset_left = 0
		# self.offset_top = 0
		# self.offset_right = 0
		# self.offset_bottom = 0
		# position = Vector2(0, 0)  # do not force position here; GameUI controls slide animation
		self.size = vp
		self.mouse_filter = Control.MOUSE_FILTER_STOP

	visible = true
	# Use ScreenBase animation
	_update_currency_display(0)  # Update display
	_setup_shop_items()  # Refresh items to show owned counts
	show_screen(0.3)
	print("[Shop] Shop opened (responsive), panel_width=" + str(_panel_width))

func _update_currency_display(_amount: int = 0):
	"""Update the currency display in the shop"""
	if coins_label:
		# Hide old label and create icon display
		var parent = coins_label.get_parent()
		if parent:
			var icon_display = parent.get_node_or_null("CoinsIconDisplay")
			if not icon_display:
				coins_label.visible = false
				icon_display = ThemeManager.create_currency_display("coins", RewardManager.get_coins(), 20, 18, Color.WHITE)
				icon_display.name = "CoinsIconDisplay"
				parent.add_child(icon_display)
			else:
				var label = icon_display.get_child(1) as Label
				if label:
					label.text = str(RewardManager.get_coins())

	if gems_label:
		# Hide old label and create icon display
		var parent = gems_label.get_parent()
		if parent:
			var icon_display = parent.get_node_or_null("GemsIconDisplay")
			if not icon_display:
				gems_label.visible = false
				icon_display = ThemeManager.create_currency_display("gems", RewardManager.get_gems(), 20, 18, Color.WHITE)
				icon_display.name = "GemsIconDisplay"
				parent.add_child(icon_display)
			else:
				var label = icon_display.get_child(1) as Label
				if label:
					label.text = str(RewardManager.get_gems())

func _on_buy_pressed(item_id: String, cost: int, cost_type: String):
	"""Handle purchase button press"""
	var can_afford = false

	if cost_type == "coins":
		can_afford = RewardManager.spend_coins(cost)
	elif cost_type == "gems":
		can_afford = RewardManager.spend_gems(cost)

	if can_afford:
		# Grant the item
		if item_id == "lives_refill":
			RewardManager.refill_lives()
			print("[Shop] Purchased lives refill")
		elif item_id == "extra_moves":
			# Extra moves: immediately add 10 moves to current game
			if GameManager:
				GameManager.add_moves(10)
				print("[Shop] Purchased extra moves: +10 moves added")
			else:
				print("[Shop] Warning: GameManager not available, cannot add moves")
		else:
			RewardManager.add_booster(item_id, 1)
			print("[Shop] Purchased booster: %s" % item_id)

		# Emit signal
		item_purchased.emit(item_id, cost_type, cost)

		# Refresh shop display
		_setup_shop_items()

		# Show success feedback
		_show_purchase_success(item_id)
	else:
		print("[Shop] Cannot afford %s (costs %d %s)" % [item_id, cost, cost_type])
		_show_insufficient_funds(cost_type)

func _show_purchase_success(item_id: String):
	"""Show visual feedback for successful purchase"""
	# TODO: Add particle effects or animation
	print("[Shop] Purchase successful: %s" % item_id)

func _show_insufficient_funds(cost_type: String):
	"""Show message when player can't afford item"""
	# TODO: Add warning message or shake animation
	print("[Shop] Insufficient %s!" % cost_type)

func _on_close_pressed():
	"""Close the shop"""
	hide_screen(0.3)
	# Schedule close complete after hide duration
	var t = get_tree().create_timer(0.3)
	t.timeout.connect(Callable(self, "_on_shop_close_complete"))

func _on_shop_close_complete():
	visible = false
	shop_closed.emit()
