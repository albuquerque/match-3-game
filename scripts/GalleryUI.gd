extends "res://scripts/ui/ScreenBase.gd"

# Gallery UI for viewing unlocked images

signal gallery_closed

const IMAGES_PER_ROW = 3
const THUMBNAIL_SIZE = Vector2(180, 180)
const SPACING = 20

# Gallery image configuration
# Maps level to image info
const GALLERY_IMAGES = {
	2: {"id": "image_01", "name": "Victory", "url": "https://picsum.photos/512/512?random=1"},
	4: {"id": "image_02", "name": "Celebration", "url": "https://picsum.photos/512/512?random=2"},
	6: {"id": "image_03", "name": "Achievement", "url": "https://picsum.photos/512/512?random=3"},
	8: {"id": "image_04", "name": "Glory", "url": "https://picsum.photos/512/512?random=4"},
	10: {"id": "image_05", "name": "Champion", "url": "https://picsum.photos/512/512?random=5"},
	12: {"id": "image_06", "name": "Master", "url": "https://picsum.photos/512/512?random=6"},
	14: {"id": "image_07", "name": "Legend", "url": "https://picsum.photos/512/512?random=7"},
	16: {"id": "image_08", "name": "Hero", "url": "https://picsum.photos/512/512?random=8"},
	18: {"id": "image_09", "name": "Elite", "url": "https://picsum.photos/512/512?random=9"},
	20: {"id": "image_10", "name": "Ultimate", "url": "https://picsum.photos/512/512?random=10"}
}

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
	# Check if UI exists in scene, otherwise create it
	_setup_ui()

	# Setup UI
	if close_button:
		close_button.pressed.connect(_on_close_pressed)

	if viewer_close:
		viewer_close.pressed.connect(_on_viewer_close_pressed)

	# Hide viewer panel initially
	if viewer_panel:
		viewer_panel.visible = false

	# Setup HTTP request for downloading images
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_http_request_completed)

	# Populate gallery
	populate_gallery()

	# Ensure fullscreen anchors and background from ScreenBase
	ensure_fullscreen()
	visible = false

func _setup_ui():
	"""Setup UI elements - either find them in scene or create them"""
	# Try to find existing nodes first
	title_label = get_node_or_null("Panel/VBoxContainer/TitleLabel")
	close_button = get_node_or_null("Panel/VBoxContainer/TopBar/CloseButton")
	scroll_container = get_node_or_null("Panel/VBoxContainer/ScrollContainer")
	grid_container = get_node_or_null("Panel/VBoxContainer/ScrollContainer/GridContainer")
	viewer_panel = get_node_or_null("ViewerPanel")
	viewer_image = get_node_or_null("ViewerPanel/VBoxContainer/ImageRect")
	viewer_title = get_node_or_null("ViewerPanel/VBoxContainer/ImageTitle")
	viewer_close = get_node_or_null("ViewerPanel/VBoxContainer/CloseViewerButton")

	# If nodes don't exist, create them programmatically
	if not title_label:
		_create_ui_programmatically()

func _create_ui_programmatically():
	"""Create the gallery UI programmatically when scene doesn't exist"""
	print("[GalleryUI] Creating UI programmatically")

	# Main panel
	var panel = Panel.new()
	panel.name = "Panel"
	panel.anchor_left = 0.1
	panel.anchor_top = 0.1
	panel.anchor_right = 0.9
	panel.anchor_bottom = 0.9
	add_child(panel)

	# VBox container
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	panel.add_child(vbox)

	# Title label
	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "Gallery"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title_label)

	# Top bar with close button
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

	# Scroll container
	scroll_container = ScrollContainer.new()
	scroll_container.name = "ScrollContainer"
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)

	# Grid container
	grid_container = GridContainer.new()
	grid_container.name = "GridContainer"
	grid_container.columns = IMAGES_PER_ROW
	grid_container.add_theme_constant_override("h_separation", SPACING)
	grid_container.add_theme_constant_override("v_separation", SPACING)
	scroll_container.add_child(grid_container)

	# Viewer panel (for full image view)
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

	print("[GalleryUI] UI created programmatically")

func populate_gallery():
	"""Populate the gallery grid with thumbnails"""
	print("[GalleryUI] populate_gallery called")
	if not grid_container:
		print("[GalleryUI] ERROR: GridContainer not found")
		return

	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()

	# Setup grid
	grid_container.columns = IMAGES_PER_ROW

	# Sort levels to show in order
	var sorted_levels = GALLERY_IMAGES.keys()
	sorted_levels.sort()

	print("[GalleryUI] Total gallery images configured: ", sorted_levels.size())
	print("[GalleryUI] Unlocked images: ", RewardManager.get_unlocked_gallery_images())

	for level in sorted_levels:
		var image_data = GALLERY_IMAGES[level]
		var image_id = image_data["id"]
		var image_name = image_data["name"]
		var is_unlocked = RewardManager.is_gallery_image_unlocked(image_id)

		print("[GalleryUI] Level ", level, " - ", image_name, " (", image_id, "): ", "UNLOCKED" if is_unlocked else "LOCKED")

		# Create thumbnail button
		var thumb_button = create_thumbnail(image_id, image_name, level, is_unlocked)
		grid_container.add_child(thumb_button)

func create_thumbnail(image_id: String, image_name: String, level: int, is_unlocked: bool) -> Control:
	"""Create a thumbnail button for the gallery"""
	var container = VBoxContainer.new()
	container.custom_minimum_size = Vector2(THUMBNAIL_SIZE.x + 20, THUMBNAIL_SIZE.y + 60)

	# Create button
	var button = TextureButton.new()
	button.custom_minimum_size = THUMBNAIL_SIZE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_COVERED
	button.set_meta("image_id", image_id)
	button.set_meta("image_name", image_name)
	button.set_meta("level", level)

	if is_unlocked:
		# Load thumbnail from cache or download
		var cached_path = get_cached_image_path(image_id)
		if FileAccess.file_exists(cached_path):
			var img = Image.new()
			var err = img.load(cached_path)
			if err == OK:
				button.texture_normal = ImageTexture.create_from_image(img)
		else:
			# Show placeholder while loading
			button.texture_normal = create_placeholder_texture(Color.DARK_GRAY)
		# Download image
		download_image(image_id)

		button.pressed.connect(_on_thumbnail_clicked.bind(image_id, image_name))
	else:
		# Show locked state
		button.texture_normal = create_locked_texture()
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5, 0.8)

	container.add_child(button)

	# Add label
	var label = Label.new()
	label.text = image_name if is_unlocked else "Level %d" % level
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ThemeManager.apply_bangers_font(label, 14)
	container.add_child(label)

	return container

func create_placeholder_texture(color: Color) -> ImageTexture:
	"""Create a placeholder colored texture"""
	var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func create_locked_texture() -> ImageTexture:
	"""Create a locked icon texture"""
	var img = Image.create(256, 256, false, Image.FORMAT_RGB8)
	img.fill(Color(0.2, 0.2, 0.2))
	# Draw lock icon (simple representation)
	return ImageTexture.create_from_image(img)

func download_image(image_id: String):
	"""Download an image from the URL"""
	if not GALLERY_IMAGES.has(image_id):
		# Find by ID
		for level in GALLERY_IMAGES:
			if GALLERY_IMAGES[level]["id"] == image_id:
				var url = GALLERY_IMAGES[level]["url"]
				print("[GalleryUI] Downloading image: %s from %s" % [image_id, url])
				http_request.set_meta("image_id", image_id)
				http_request.request(url)
				return

	print("[GalleryUI] ERROR: Image ID not found: %s" % image_id)

func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	"""Handle HTTP request completion"""
	if result != HTTPRequest.RESULT_SUCCESS:
		print("[GalleryUI] Download failed with result: %d" % result)
		return

	if response_code != 200:
		print("[GalleryUI] Download failed with response code: %d" % response_code)
		return

	var image_id = http_request.get_meta("image_id", "")
	if image_id == "":
		print("[GalleryUI] ERROR: No image_id in request meta")
		return

	# Save image to cache
	var cached_path = get_cached_image_path(image_id)
	var file = FileAccess.open(cached_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("[GalleryUI] Image saved: %s" % cached_path)

		# Refresh gallery to show downloaded image
		populate_gallery()
	else:
		print("[GalleryUI] ERROR: Could not save image: %s" % cached_path)

func get_cached_image_path(image_id: String) -> String:
	"""Get the cache path for an image"""
	return "user://gallery_%s.jpg" % image_id

func _on_thumbnail_clicked(image_id: String, image_name: String):
	"""Handle thumbnail click to view full image"""
	print("[GalleryUI] Viewing image: %s" % image_id)

	if not viewer_panel or not viewer_image:
		return

	# Load full image
	var cached_path = get_cached_image_path(image_id)
	if FileAccess.file_exists(cached_path):
		var img = Image.new()
		var err = img.load(cached_path)
		if err == OK:
			viewer_image.texture = ImageTexture.create_from_image(img)
			viewer_title.text = image_name
			viewer_panel.visible = true
		else:
			print("[GalleryUI] ERROR: Could not load image: %s" % cached_path)
	else:
		print("[GalleryUI] ERROR: Image file not found: %s" % cached_path)

func _on_viewer_close_pressed():
	"""Close the image viewer"""
	if viewer_panel:
		viewer_panel.visible = false

func _on_close_pressed():
	"""Close the gallery"""
	visible = false
	emit_signal("gallery_closed")

func show_gallery():
	"""Show the gallery UI"""
	visible = true
	populate_gallery()

func open_gallery():
	ensure_fullscreen()
	_on_open()

func _on_open():
	show_screen()
