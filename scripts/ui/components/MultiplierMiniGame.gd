extends VBoxContainer
class_name MultiplierMiniGame

## MultiplierMiniGame — self-contained reward multiplier mini-game component.
## Shows a coloured zone bar with a bouncing pointer; player taps to stop it
## and claims the multiplier for the zone the pointer lands on.
##
## Usage:
##   var mmg = MultiplierMiniGame.new()
##   add_child(mmg)
##   mmg.multiplier_chosen.connect(_on_multiplier)
##   mmg.start()
##
## Signals:
##   multiplier_chosen(value: float)  — emitted when player taps and locks a zone
##   ad_requested()                   — emitted when "Watch Ad" is pressed; caller
##                                      must call confirm_ad_watched() afterwards

signal multiplier_chosen(value: float)
signal ad_requested

# ── Zone config [start%, end%, multiplier, color] ────────────────────────────
const ZONES := [
	[0.00, 0.15, 1.0, Color(0.5, 0.5, 0.5, 1.0)],   # Gray   1×
	[0.15, 0.30, 1.5, Color(0.4, 0.7, 0.4, 1.0)],   # Green  1.5×
	[0.30, 0.45, 2.0, Color(0.3, 0.5, 0.8, 1.0)],   # Blue   2×
	[0.45, 0.55, 3.0, Color(0.7, 0.4, 0.9, 1.0)],   # Purple 3× (JACKPOT)
	[0.55, 0.70, 2.0, Color(0.3, 0.5, 0.8, 1.0)],   # Blue   2×
	[0.70, 0.85, 1.5, Color(0.4, 0.7, 0.4, 1.0)],   # Green  1.5×
	[0.85, 1.00, 1.0, Color(0.5, 0.5, 0.5, 1.0)],   # Gray   1×
]

const BAR_HEIGHT   := 56.0
const POINTER_W    := 8.0
const POINTER_SPEED := 220.0  # px / second

# Actual bar width — resolved from container size in _ready()
var BAR_WIDTH : float = 320.0

# ── State ─────────────────────────────────────────────────────────────────────
var _active       := false
var _locked       := false
var _ptr_x        := 0.0
var _ptr_dir      := 1.0
var _chosen_mult  := 1.0
var _ad_required  := true   # set false for testing / desktop

# ── Nodes (built procedurally) ────────────────────────────────────────────────
var _bar_root    : Control
var _pointer     : ColorRect
var _tap_btn     : Button
var _result_lbl  : Label

# ── Public API ────────────────────────────────────────────────────────────────

func start() -> void:
	"""Start the pointer moving. Call after adding to scene tree."""
	if _active or _locked:
		return
	_active = true
	if _tap_btn:
		_tap_btn.visible = true

func confirm_ad_watched() -> void:
	"""Call this after the rewarded ad resolves to emit multiplier_chosen."""
	_emit_chosen()

func set_require_ad(required: bool) -> void:
	"""Set false in desktop / test builds to skip the ad step."""
	_ad_required = required

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if OS.has_feature("editor") or OS.has_feature("pc"):
		_ad_required = false

	# Defer one frame so the parent PanelContainer has resolved its inner width
	await get_tree().process_frame
	var parent_w := get_parent_control().size.x if get_parent_control() else 0.0
	BAR_WIDTH = max(200.0, parent_w - 8.0)   # slight inset so pointer doesn't touch edges
	_build_ui()

func _process(delta: float) -> void:
	if not _active or _locked or _pointer == null:
		return
	_ptr_x += POINTER_SPEED * _ptr_dir * delta
	if _ptr_x >= BAR_WIDTH - POINTER_W:
		_ptr_x = BAR_WIDTH - POINTER_W
		_ptr_dir = -1.0
	elif _ptr_x <= 0.0:
		_ptr_x = 0.0
		_ptr_dir = 1.0
	_pointer.position.x = _ptr_x

# ── UI construction ────────────────────────────────────────────────────────────

func _build_ui() -> void:
	# VBoxContainer already stacks children — no manual positions needed
	add_theme_constant_override("separation", 8)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# ── Title ─────────────────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "🎯 " + tr("UI_MULTIPLIER_CHALLENGE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
		ThemeManager.apply_bangers_font(title, 20)
	add_child(title)

	# ── Bar row: CenterContainer holds the fixed-size bar ─────────────────────
	var bar_centre := CenterContainer.new()
	bar_centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_centre.custom_minimum_size = Vector2(0, BAR_HEIGHT + 20)
	add_child(bar_centre)

	_bar_root = Control.new()
	_bar_root.name = "BarRoot"
	_bar_root.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_centre.add_child(_bar_root)

	# Background strip
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.15, 0.15, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bar_root.add_child(bg)

	# Zone rects + labels — fill the bar from left to right
	for z in ZONES:
		var zr := ColorRect.new()
		zr.color    = z[3]
		zr.position = Vector2(BAR_WIDTH * z[0], 0)
		zr.size     = Vector2(BAR_WIDTH * (z[1] - z[0]), BAR_HEIGHT)
		_bar_root.add_child(zr)

		var lbl := Label.new()
		lbl.text = "%.1f×" % z[2]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.position = zr.position
		lbl.size     = zr.size
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
		if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
			ThemeManager.apply_bangers_font(lbl, 15)
		_bar_root.add_child(lbl)

	# Pointer (drawn on top)
	_pointer = ColorRect.new()
	_pointer.name    = "Pointer"
	_pointer.color   = Color(1.0, 1.0, 0.0, 0.95)
	_pointer.position = Vector2(0, -4)
	_pointer.size    = Vector2(POINTER_W, BAR_HEIGHT + 8)
	_bar_root.add_child(_pointer)

	# Invisible tap area
	var tap_area := Control.new()
	tap_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tap_area.mouse_filter = Control.MOUSE_FILTER_STOP
	tap_area.gui_input.connect(_on_bar_input)
	_bar_root.add_child(tap_area)

	# ── "TAP TO STOP" button row ───────────────────────────────────────────────
	var btn_wrap := CenterContainer.new()
	btn_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(btn_wrap)

	_tap_btn = Button.new()
	_tap_btn.text = "🎯 " + tr("UI_TAP_TO_STOP")
	_tap_btn.custom_minimum_size = Vector2(min(260, BAR_WIDTH - 20), 52)
	_tap_btn.visible = false
	_tap_btn.pressed.connect(_on_tapped)
	if ThemeManager and ThemeManager.has_method("apply_bangers_font_to_button"):
		ThemeManager.apply_bangers_font_to_button(_tap_btn, 20)
	_tap_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	btn_wrap.add_child(_tap_btn)

	# ── Result label row ───────────────────────────────────────────────────────
	_result_lbl = Label.new()
	_result_lbl.text = ""
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_lbl.add_theme_font_size_override("font_size", 20)
	if ThemeManager and ThemeManager.has_method("apply_bangers_font"):
		ThemeManager.apply_bangers_font(_result_lbl, 20)
	_result_lbl.visible = false
	add_child(_result_lbl)

# ── Interaction ────────────────────────────────────────────────────────────────

func _on_bar_input(event: InputEvent) -> void:
	if not _active or _locked:
		return
	var is_touch: bool = event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed
	var is_click: bool = event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if is_touch or is_click:
		_on_tapped()

func _on_tapped() -> void:
	if not _active or _locked:
		return
	_active = false
	_locked = true
	if _tap_btn:
		_tap_btn.visible = false

	# Determine which zone the pointer is in
	var pct := _ptr_x / BAR_WIDTH
	_chosen_mult = 1.0
	for z in ZONES:
		if pct >= z[0] and pct < z[1]:
			_chosen_mult = float(z[2])
			break

	# Flash the pointer yellow → white to give feedback
	var tw = create_tween()
	tw.tween_property(_pointer, "color", Color(1, 1, 1, 1), 0.08)
	tw.tween_property(_pointer, "color", Color(1.0, 1.0, 0.0, 0.95), 0.12)

	# Show result text
	var mult_color := Color(0.5, 0.5, 0.5)
	for z in ZONES:
		if _chosen_mult == float(z[2]):
			mult_color = z[3]
			break
	_result_lbl.text = "%.1f× — %s!" % [_chosen_mult, _mult_label(_chosen_mult)]
	_result_lbl.add_theme_color_override("font_color", mult_color)
	_result_lbl.visible = true

	if _ad_required:
		# Swap tap button for "Watch Ad to claim"
		_tap_btn.text = "📺 " + tr("UI_WATCH_AD_MULTIPLIER")
		_tap_btn.visible = true
		_tap_btn.pressed.disconnect(_on_tapped)
		_tap_btn.pressed.connect(_on_watch_ad_pressed)
		ad_requested.emit()
	else:
		# No ad required (desktop / test) — emit after short delay
		await get_tree().create_timer(0.6).timeout
		_emit_chosen()

func _on_watch_ad_pressed() -> void:
	ad_requested.emit()

func _emit_chosen() -> void:
	multiplier_chosen.emit(_chosen_mult)

func _mult_label(v: float) -> String:
	match v:
		3.0: return tr("UI_MULTIPLIER_JACKPOT")
		2.0: return tr("UI_MULTIPLIER_GREAT")
		1.5: return tr("UI_MULTIPLIER_GOOD")
		_:   return tr("UI_MULTIPLIER_OK")
