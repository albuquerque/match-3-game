extends Control
class_name BoosterPanelComponent

## BoosterPanelComponent: owns the booster bar shown during gameplay.
## E2: Self-wiring — connects to RewardManager.booster_changed and
## GameManager.level_loaded directly. GameUI no longer mediates booster updates.

signal booster_pressed(booster_id: String)

const BOOSTER_KEYS := ["hammer", "shuffle", "swap", "chain_reaction",
		"bomb_3x3", "line_blast", "tile_squasher", "row_clear", "column_clear"]

const BUTTON_NAMES := {
	"hammer": "HammerButton", "shuffle": "ShuffleButton", "swap": "SwapButton",
	"chain_reaction": "ChainReactionButton", "bomb_3x3": "Bomb3x3Button",
	"line_blast": "LineBlastButton", "tile_squasher": "TileSquasherButton",
	"row_clear": "RowClearButton", "column_clear": "ColumnClearButton",
}

var _active_button: Button = null
var _active_tween: Tween = null

func _ready() -> void:
	var hbox = get_node_or_null("HBoxContainer")
	if hbox:
		for id in BOOSTER_KEYS:
			var btn: Button = hbox.get_node_or_null(BUTTON_NAMES.get(id, ""))
			if btn:
				btn.pressed.connect(_on_button_pressed.bind(id))
	_connect_signals()

func _connect_signals() -> void:
	var rm = _rm()
	if rm and rm.has_signal("booster_changed") and not rm.is_connected("booster_changed", _on_booster_changed):
		rm.connect("booster_changed", _on_booster_changed)
	var gm = _gm()
	if gm and gm.has_signal("level_loaded") and not gm.is_connected("level_loaded", _on_level_loaded):
		gm.connect("level_loaded", _on_level_loaded)

func _gm():
	return Engine.get_singleton("GameManager") if Engine.has_singleton("GameManager") else get_node_or_null("/root/GameManager")

func _rm():
	return get_node_or_null("/root/RewardManager")

func _tm():
	return get_node_or_null("/root/ThemeManager")

# ── Self-wired handlers ───────────────────────────────────────────────────────

func _on_level_loaded() -> void:
	var gm = _gm()
	if gm and "available_boosters" in gm and gm.available_boosters.size() > 0:
		set_available_boosters(gm.available_boosters)
	_refresh_counts()
	var tm = _tm()
	if tm and tm.has_method("get_theme_name"):
		load_icons(tm.get_theme_name())

func _on_booster_changed(_type: String, _amount: int) -> void:
	_refresh_counts()

func _refresh_counts() -> void:
	var rm = _rm()
	var counts: Dictionary = {}
	if rm and rm.has_method("get_booster_count"):
		for id in BOOSTER_KEYS:
			counts[id] = rm.get_booster_count(id)
	refresh_counts(counts)

# ── Public API ───────���────────────────────────────────────────────────────────

func refresh_counts(counts: Dictionary) -> void:
	var hbox = get_node_or_null("HBoxContainer")
	if not hbox:
		return
	for id in BOOSTER_KEYS:
		var btn: Button = hbox.get_node_or_null(BUTTON_NAMES.get(id, ""))
		if not btn:
			continue
		var count: int = counts.get(id, 0)
		var lbl: Label = btn.get_node_or_null("CountLabel")
		if lbl:
			lbl.text = str(count)
		btn.disabled = (count <= 0)
		var icon: TextureRect = btn.get_node_or_null("Icon")
		if icon:
			icon.modulate = Color.WHITE if count > 0 else Color(0.5, 0.5, 0.5, 0.5)

func set_available_boosters(booster_ids: Array) -> void:
	var hbox = get_node_or_null("HBoxContainer")
	if not hbox:
		return
	for id in BOOSTER_KEYS:
		var btn: Button = hbox.get_node_or_null(BUTTON_NAMES.get(id, ""))
		if btn:
			btn.visible = (id in booster_ids)

func highlight_active(booster_id: String) -> void:
	_stop_highlight()
	var hbox = get_node_or_null("HBoxContainer")
	if not hbox:
		return
	var btn: Button = hbox.get_node_or_null(BUTTON_NAMES.get(booster_id, ""))
	if not btn:
		return
	_active_button = btn
	_active_tween = create_tween().set_loops()
	_active_tween.tween_property(btn, "modulate", Color(1.5, 1.5, 0.3, 1.0), 0.4)
	_active_tween.tween_property(btn, "modulate", Color.WHITE, 0.4)

func clear_highlight() -> void:
	_stop_highlight()

func load_icons(theme_name: String) -> void:
	var hbox = get_node_or_null("HBoxContainer")
	if not hbox:
		return
	for id in BOOSTER_KEYS:
		var btn = hbox.get_node_or_null(BUTTON_NAMES.get(id, ""))
		if not btn:
			continue
		var icon: TextureRect = btn.get_node_or_null("Icon")
		if not icon:
			continue
		var path = "res://textures/%s/booster_%s.png" % [theme_name, id]
		if not ResourceLoader.exists(path):
			path = "res://textures/modern/booster_%s.png" % id
		if ResourceLoader.exists(path):
			icon.texture = load(path)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# ── Private ───────────────────────────────────────────────────────────────────

func _on_button_pressed(id: String) -> void:
	emit_signal("booster_pressed", id)

func _stop_highlight() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if _active_button and is_instance_valid(_active_button):
		_active_button.modulate = Color.WHITE
		_active_button.scale = Vector2.ONE
	_active_button = null
	_active_tween = null
