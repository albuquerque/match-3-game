extends "res://scripts/ui/ScreenBase.gd"

# Gallery Page (UI wrapper) - migrated behavior from GalleryUI.gd

signal gallery_closed

const IMAGES_PER_ROW = 3
const THUMBNAIL_SIZE = Vector2(180, 180)
const SPACING = 20

var current_viewing_image: TextureRect = null
var http_request: HTTPRequest = null

# UI elements - will be created if not present in scene
var title_label: Label = null
var close_button: Button = null
var scroll_container: ScrollContainer = null
var grid_container: GridContainer = null
var viewer_panel: Panel = null
var viewer_image: TextureRect = null
var viewer_title: Label = null
var viewer_close: Button = null

func _ready():
	_setup_ui()
	# Setup HTTP request for downloading images
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)
	populate_gallery()
	ensure_fullscreen()
	visible = false

func _setup_ui():
	# Try to find existing nodes first
	title_label = get_node_or_null("Panel/VBoxContainer/TitleLabel")
	close_button = get_node_or_null("Panel/VBoxContainer/TopBar/CloseButton")
	scroll_container = get_node_or_null("Panel/VBoxContainer/ScrollContainer")
	grid_container = get_node_or_null("Panel/VBoxContainer/ScrollContainer/GridContainer")
	viewer_panel = get_node_or_null("ViewerPanel")
	viewer_image = get_node_or_null("ViewerPanel/VBoxContainer/ImageRect")
	viewer_title = get_node_or_null("ViewerPanel/VBoxContainer/ImageTitle")
	viewer_close = get_node_or_null("ViewerPanel/VBoxContainer/CloseViewerButton")

	if not title_label:
		_create_ui_programmatically()

	# Connect buttons found via scene tree (programmatically-created ones are wired inside _create_ui_programmatically)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)
	if viewer_close and not viewer_close.pressed.is_connected(_on_viewer_close_pressed):
		viewer_close.pressed.connect(_on_viewer_close_pressed)

func _create_ui_programmatically():
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	panel.add_child(vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Gallery"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title_label)

	var top_bar = HBoxContainer.new()
	top_bar.name = "TopBar"
	vbox.add_child(top_bar)

	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	close_button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(100, 40)
	top_bar.add_child(close_button)

	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)

	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = IMAGES_PER_ROW
	grid_container.add_theme_constant_override("h_separation", SPACING)
	grid_container.add_theme_constant_override("v_separation", SPACING)
	scroll_container.add_child(grid_container)

	viewer_panel = Panel.new()
	viewer_panel.name = "ViewerPanel"
	viewer_panel.anchor_right = 1.0
	viewer_panel.anchor_bottom = 1.0
	viewer_panel.visible = false
	add_child(viewer_panel)

	var viewer_vbox = VBoxContainer.new()
	viewer_vbox.name = "VBoxContainer"
	viewer_vbox.anchor_left = 0.1
	viewer_vbox.anchor_top = 0.1
	viewer_vbox.anchor_right = 0.9
	viewer_vbox.anchor_bottom = 0.9
	viewer_panel.add_child(viewer_vbox)

	viewer_title = Label.new()
	viewer_title.name = "ImageTitle"
	viewer_title.text = ""
	viewer_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	viewer_title.add_theme_font_size_override("font_size", 24)
	viewer_vbox.add_child(viewer_title)

	viewer_image = TextureRect.new()
	viewer_image.name = "ImageRect"
	viewer_image.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	viewer_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	viewer_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer_vbox.add_child(viewer_image)

	viewer_close = Button.new()
	viewer_close.name = "CloseViewerButton"
	viewer_close.text = "Close"
	viewer_close.custom_minimum_size = Vector2(100, 40)
	viewer_vbox.add_child(viewer_close)

	# Wire signals after all nodes are created
	close_button.pressed.connect(_on_close_pressed)
	viewer_close.pressed.connect(_on_viewer_close_pressed)

func populate_gallery():
	if not grid_container:
		return
	for child in grid_container.get_children():
		child.queue_free()
	# Use a tiny static set for now: load from data or GALLERY_IMAGES if needed
	# We'll create placeholder thumbnails to keep UI functional
	for i in range(1, 11):
		var container = VBoxContainer.new()
		container.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x + 20, THUMBNAIL_SIZE.y + 60)
		var button = TextureButton.new()
		button.custom_minimum_size = THUMBNAIL_SIZE
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
		button.set_meta("image_id", "img_%02d" % i)
		button.set_meta("image_name", "Image %d" % i)
		button.set_meta("level", i)
		button.texture_normal = create_placeholder_texture(Color(0.2, 0.2, 0.2))
		button.pressed.connect(func() -> void: _on_thumbnail_clicked(button.get_meta("image_id"), button.get_meta("image_name")))
		container.add_child(button)
		var label = Label.new()
		label.text = "Image %d" % i
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(label)
		grid_container.add_child(container)

func create_placeholder_texture(color: Color) -> ImageTexture:
	var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _on_thumbnail_clicked(image_id: String, image_name: String):
	if not viewer_panel or not viewer_image:
		return
	viewer_image.texture = create_placeholder_texture(Color(0.3, 0.3, 0.3))
	viewer_title.text = image_name
	viewer_panel.visible = true

func _on_viewer_close_pressed():
	if viewer_panel:
		viewer_panel.visible = false

func _on_close_pressed():
	emit_signal("gallery_closed")
	# Close via PageManager so the page is removed from the navigation stack
	var pm = get_node_or_null("/root/PageManager")
	if pm and pm.has_method("close"):
		pm.close("GalleryPage")
	else:
		visible = false

func show_gallery():
	visible = true
	populate_gallery()

func open_gallery():
	ensure_fullscreen()
	show_screen()

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	# Minimal stub for network completion
	print("[GalleryPage] HTTP request completed: result=%d code=%d" % [result, response_code])
