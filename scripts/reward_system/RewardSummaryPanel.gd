extends Control
class_name RewardSummaryPanel

signal continue_pressed

# Node refs — resolved in setup() after the scene is in the tree
var _title_label    : Label   = null
var _stars_label    : Label   = null
var _rewards_label  : Label   = null
var _claim_btn      : Button  = null

var _base_coins : int = 0
var _base_gems  : int = 0
var _setup_done : bool = false

func setup(rewards_data: Dictionary) -> void:
	_base_coins = rewards_data.get("coins", 0)
	_base_gems  = rewards_data.get("gems",  0)
	var stars_val : int = rewards_data.get("stars", 0)

	# Resolve nodes now — the scene was instantiated and add_child called before
	# setup(), so _ready has already fired and the tree is live.
	_title_label   = get_node_or_null("Centre/Card/VBox/Title")
	_stars_label   = get_node_or_null("Centre/Card/VBox/Stars")
	_rewards_label = get_node_or_null("Centre/Card/VBox/RewardsLabel")
	_claim_btn     = get_node_or_null("Centre/Card/VBox/ClaimWrapper/ClaimButton")
	var vbox       = get_node_or_null("Centre/Card/VBox")

	# Apply Bangers font via ThemeManager if available
	var tm = get_node_or_null("/root/ThemeManager")
	if tm and _title_label:
		if tm.has_method("apply_bangers_font"):
			tm.apply_bangers_font(_title_label, 32)
	if tm and _claim_btn:
		if tm.has_method("apply_bangers_font_to_button"):
			tm.apply_bangers_font_to_button(_claim_btn, 24)

	if _title_label:
		_title_label.text = tr("UI_LEVEL_COMPLETE")
	if _stars_label:
		_stars_label.text = "⭐".repeat(stars_val) + "☆".repeat(max(0, 3 - stars_val))
	_refresh_rewards_label(_base_coins, _base_gems)

	# Wire claim button
	if _claim_btn and not _claim_btn.pressed.is_connected(_on_claim_pressed):
		_claim_btn.pressed.connect(_on_claim_pressed)

	# Multiplier mini-game — added directly into the VBox before the Claim button
	if vbox:
		var mmg_script = load("res://scripts/ui/components/MultiplierMiniGame.gd")
		if mmg_script:
			var mmg = mmg_script.new()
			mmg.name = "MultiplierMiniGame"
			mmg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			vbox.add_child(mmg)
			# Move before Spacer (which is before ClaimWrapper)
			var spacer = vbox.get_node_or_null("Spacer")
			if spacer:
				vbox.move_child(mmg, spacer.get_index())
			mmg.multiplier_chosen.connect(_on_multiplier_chosen)
			mmg.ad_requested.connect(_on_ad_requested.bind(mmg))
			mmg.start()
		else:
			push_warning("[RewardSummaryPanel] MultiplierMiniGame script not found")

	_setup_done = true

func _refresh_rewards_label(coins: int, gems: int) -> void:
	if not _rewards_label:
		return
	var text = ""
	if coins > 0: text += tr("UI_REWARDS_COINS") % coins + "\n"
	if gems  > 0: text += tr("UI_REWARDS_GEMS")  % gems  + "\n"
	if text == "": text = tr("UI_REWARDS_NONE")
	_rewards_label.text = text.strip_edges()

func _on_multiplier_chosen(multiplier: float) -> void:
	var final_coins = int(round(_base_coins * multiplier))
	var final_gems  = int(round(_base_gems  * multiplier))
	_refresh_rewards_label(final_coins, final_gems)
	var rm = get_node_or_null("/root/RewardManager")
	if rm:
		if rm.has_method("add_coins") and final_coins > 0: rm.add_coins(final_coins)
		if rm.has_method("add_gems")  and final_gems  > 0: rm.add_gems(final_gems)

func _on_ad_requested(mmg: Node) -> void:
	if mmg and is_instance_valid(mmg) and mmg.has_method("confirm_ad_watched"):
		mmg.confirm_ad_watched()

func _on_claim_pressed() -> void:
	continue_pressed.emit()

func _ready() -> void:
	# Fade in
	modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.25)
