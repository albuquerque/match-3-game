extends PanelContainer

## StoryCard - displays one unlocked narrative stage in the Story tab.
## Tapping opens StoryPreview fullscreen modal with full list for prev/next navigation.

var _stage_data: Dictionary = {}
var _all_stages: Array = []   # full ordered list passed by GalleryScreen
var _index: int = 0           # position of this card in the list

func setup(stage_data: Dictionary, all_stages: Array = [], index: int = 0) -> void:
	_stage_data = stage_data
	_all_stages = all_stages
	_index = index
	_build()

func _build() -> void:
	custom_minimum_size = Vector2(0, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg_hex: String = str(_stage_data.get("background_color", "#1a1a2e"))
	var bg_col := Color(bg_hex) if bg_hex.begins_with("#") else Color(0.1, 0.1, 0.18)
	var txt_hex: String = str(_stage_data.get("text_color", "#ffffff"))
	var txt_col := Color(txt_hex) if txt_hex.begins_with("#") else Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = txt_col.darkened(0.4)
	add_theme_stylebox_override("panel", style)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	add_child(hbox)
	var art_path: String = str(_stage_data.get("art_asset", ""))
	if not art_path.is_empty():
		var art := TextureRect.new()
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.custom_minimum_size = Vector2(120, 120)
		art.size = Vector2(120, 120)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(art)
		_load_art_async(art, art_path)
	else:
		var swatch := ColorRect.new()
		swatch.color = bg_col.lightened(0.15)
		swatch.custom_minimum_size = Vector2(8, 0)
		swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		hbox.add_child(swatch)
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 6)
	hbox.add_child(vbox)
	var name_lbl := Label.new()
	name_lbl.text = str(_stage_data.get("name", tr("UNKNOWN")))
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_lbl.add_theme_color_override("font_color", txt_col)
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(name_lbl)
	var desc: String = str(_stage_data.get("description", ""))
	if desc.is_empty():
		for state in _stage_data.get("states", []):
			var sd: String = str(state.get("description", state.get("text", "")))
			if not sd.is_empty():
				desc = sd
				break
	if not desc.is_empty():
		var desc_lbl := Label.new()
		desc_lbl.text = desc
		desc_lbl.add_theme_font_size_override("font_size", 14)
		desc_lbl.add_theme_color_override("font_color", txt_col.darkened(0.2))
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(desc_lbl)
	var hint := Label.new()
	hint.text = tr("GALLERY_STORY_HINT")
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", txt_col.darkened(0.35))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(hint)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(_on_tapped)
	add_child(btn)

func _on_tapped() -> void:
	var script := load("res://scripts/ui/gallery/StoryPreview.gd")
	var preview: Node = script.new()
	get_tree().root.add_child(preview)
	preview.call("open", _stage_data, _all_stages, _index)

func _load_art_async(rect: TextureRect, path: String) -> void:
	var tex: Texture2D = await GalleryImageLoader.load_image(path)
	if tex and is_instance_valid(rect):
		rect.texture = tex
