extends CanvasLayer

## GalleryPreview - full-size image preview modal for unlocked gallery items.
## Button shows "Download Image" if not yet saved, "Open Image" if already saved.
## Ad plays before first download only. OS.shell_open() opens saved files.

signal closed

const PREVIEW_LAYER := 110

var _item_data: Dictionary = {}
var _panel: Control = null
var _preloaded_texture: Texture2D = null

func _ready() -> void:
	layer = PREVIEW_LAYER

func open(item_data: Dictionary, preloaded_texture: Texture2D = null) -> void:
	_item_data = item_data
	_preloaded_texture = preloaded_texture
	print("[GalleryPreview] open() item_id=%s art_asset=%s preloaded=%s" % [str(_item_data.get("id", "<no-id>")), str(_item_data.get("art_asset", "")), str(preloaded_texture != null)])
	_build_ui()

func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.name = "Overlay"
	overlay.color = Color(0, 0, 0, 0.75)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.gui_input.connect(_on_overlay_input)
	add_child(overlay)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.14, 0.98)
	style.border_color = Color(1.0, 0.82, 0.2, 1.0)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	_panel.add_child(vbox)

	var top_bar := HBoxContainer.new()
	vbox.add_child(top_bar)

	var title := Label.new()
	title.text = str(_item_data.get("name", ""))
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = tr("UI_BUTTON_CLOSE")
	close_btn.custom_minimum_size = Vector2(44, 44)
	close_btn.pressed.connect(_close)
	top_bar.add_child(close_btn)

	var img_container := CenterContainer.new()
	img_container.custom_minimum_size = Vector2(520, 520)
	img_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(img_container)

	var loading_lbl := Label.new()
	loading_lbl.name = "LoadingLabel"
	loading_lbl.text = tr("LOADING")
	loading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	img_container.add_child(loading_lbl)

	var art_rect := TextureRect.new()
	art_rect.name = "ArtRect"
	art_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_rect.custom_minimum_size = Vector2(520, 520)
	art_rect.size = Vector2(520, 520)
	art_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art_rect.visible = false
	img_container.add_child(art_rect)

	# If a preloaded texture was provided (from GalleryItemCard), show it immediately and skip fetching
	if _preloaded_texture and _preloaded_texture is Texture2D:
		loading_lbl.visible = false
		art_rect.texture = _preloaded_texture
		art_rect.visible = true
		# Continue to build rest of UI and return early from heavy load logic
		# (Download button label still needs the button to exist)
		# Create rarity label + download button + padding so _refresh_download_btn can find the button
		var rarity_lbl := Label.new()
		rarity_lbl.text = str(_item_data.get("rarity", "")).capitalize()
		rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rarity_lbl.add_theme_font_size_override("font_size", 16)
		rarity_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
		vbox.add_child(rarity_lbl)

		var dl_btn := Button.new()
		dl_btn.name = "DownloadBtn"
		dl_btn.text = tr("GALLERY_DOWNLOAD")
		dl_btn.custom_minimum_size = Vector2(240, 48)
		dl_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		dl_btn.pressed.connect(_on_download_pressed)
		vbox.add_child(dl_btn)

		var pad := Control.new()
		pad.custom_minimum_size = Vector2(0, 12)
		vbox.add_child(pad)

		# Now refresh the download button label (button exists)
		_refresh_download_btn()

		# Wait for layout to resolve before animating
		await get_tree().process_frame
		await get_tree().process_frame
		_panel.pivot_offset = _panel.size / 2.0

		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.85, 0.85)
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(_panel, "modulate:a", 1.0, 0.2)
		tw2.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		return

	# If no preloaded texture, show silhouette/placeholder immediately so preview isn't blank
	var initial_shown = false
	var sil_path_init = str(_item_data.get("silhouette_asset", ""))
	if sil_path_init.begins_with("res://") and ResourceLoader.exists(sil_path_init):
		var sil_tex_init = load(sil_path_init)
		if sil_tex_init:
			loading_lbl.visible = false
			art_rect.texture = sil_tex_init
			art_rect.visible = true
			initial_shown = true
	else:
		var placeholder_init = "res://assets/gallery/locked_placeholder.svg"
		if ResourceLoader.exists(placeholder_init):
			var ph_init = load(placeholder_init)
			if ph_init:
				loading_lbl.visible = false
				art_rect.texture = ph_init
				art_rect.visible = true
				initial_shown = true

	# Continue building UI (rarity label, download button etc.)
	var rarity_lbl := Label.new()
	rarity_lbl.text = str(_item_data.get("rarity", "")).capitalize()
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_lbl.add_theme_font_size_override("font_size", 16)
	rarity_lbl.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
	vbox.add_child(rarity_lbl)

	var dl_btn := Button.new()
	dl_btn.name = "DownloadBtn"
	dl_btn.text = tr("GALLERY_DOWNLOAD")
	dl_btn.custom_minimum_size = Vector2(240, 48)
	dl_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dl_btn.pressed.connect(_on_download_pressed)
	vbox.add_child(dl_btn)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 12)
	vbox.add_child(pad)

	# Refresh button label before layout resolves
	_refresh_download_btn()

	# Wait for layout to resolve before animating
	await get_tree().process_frame
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2.0

	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.85, 0.85)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.2)
	tw.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var art_url: String = str(_item_data.get("art_asset", ""))
	if not art_url.is_empty():
		# First try the GalleryImageLoader disk cache at user://gallery_cache/<md5>.png
		var cache_path = "user://gallery_cache/" + art_url.md5_text() + ".png"
		if FileAccess.file_exists(cache_path):
			print("[GalleryPreview] Found cached image at: %s" % cache_path)
			var imgc := Image.new()
			if imgc.load(ProjectSettings.globalize_path(cache_path)) == OK and not imgc.is_empty():
				var tcache = ImageTexture.create_from_image(imgc)
				loading_lbl.visible = false
				art_rect.texture = tcache
				art_rect.visible = true
				# Skip network fetch
				return
		# Not in cache — try loader (which will fetch and populate cache)
		var tex: Texture2D = await GalleryImageLoader.load_image(art_url)
		if tex and is_instance_valid(art_rect):
			loading_lbl.visible = false
			art_rect.texture = tex
			art_rect.visible = true
		else:
			# Art failed to load — attempt to show the item's silhouette or a global placeholder
			print("[GalleryPreview] Failed to load art for %s -> %s" % [str(_item_data.get("id", "<no-id>")), art_url])
			# Try item-specific silhouette
			var sil_path = str(_item_data.get("silhouette_asset", ""))
			if sil_path.begins_with("res://") and ResourceLoader.exists(sil_path):
				var sil_tex = load(sil_path)
				if sil_tex and is_instance_valid(art_rect):
					loading_lbl.visible = false
					art_rect.texture = sil_tex
					art_rect.visible = true
					print("[GalleryPreview] Fallback to silhouette: %s" % sil_path)
					return
			# Fallback to global placeholder
			var placeholder = "res://assets/gallery/locked_placeholder.svg"
			if ResourceLoader.exists(placeholder):
				var ph = load(placeholder)
				if ph and is_instance_valid(art_rect):
					loading_lbl.visible = false
					art_rect.texture = ph
					art_rect.visible = true
					print("[GalleryPreview] Fallback to global placeholder: %s" % placeholder)
				return
			# Give up, keep loading spinner
			print("[GalleryPreview] No valid fallback found for art: %s" % art_url)

func _on_overlay_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close()

## Set button label to "Open Image" if already downloaded, else "Download Image".
func _refresh_download_btn() -> void:
	var dl_btn := _panel.find_child("DownloadBtn", true, false) as Button
	if not dl_btn:
		return
	var item_name: String = str(_item_data.get("name", "image"))
	var existing := GalleryImageLoader.get_download_path(item_name)
	if FileAccess.file_exists(existing):
		dl_btn.text = tr("GALLERY_OPEN")
	else:
		dl_btn.text = tr("GALLERY_DOWNLOAD")

func _on_download_pressed() -> void:
	var dl_btn := _panel.find_child("DownloadBtn", true, false) as Button
	var item_name: String = str(_item_data.get("name", "image"))
	var existing := GalleryImageLoader.get_download_path(item_name)
	if FileAccess.file_exists(existing):
		_open_in_platform_viewer(existing)
		return
	if dl_btn:
		dl_btn.text = tr("GALLERY_LOADING_AD")
		dl_btn.disabled = true
	await _show_interstitial_and_wait()
	await _do_download(dl_btn)

## Open a locally saved file in the platform image viewer.
func _open_in_platform_viewer(abs_path: String) -> void:
	OS.shell_open(abs_path)

## Show interstitial ad and wait for it to close. Always returns.
func _show_interstitial_and_wait() -> void:
	if not AdMobManager or not AdMobManager.is_interstitial_ad_ready():
		AdMobManager.load_interstitial_ad()
		return
	AdMobManager.show_interstitial_ad()
	await AdMobManager.interstitial_ad_closed

func _do_download(dl_btn: Button) -> void:
	if dl_btn and is_instance_valid(dl_btn):
		dl_btn.text = tr("GALLERY_DOWNLOADING")
	var art_url: String = str(_item_data.get("art_asset", ""))
	var item_name: String = str(_item_data.get("name", "image"))
	var out_path := await GalleryImageLoader.download_image(art_url, item_name)
	if not is_instance_valid(dl_btn):
		return
	if out_path.is_empty():
		dl_btn.text = tr("GALLERY_DOWNLOAD_FAILED")
		dl_btn.disabled = false
	else:
		dl_btn.text = tr("GALLERY_OPEN")
		dl_btn.disabled = false

func _close() -> void:
	if not _panel or not is_instance_valid(_panel):
		_finish_close()
		return
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "modulate:a", 0.0, 0.18)
	tw.tween_property(_panel, "scale", Vector2(0.85, 0.85), 0.18)
	await tw.finished
	_finish_close()

func _finish_close() -> void:
	closed.emit()
	queue_free()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close()
