extends Control

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

@onready var title_label = $Panel/VBoxContainer/TitleLabel
@onready var close_button = $Panel/VBoxContainer/TopBar/CloseButton
@onready var scroll_container = $Panel/VBoxContainer/ScrollContainer
@onready var grid_container = $Panel/VBoxContainer/ScrollContainer/GridContainer
@onready var viewer_panel = $ViewerPanel
@onready var viewer_image = $ViewerPanel/VBoxContainer/ImageRect
@onready var viewer_title = $ViewerPanel/VBoxContainer/ImageTitle
@onready var viewer_close = $ViewerPanel/VBoxContainer/CloseViewerButton

func _ready():
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

static func get_image_for_level(level: int) -> Dictionary:
	"""Get gallery image info for a specific level"""
	if GALLERY_IMAGES.has(level):
		return GALLERY_IMAGES[level]
	return {}

