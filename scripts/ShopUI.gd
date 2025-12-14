extends Control

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
	"row_clear": 250,
	"column_clear": 250,
	"extra_moves": 200,
	"color_reducer": 400
}

# Lives refill price (gems)
const LIVES_REFILL_GEM_COST = 50

func _ready():
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

	# Add lives refill option
	_add_shop_item("Lives Refill", "❤️", "Refill all 5 lives", LIVES_REFILL_GEM_COST, "gems", "lives_refill")

	# Add booster items
	_add_shop_item("Hammer", "🔨", "Destroy any tile", BOOSTER_PRICES["hammer"], "coins", "hammer")
	_add_shop_item("Shuffle", "🔀", "Reorganize board", BOOSTER_PRICES["shuffle"], "coins", "shuffle")
	_add_shop_item("Row Clear", "↔️", "Clear entire row", BOOSTER_PRICES["row_clear"], "coins", "row_clear")
	_add_shop_item("Column Clear", "↕️", "Clear entire column", BOOSTER_PRICES["column_clear"], "coins", "column_clear")
	_add_shop_item("Extra Moves", "➕", "Start with +5 moves", BOOSTER_PRICES["extra_moves"], "coins", "extra_moves")
	_add_shop_item("Color Reducer", "🎨", "Remove 1 tile type", BOOSTER_PRICES["color_reducer"], "coins", "color_reducer")

func _add_shop_item(item_name: String, icon: String, description: String, cost: int, cost_type: String, item_id: String):
	"""Add a shop item to the container"""
	var item_panel = PanelContainer.new()

	var hbox = HBoxContainer.new()
	item_panel.add_child(hbox)

	# Icon
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.add_theme_font_size_override("font_size", 48)
	icon_label.custom_minimum_size = Vector2(60, 60)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(icon_label)

	# Info (name + description)
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_label = Label.new()
	name_label.text = item_name
	name_label.add_theme_font_size_override("font_size", 20)
	info_vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = description
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.modulate = Color(0.8, 0.8, 0.8)
	info_vbox.add_child(desc_label)

	# Check if player owns any of this booster
	if item_id != "lives_refill":
		var owned = RewardManager.get_booster_count(item_id)
		if owned > 0:
			var owned_label = Label.new()
			owned_label.text = "Owned: %d" % owned
			owned_label.add_theme_font_size_override("font_size", 12)
			owned_label.modulate = Color(0.5, 1.0, 0.5)
			info_vbox.add_child(owned_label)

	# Buy button
	var buy_button = Button.new()
	var cost_icon = "💰" if cost_type == "coins" else "💎"
	buy_button.text = "Buy\n%d %s" % [cost, cost_icon]
	buy_button.custom_minimum_size = Vector2(100, 60)
	buy_button.pressed.connect(func(): _on_buy_pressed(item_id, cost, cost_type))
	hbox.add_child(buy_button)

	shop_items_container.add_child(item_panel)

func show_shop():
	"""Show the shop dialog"""
	visible = true
	modulate = Color.TRANSPARENT

	_update_currency_display(0)  # Update display
	_setup_shop_items()  # Refresh items to show owned counts

	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

	print("[Shop] Shop opened")

func _update_currency_display(_amount: int = 0):
	"""Update the currency display in the shop"""
	if coins_label:
		coins_label.text = "💰 %d" % RewardManager.get_coins()
	if gems_label:
		gems_label.text = "💎 %d" % RewardManager.get_gems()

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
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.tween_callback(_on_shop_close_complete)

func _on_shop_close_complete():
	visible = false
	shop_closed.emit()

