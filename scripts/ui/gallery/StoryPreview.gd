extends CanvasLayer

## StoryPreview — fullscreen modal to read a narrative stage from the Story tab.
## Supports navigating to previous / next stage via arrow buttons or horizontal swipe.
## Opened by StoryCard with the full seen-stages list and starting index.

signal closed

const LAYER := 112        # above GalleryPreview (110)
const SWIPE_MIN_PX := 60  # minimum horizontal drag distance to trigger navigation

var _stages: Array = []   # full ordered list of seen stage data dicts
var _index: int = 0       # currently displayed index

# UI nodes rebuilt on each navigation
var _overlay: ColorRect = null
var _panel: Control = null

# Swipe tracking
var _touch_start: Vector2 = Vector2.ZERO
var _touch_tracking := false

func _ready() -> void:
	layer = LAYER

## Entry point. all_stages is the full ordered list; start_index is which to show first.
func open(stage_data: Dictionary, all_stages: Array = [], start_index: int = 0) -> void:
	if all_stages.is_empty():
		_stages = [stage_data]
		_index = 0
	else:
		_stages = all_stages
		_index = start_index
	_build_ui(false)

# ── Build / Rebuild UI ────────────────────────────────────────────────────

func _build_ui(animate_in: bool) -> void:
	# Clear any previous content
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame  # let queue_free flush

	var stage_data: Dictionary = _stages[_index]

	var bg_hex: String = str(stage_data.get("background_color", "#0a0a1a"))
	var bg_col := Color(bg_hex) if bg_hex.begins_with("#") else Color(0.04, 0.04, 0.10)
	var txt_hex: String = str(stage_data.get("text_color", "#ffffff"))
	var txt_col := Color(txt_hex) if txt_hex.begins_with("#") else Color.WHITE

	# Full-screen background
	_overlay = ColorRect.new()
	_overlay.name = "Overlay"
	_overlay.color = bg_col
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	# Main container
	_panel = Control.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_panel)

	# ── Top bar: Prev | Title | Counter | Close ────────────────────────────
	var top_bar := HBoxContainer.new()
	top_bar.anchor_left = 0.0
	top_bar.anchor_top = 0.0
	top_bar.anchor_right = 1.0
	top_bar.anchor_bottom = 0.0
	top_bar.offset_top = 16
	top_bar.offset_bottom = 72
	top_bar.offset_left = 12
	top_bar.offset_right = -12
	top_bar.add_theme_constant_override("separation", 8)
	_panel.add_child(top_bar)

	# Prev arrow (disabled on first item)
	var prev_btn := Button.new()
	prev_btn.name = "PrevBtn"
	prev_btn.text = "◀"
	prev_btn.custom_minimum_size = Vector2(48, 48)
	prev_btn.disabled = (_index == 0)
	prev_btn.modulate.a = 0.0 if _index == 0 else 1.0
	prev_btn.pressed.connect(_navigate.bind(-1))
	top_bar.add_child(prev_btn)

	# Title — expands to fill middle
	var title_lbl := Label.new()
	title_lbl.name = "TitleLabel"
	title_lbl.text = str(stage_data.get("name", ""))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 24)
	title_lbl.add_theme_color_override("font_color", txt_col)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top_bar.add_child(title_lbl)

	# Counter label  e.g. "3 / 7"
	var counter_lbl := Label.new()
	counter_lbl.name = "CounterLabel"
	counter_lbl.text = "%d / %d" % [_index + 1, _stages.size()]
	counter_lbl.add_theme_font_size_override("font_size", 14)
	counter_lbl.add_theme_color_override("font_color", txt_col.darkened(0.3))
	counter_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	top_bar.add_child(counter_lbl)

	# Next arrow (disabled on last item)
	var next_btn := Button.new()
	next_btn.name = "NextBtn"
	next_btn.text = "▶"
	next_btn.custom_minimum_size = Vector2(48, 48)
	next_btn.disabled = (_index >= _stages.size() - 1)
	next_btn.modulate.a = 0.0 if _index >= _stages.size() - 1 else 1.0
	next_btn.pressed.connect(_navigate.bind(1))
	top_bar.add_child(next_btn)

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = tr("UI_BUTTON_CLOSE")
	close_btn.custom_minimum_size = Vector2(60, 48)
	close_btn.pressed.connect(_close)
	top_bar.add_child(close_btn)

	# ── Content area ───────────────────────────────────────────────────────
	var art_path: String = str(stage_data.get("art_asset", ""))
	var art_start_y := 84

	if not art_path.is_empty():
		var art := TextureRect.new()
		art.name = "ArtRect"
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.anchor_left = 0.0
		art.anchor_top = 0.0
		art.anchor_right = 1.0
		art.anchor_bottom = 0.0
		art.offset_top = 88
		art.offset_bottom = 400
		art.offset_left = 40
		art.offset_right = -40
		_panel.add_child(art)
		art_start_y = 408
		_load_art_async(art, art_path)

	# Scroll area for state texts
	var scroll := ScrollContainer.new()
	scroll.name = "ScrollArea"
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_top = art_start_y
	scroll.offset_bottom = -72
	scroll.offset_left = 0
	scroll.offset_right = 0
	_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(vbox)

	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(pad_top)

	for state in stage_data.get("states", []):
		_add_state_block(vbox, state, txt_col, bg_col)

	var pad_bot := Control.new()
	pad_bot.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(pad_bot)

	# ── Bottom nav bar (swipe hint + arrow buttons) ────────────────────────
	var bottom_bar := HBoxContainer.new()
	bottom_bar.anchor_left = 0.0
	bottom_bar.anchor_top = 1.0
	bottom_bar.anchor_right = 1.0
	bottom_bar.anchor_bottom = 1.0
	bottom_bar.offset_top = -64
	bottom_bar.offset_bottom = -8
	bottom_bar.offset_left = 12
	bottom_bar.offset_right = -12
	bottom_bar.add_theme_constant_override("separation", 12)
	_panel.add_child(bottom_bar)

	var prev_btn2 := Button.new()
	prev_btn2.text = "◀ " + tr("STORY_PREV")
	prev_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prev_btn2.custom_minimum_size = Vector2(0, 48)
	prev_btn2.disabled = (_index == 0)
	prev_btn2.visible = (_stages.size() > 1)
	prev_btn2.pressed.connect(_navigate.bind(-1))
	bottom_bar.add_child(prev_btn2)

	var next_btn2 := Button.new()
	next_btn2.text = tr("STORY_NEXT") + " ▶"
	next_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_btn2.custom_minimum_size = Vector2(0, 48)
	next_btn2.disabled = (_index >= _stages.size() - 1)
	next_btn2.visible = (_stages.size() > 1)
	next_btn2.pressed.connect(_navigate.bind(1))
	bottom_bar.add_child(next_btn2)

	# ── Fade in ────────────────────────────────────────────────────────────
	if animate_in:
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(_panel, "modulate:a", 1.0, 0.18)
	else:
		_overlay.modulate.a = 0.0
		_panel.modulate.a = 0.0
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_overlay, "modulate:a", 1.0, 0.25)
		tw.tween_property(_panel, "modulate:a", 1.0, 0.25)

# ── Navigation ────────────────────────────────────────────────────────────

func _navigate(direction: int) -> void:
	var new_idx := _index + direction
	if new_idx < 0 or new_idx >= _stages.size():
		return
	_index = new_idx
	# Slide-out then rebuild
	var tw := create_tween()
	var slide_x := -200.0 if direction > 0 else 200.0
	tw.tween_property(_panel, "modulate:a", 0.0, 0.15)
	await tw.finished
	_build_ui(true)

# ── State block ───────────────────────────────────────────────────────────

func _add_state_block(vbox: VBoxContainer, state: Dictionary, txt_col: Color, bg_col: Color) -> void:
	var state_bg_hex: String = str(state.get("background_color", ""))
	var state_txt_hex: String = str(state.get("text_color", ""))
	var state_txt_col := Color(state_txt_hex) if state_txt_hex.begins_with("#") else txt_col

	var text := ""
	var text_key: String = str(state.get("text_key", ""))
	if not text_key.is_empty():
		var translated := tr(text_key)
		if translated != text_key:
			text = translated
	if text.is_empty():
		text = str(state.get("text", state.get("description", "")))

	if text.is_empty() and not state.has("asset"):
		return

	var block := PanelContainer.new()
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if state_bg_hex.begins_with("#"):
		var style := StyleBoxFlat.new()
		style.bg_color = Color(state_bg_hex)
		style.corner_radius_top_left = 8
		style.corner_radius_top_right = 8
		style.corner_radius_bottom_left = 8
		style.corner_radius_bottom_right = 8
		block.add_theme_stylebox_override("panel", style)
	vbox.add_child(block)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	block.add_child(inner)

	var asset: String = str(state.get("asset", ""))
	if not asset.is_empty():
		var full_asset := asset
		if not asset.contains("/"):
			for prefix in ["res://textures/narrative/", "res://assets/narrative/"]:
				if ResourceLoader.exists(prefix + asset):
					full_asset = prefix + asset
					break
		var state_art := TextureRect.new()
		state_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		state_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		state_art.custom_minimum_size = Vector2(0, 200)
		state_art.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(state_art)
		_load_art_async(state_art, full_asset)

	if not text.is_empty():
		var lbl := Label.new()
		lbl.text = text
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", state_txt_col)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(lbl)

# ── Swipe / input ─────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			_navigate(-1)
		elif event.keycode == KEY_RIGHT:
			_navigate(1)
		return

	# Touch / mouse swipe
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressing: bool = event.pressed if event is InputEventMouseButton else event.pressed
		var pos: Vector2 = event.position
		if pressing:
			_touch_start = pos
			_touch_tracking = true
		elif _touch_tracking:
			_touch_tracking = false
			var delta := pos.x - _touch_start.x
			if abs(delta) >= SWIPE_MIN_PX:
				_navigate(-1 if delta > 0 else 1)

# ── Art loader ────────────────────────────────────────────────────────────

func _load_art_async(rect: TextureRect, path: String) -> void:
	var tex: Texture2D = await GalleryImageLoader.load_image(path)
	if tex and is_instance_valid(rect):
		rect.texture = tex

# ── Close ─────────────────────────────────────────────────────────────────

func _close() -> void:
	if not _panel or not is_instance_valid(_panel):
		_finish_close()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	if _overlay and is_instance_valid(_overlay):
		tw.tween_property(_overlay, "modulate:a", 0.0, 0.18)
	await tw.finished
	_finish_close()

func _finish_close() -> void:
	closed.emit()
	queue_free()
