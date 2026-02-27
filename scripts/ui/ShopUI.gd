extends "res://scripts/ui/ScreenBase.gd"

signal shop_closed
signal item_purchased(item_type: String, cost_type: String, cost_amount: int)

@onready var close_button = null
@onready var coins_label = null
@onready var gems_label = null
@onready var shop_items_container = null

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

func _ready():
	ensure_fullscreen()
	visible = false
	# Create a minimal UI if scene doesn't provide one
	_setup_placeholder_ui()

func _setup_placeholder_ui():
	if not has_node("Panel"):
		var panel = Panel.new()
		panel.name = "Panel"
		add_child(panel)
		var v = VBoxContainer.new()
		v.name = "VBoxContainer"
		panel.add_child(v)
		close_button = Button.new()
		close_button.name = "CloseButton"
		close_button.text = "Close"
		v.add_child(close_button)
		close_button.pressed.connect(_on_close_pressed)
		shop_items_container = VBoxContainer.new()
		shop_items_container.name = "ShopItemsContainer"
		v.add_child(shop_items_container)

func setup(params: Dictionary = {}):
	pass

func _setup_shop_items():
	if not shop_items_container:
		return
	for child in shop_items_container.get_children():
		if is_instance_valid(child):
			child.queue_free()
	for key in BOOSTER_PRICES.keys():
		var lbl = Label.new()
		lbl.text = "%s: %d" % [str(key), BOOSTER_PRICES[key]]
		shop_items_container.add_child(lbl)

func show_shop():
	_compute_responsive()
	if self is Control:
		var vp = get_viewport().get_visible_rect().size
		self.anchor_left = 0
		self.anchor_top = 0
		self.anchor_right = 1
		self.anchor_bottom = 1
		self.size = vp
		self.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = true
	_update_currency_display()
	_setup_shop_items()
	show_screen(0.25)

func _compute_responsive():
	var vp = get_viewport().get_visible_rect().size
	return int(min(480, vp.x * 0.40))

func _update_currency_display(_amount: int = 0):
	var coins = 0
	var gems = 0
	if has_method("get_tree") and get_tree() != null:
		var root = get_tree().root
		var rm = null
		if root:
			rm = root.get_node_or_null("RewardManager")
		if rm == null and typeof(RewardManager) != TYPE_NIL:
			rm = RewardManager
		if rm and rm.has_method("get_coins"):
			coins = rm.get_coins()
		if rm and rm.has_method("get_gems"):
			gems = rm.get_gems()
	if coins_label and is_instance_valid(coins_label):
		coins_label.text = str(coins)
	if gems_label and is_instance_valid(gems_label):
		gems_label.text = str(gems)

func _on_buy_pressed(item_id: String, cost: int, cost_type: String):
	var rm = null
	if has_method("get_tree") and get_tree() != null:
		var root = get_tree().root
		if root:
			rm = root.get_node_or_null("RewardManager")
	if rm == null and typeof(RewardManager) != TYPE_NIL:
		rm = RewardManager
	var can_afford = false
	if cost_type == "coins" and rm and rm.has_method("spend_coins"):
		can_afford = rm.spend_coins(cost)
	elif cost_type == "gems" and rm and rm.has_method("spend_gems"):
		can_afford = rm.spend_gems(cost)
	if can_afford:
		emit_signal("item_purchased", item_id, cost_type, cost)
		_setup_shop_items()

func _on_close_pressed():
	hide_screen(0.25)
	call_deferred("_on_shop_close_complete")

func _on_shop_close_complete():
	visible = false
	emit_signal("shop_closed")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_on_close_pressed()
