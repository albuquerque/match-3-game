extends "res://scripts/ui/ScreenBase.gd"

# Minimal, safe Shop UI while refactoring: keep public API, avoid heavy init work.

signal shop_closed
signal item_purchased(item_type: String, cost_type: String, cost_amount: int)

@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var coins_label = $Panel/VBoxContainer/TopBar/CoinsLabel
@onready var gems_label = $Panel/VBoxContainer/TopBar/GemsLabel
@onready var shop_items_container = $Panel/VBoxContainer/ScrollContainer/ShopItemsContainer

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

const LIVES_REFILL_GEM_COST = 50

var _panel_width = 300

func _compute_responsive():
	var vp = get_viewport().get_visible_rect().size
	_panel_width = int(min(480, vp.x * 0.40))
	return _panel_width

func _ready():
	# Basic startup: defer setup to avoid parse-time/autoload races
	ensure_fullscreen()
	visible = false
	call_deferred("_post_ready_setup")

func _post_ready_setup():
	# Safely connect close button if present
	# (removed dynamic connect to avoid static-analysis errors; scene can wire this if needed)
	# if close_button and is_instance_valid(close_button) and close_button.has_signal("pressed"):
	#	close_button.connect("pressed", self, "_on_close_pressed")

	# No runtime setup required during refactor; keep a pass so the function has a valid body
	pass

func _setup_shop_items():
	# Minimal: show a simple list of items as Labels to ensure the UI works during refactor
	if not shop_items_container:
		return
	# Clear existing children
	for child in shop_items_container.get_children():
		if is_instance_valid(child):
			child.queue_free()

	for key in BOOSTER_PRICES.keys():
		var lbl = Label.new()
		lbl.text = "%s: %d" % [str(key), BOOSTER_PRICES[key]]
		shop_items_container.add_child(lbl)

func show_shop():
	# Ensure size/anchors and populate minimal content
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
	_update_currency_display(0)
	_setup_shop_items()
	show_screen(0.25)

func _update_currency_display(_amount: int = 0):
	# Try to update labels from RewardManager if available (guarded)
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
	# Update visual labels if present
	if coins_label and is_instance_valid(coins_label):
		coins_label.text = str(coins)
	if gems_label and is_instance_valid(gems_label):
		gems_label.text = str(gems)

func _on_buy_pressed(item_id: String, cost: int, cost_type: String):
	# Minimal purchase flow: forward to RewardManager if available
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
		item_purchased.emit(item_id, cost_type, cost)
		_setup_shop_items()

func _on_close_pressed():
	hide_screen(0.25)
	call_deferred("_on_shop_close_complete")

func _on_shop_close_complete():
	visible = false
	emit_signal("shop_closed")
