extends CanvasLayer
## ShardToastNotifier - center-screen zoom popup on shard/unlock events.
## Subscribes only to EventBus.shard_discovered. No other dependencies.
## Drop res://assets/gallery/shard.png to show the shard icon.
## NOTE: All nodes use MOUSE_FILTER_IGNORE so the toast never blocks gameplay input.
const SHARD_ICON_PATH := "res://assets/gallery/shard.png"
const HOLD_DURATION := 1.2
const UNLOCK_HOLD_DURATION := 1.8
# Queue so rapid drops don't stack visually
var _queue: Array = []
var _busy: bool = false

## Recursively set mouse_filter = IGNORE on a node and all its children.
static func _ignore_input_recursive(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_input_recursive(child)
func _ready() -> void:
	layer = 95
	if GalleryManager:
		GalleryManager.shard_discovered.connect(_on_shard_discovered)
		GalleryManager.gallery_unlocked.connect(_on_gallery_item_unlocked)
		print("[ShardToastNotifier] Connected to GalleryManager signals")
	else:
		push_error("[ShardToastNotifier] GalleryManager not found")
	print("[ShardToastNotifier] ready")
func _on_shard_discovered(item_id: String, _context: Dictionary) -> void:
	var prog := GalleryManager.get_progress(item_id)
	# If already unlocked at this point, the unlock toast will handle it via gallery_item_unlocked
	if prog.get("unlocked", false):
		return
	var item_name: String = _get_item_name(item_id)
	var shards: int = prog.get("shards", 0)
	var required: int = prog.get("required", 0)
	_queue.append({"name": item_name, "shards": shards, "required": required, "unlock": false})
	if not _busy:
		_next()

func _on_gallery_item_unlocked(item_id: String) -> void:
	var item_name: String = _get_item_name(item_id)
	var prog := GalleryManager.get_progress(item_id)
	_queue.append({"name": item_name, "shards": prog.get("required", 0), "required": prog.get("required", 0), "unlock": true})
	if not _busy:
		_next()

func _get_item_name(item_id: String) -> String:
	for item in GalleryManager.get_all_items():
		if str(item.get("id", "")) == item_id:
			return str(item.get("name", item_id))
	return item_id
func _next() -> void:
	if _queue.is_empty():
		_busy = false
		return
	_busy = true
	var data: Dictionary = _queue[0]
	_queue.remove_at(0)
	_show_popup(data)
func _show_popup(data: Dictionary) -> void:
	var is_unlock: bool = data.get("unlock", false)
	var popup := _build_popup(data)
	# Ensure the entire popup tree passes input through to the game board
	_ignore_input_recursive(popup)
	# Prevent Control from stretching to fill the CanvasLayer
	popup.set_anchors_preset(Control.PRESET_TOP_LEFT)
	popup.grow_horizontal = Control.GROW_DIRECTION_END
	popup.grow_vertical = Control.GROW_DIRECTION_END
	add_child(popup)

	# Wait one frame so the panel has calculated its natural size from content
	await get_tree().process_frame

	# Center on screen
	var vp := get_viewport().get_visible_rect().size
	var sz := popup.size
	popup.pivot_offset = sz / 2.0
	popup.position = (vp - sz) / 2.0

	# Zoom in from center
	popup.scale = Vector2(0.1, 0.1)
	popup.modulate.a = 0.0
	var tin := create_tween()
	tin.set_parallel(true)
	tin.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tin.tween_property(popup, "modulate:a", 1.0, 0.2)
	await tin.finished

	# Hold
	var hold := UNLOCK_HOLD_DURATION if is_unlock else HOLD_DURATION
	await get_tree().create_timer(hold).timeout

	# Zoom out
	var tout := create_tween()
	tout.set_parallel(true)
	tout.tween_property(popup, "scale", Vector2(0.6, 0.6), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tout.tween_property(popup, "modulate:a", 0.0, 0.2)
	await tout.finished
	popup.queue_free()
	_next()
func _build_popup(data: Dictionary) -> Control:
	var is_unlock: bool = data.get("unlock", false)
	var item_name: String = data.get("name", "")
	var shards: int = data.get("shards", 0)
	var required: int = data.get("required", 0)
	# Outer panel
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(380, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	if is_unlock:
		style.bg_color = Color(0.15, 0.10, 0.03, 0.97)
		style.border_color = Color(1.0, 0.82, 0.2, 1.0)
	else:
		style.bg_color = Color(0.06, 0.05, 0.16, 0.97)
		style.border_color = Color(0.55, 0.35, 1.0, 1.0)
	panel.add_theme_stylebox_override("panel", style)
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	# Padding top
	var pad_top := Control.new()
	pad_top.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(pad_top)
	# Shard icon — constrained to exact size, image resized before texturing
	const ICON_SIZE := 216
	var icon := TextureRect.new()
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Load and resize the image to the icon size before creating the texture
	var abs_path := ProjectSettings.globalize_path(SHARD_ICON_PATH)
	var img := Image.new()
	var err := img.load(abs_path)
	if err == OK and not img.is_empty():
		img.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		icon.texture = ImageTexture.create_from_image(img)
		print("[ShardToastNotifier] shard icon loaded ", abs_path)
	elif ResourceLoader.exists(SHARD_ICON_PATH):
		var res_tex: Texture2D = load(SHARD_ICON_PATH)
		# Resize via Image to enforce size
		var ri := res_tex.get_image()
		ri.resize(ICON_SIZE, ICON_SIZE, Image.INTERPOLATE_LANCZOS)
		icon.texture = ImageTexture.create_from_image(ri)
		print("[ShardToastNotifier] shard icon loaded via ResourceLoader")
	else:
		print("[ShardToastNotifier] WARNING: shard icon not found at ", SHARD_ICON_PATH)
		var fb_img := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
		var col: Color = Color(1.0, 0.82, 0.2) if is_unlock else Color(0.55, 0.35, 1.0)
		for px in range(ICON_SIZE):
			for py in range(ICON_SIZE):
				var dx := px - ICON_SIZE / 2.0
				var dy := py - ICON_SIZE / 2.0
				var r := ICON_SIZE / 2.0 - 2.0
				if dx * dx + dy * dy <= r * r:
					fb_img.set_pixel(px, py, col)
		icon.texture = ImageTexture.create_from_image(fb_img)
	vbox.add_child(icon)
	# Header label
	var header := Label.new()
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 18)
	if is_unlock:
		header.text = tr("SHARD_TOAST_UNLOCKED")
		header.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	else:
		header.text = tr("SHARD_TOAST_FOUND")
		header.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	vbox.add_child(header)
	# Item name
	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(name_lbl)
	# Progress bar (hidden on unlock)
	if not is_unlock:
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = required
		bar.value = shards
		bar.custom_minimum_size = Vector2(280, 20)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		vbox.add_child(bar)
		var count_lbl := Label.new()
		count_lbl.text = tr("SHARD_TOAST_PROGRESS") % [shards, required]
		count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_lbl.add_theme_font_size_override("font_size", 16)
		count_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		vbox.add_child(count_lbl)
	# Padding bottom
	var pad_bot := Control.new()
	pad_bot.custom_minimum_size = Vector2(0, 16)
	vbox.add_child(pad_bot)
	return panel
