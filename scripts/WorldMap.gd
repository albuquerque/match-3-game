extends Control

# World Map / Level Select Screen for Biblical Match-3 Game
# Based on JSON structure with background images per chapter

signal level_selected(level_number: int)
signal back_to_menu

# UI Node references
@onready var background: TextureRect
@onready var map_container: Control
@onready var chapters_scroll: ScrollContainer
@onready var chapters_vbox: VBoxContainer
@onready var top_ui: Control
@onready var title_label: Label

# Progress text label (created dynamically in _setup_ui)
var progress_label: Label = null

# Data
var world_map_data: Dictionary = {}
var current_chapter_containers: Array[Control] = []
var screen_size: Vector2 = Vector2.ZERO
var scale_factor: Vector2 = Vector2.ONE

# DLC Management
var dlc_chapters: Array = []
var available_dlc: Array = []
var progress_dialog: AcceptDialog = null

# Preload gold star texture for consistent cross-platform rendering
var gold_star_texture = load("res://textures/gold_star.svg") as Texture2D

var NodeResolvers = null

func _ensure_resolvers():
    if NodeResolvers == null:
        var s = load("res://scripts/helpers/node_resolvers_api.gd")
        if s != null and typeof(s) != TYPE_NIL:
            NodeResolvers = s
        else:
            NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

# Cached autoload resolvers
var _cached_ar: Node = null
var _cached_dlc: Node = null
var _cached_am: Node = null
var _cached_rm: Node = null

func _ar():
	if is_instance_valid(_cached_ar):
		return _cached_ar
	var a = NodeResolvers._get_ar() if typeof(NodeResolvers) != TYPE_NIL else null
	if a == null and has_method("get_tree"):
		var _root = get_tree().root
		if _root:
			a = _root.get_node_or_null("AssetRegistry")
	_cached_ar = a
	return a

func _get_dlc():
    if is_instance_valid(_cached_dlc):
        return _cached_dlc
    var d = NodeResolvers._get_dlc() if typeof(NodeResolvers) != TYPE_NIL else null
    if d == null and has_method("get_tree"):
        var _root = get_tree().root
        if _root:
            d = _root.get_node_or_null("DLCManager")
    _cached_dlc = d
    return d

func _ready():
	"""Initialize the world map"""
	screen_size = get_viewport_rect().size
	_ensure_resolvers()
	# Base design was for 720x1280, calculate scale factors
	scale_factor = Vector2(screen_size.x / 720.0, screen_size.y / 1280.0)
	_load_world_map_data()
	_load_dlc_chapters()
	_connect_dlc_signals()
	_setup_ui()
	_populate_chapters()
	_fetch_available_dlc()
	# Ready

func _scale_position(pos: Array) -> Vector2:
	"""Convert JSON position to screen-scaled position"""
	return Vector2(pos[0] * scale_factor.x, pos[1] * scale_factor.y)

func _load_world_map_data():
	"""Load world map configuration from JSON"""
	var path = "res://data/levels/world_map.json"
	if not FileAccess.file_exists(path):
		print("[WorldMap] world_map.json not found at: %s" % path)
		_create_fallback_data()
		return

	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()

		var json = JSON.new()
		var parse_result = json.parse(json_string)

		if parse_result == OK and json.data:
			# Ensure structure contains expected keys
			if typeof(json.data) == TYPE_DICTIONARY and json.data.has("world_map") and json.data.world_map.has("chapters"):
				world_map_data = json.data
				var chapters_count = 0
				if typeof(world_map_data.world_map.chapters) == TYPE_ARRAY:
					chapters_count = world_map_data.world_map.chapters.size()
				print("[WorldMap] Loaded world map data: %d chapters" % chapters_count)
				return
			else:
				print("[WorldMap] world_map.json missing expected keys, using fallback")
				_create_fallback_data()
				return
		else:
			print("[WorldMap] Error parsing world_map.json - using fallback")
			_create_fallback_data()
			return
	else:
		print("[WorldMap] Could not open world_map.json, using fallback")
		_create_fallback_data()
		return

func _create_fallback_data():
	"""Create basic fallback data if JSON loading fails"""
	world_map_data = {
		"world_map": {
			"title": "Journey of Faith",
			"chapters": [
				{
					"id": 1,
					"title": "Genesis: The Beginning",
					"background_image": "res://textures/background.jpg",
					"theme_color": "#3D5A80",
					"levels": []
				}
			]
		}
	}

	# Add basic levels 1-10 for fallback
	for i in range(1, 11):
		world_map_data.world_map.chapters[0].levels.append({
			"level": i,
			"pos": [200 + (i-1) * 100, 600],
			"unlocked": i <= 3,
			"name": "Level %d" % i
		})

func _load_dlc_chapters():
	"""Load installed DLC chapters and integrate into world map"""
	if not AssetRegistry:
		print("[WorldMap] AssetRegistry not available")
		return

	var ar = _ar()
	if ar == null:
		print("[WorldMap] AssetRegistry resolver returned null")
		return
	var installed = ar.get_installed_chapters()
	print("[WorldMap] Found %d installed DLC chapters" % installed.size())

	for chapter_id in installed:
		print("[WorldMap] Processing chapter_id: %s" % chapter_id)
		var manifest = ar.get_chapter_info(chapter_id)
		print("[WorldMap] Manifest keys: %s" % str(manifest.keys()))

		var world_map_entry = manifest.get("world_map_entry", {})
		print("[WorldMap] world_map_entry: %s" % str(world_map_entry))
		print("[WorldMap] world_map_entry.is_empty(): %s" % str(world_map_entry.is_empty()))

		if not world_map_entry.is_empty():
			# Create chapter data in same format as built-in chapters
			var chapter_data = {
				"id": world_map_entry.get("chapter_number", 99),
				"title": world_map_entry.get("title", "DLC Chapter"),
				"background_image": _get_dlc_asset_path(chapter_id, world_map_entry.get("background_image", "")),
				"theme_color": world_map_entry.get("theme_color", "#4A90E2"),
				"level_grid": world_map_entry.get("level_grid", {}),
				"levels": [],
				"source": "dlc",
				"chapter_id": chapter_id
			}

			# Convert level data from manifest format to world_map format
			var manifest_levels = manifest.get("levels", [])
			for level_info in manifest_levels:
				chapter_data["levels"].append({
					"level": level_info.get("number"),
					"name": level_info.get("name", ""),
					"pos": level_info.get("pos", [360, 180]),
					"unlocked": level_info.get("unlocked", false),
					"source": "dlc",
					"file": level_info.get("file", "")
				})

			dlc_chapters.append(chapter_data)
			print("[WorldMap] Loaded DLC chapter: %s (%d levels)" % [chapter_data["title"], chapter_data["levels"].size()])
		else:
			print("[WorldMap] ⚠️ Skipping chapter %s - world_map_entry is empty!" % chapter_id)

func _connect_dlc_signals():
	"""Connect to DLC manager signals"""
	# DLC manager resolved earlier via _dlc()
	var dlc = _get_dlc()
	if dlc == null:
		print("[WorldMap] DLCManager not available")
		return

	print("[WorldMap] Connecting DLC signals...")
	dlc.connect("dlc_list_updated", self, "_on_dlc_list_updated")
	dlc.connect("download_complete", self, "_on_dlc_download_complete")
	dlc.connect("chapter_installed", self, "_on_dlc_chapter_installed")
	print("[WorldMap] ✓ All DLC signals connected")

func _fetch_available_dlc():
	"""Fetch available DLC chapters from server"""
	var dlc2 = _get_dlc()
	if dlc2 == null:
		return

	dlc2.fetch_available_chapters()

func _get_dlc_asset_path(chapter_id: String, relative_path: String) -> String:
	"""Convert DLC relative path to full path"""
	if relative_path.begins_with("res://"):
		return relative_path
	return "user://dlc/chapters/" + chapter_id + "/" + relative_path

func _setup_ui():
	"""Create the UI hierarchy based on the pseudodoc structure"""
	# Main Background (full screen)
	background = TextureRect.new()
	background.name = "Background"
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	# Set a default background
	var default_texture = load("res://textures/background.jpg") as CompressedTexture2D
	if default_texture:
		background.texture = default_texture

	# Map Container (full rect with margins)
	map_container = Control.new()
	map_container.name = "MapContainer"
	map_container.anchor_left = 0.05
	map_container.anchor_right = 0.95
	map_container.anchor_top = 0.1
	map_container.anchor_bottom = 0.9
	add_child(map_container)

	# Chapters Scroll Container
	chapters_scroll = ScrollContainer.new()
	chapters_scroll.name = "ChaptersScroll"
	chapters_scroll.anchor_right = 1.0
	chapters_scroll.anchor_bottom = 1.0
	chapters_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	map_container.add_child(chapters_scroll)

	# Chapters VBox Container
	chapters_vbox = VBoxContainer.new()
	chapters_vbox.name = "ChaptersVBox"
	chapters_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapters_scroll.add_child(chapters_vbox)

	# Top UI (title and progress)
	top_ui = Control.new()
	top_ui.name = "TopUI"
	top_ui.anchor_right = 1.0
	top_ui.custom_minimum_size = Vector2(0, 100)
	add_child(top_ui)

	# Title
	title_label = Label.new()
	title_label.name = "Title"
	title_label.text = tr("WORLDMAP_TITLE") if not world_map_data or not world_map_data.world_map.title else world_map_data.world_map.title
	title_label.anchor_left = 0.5
	title_label.anchor_right = 0.5
	title_label.anchor_top = 0.2
	title_label.anchor_bottom = 0.5
	title_label.offset_left = -200
	title_label.offset_right = 200
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Apply styled font (outline/glow)
	ThemeManager.apply_bangers_font_styled(title_label, 32, Color.WHITE, Color(0,0,0), 3)
	top_ui.add_child(title_label)

	# Progress container: star icon + text (use texture for star to ensure mobile consistency)
	var progress_container = HBoxContainer.new()
	progress_container.name = "ProgressContainer"
	progress_container.anchor_left = 0.5
	progress_container.anchor_right = 0.5
	progress_container.anchor_top = 0.5
	progress_container.anchor_bottom = 0.8
	progress_container.offset_left = -300
	progress_container.offset_right = 300
	progress_container.alignment = BoxContainer.ALIGNMENT_CENTER

	# Star icon
	var progress_star = TextureRect.new()
	progress_star.name = "ProgressStar"
	progress_star.texture = gold_star_texture
	progress_star.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	progress_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	progress_star.custom_minimum_size = Vector2(18, 18)
	progress_container.add_child(progress_star)

	# Progress text
	progress_label = Label.new()
	progress_label.name = "ProgressText"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Styled progress text
	ThemeManager.apply_bangers_font_styled(progress_label, 18, Color.WHITE, Color(0,0,0), 2)
	progress_container.add_child(progress_label)

	top_ui.add_child(progress_container)

	# Back Button
	var back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = tr("UI_BACK_TO_MENU")
	back_button.position = Vector2(20, 20)
	back_button.custom_minimum_size = Vector2(180, 50)
	ThemeManager.apply_bangers_font_to_button_styled(back_button, 16, Color.WHITE, Color(0,0,0), 2)
	back_button.pressed.connect(_on_back_pressed)
	top_ui.add_child(back_button)

func _populate_chapters():
	"""Create chapter containers with background images and levels"""
	# Clear existing chapters
	for child in chapters_vbox.get_children():
		child.queue_free()
	current_chapter_containers.clear()

	# Update progress
	_update_progress_display()

	# Combine built-in and DLC chapters
	var all_chapters = []

	# Add built-in chapters
	for chapter_data in world_map_data.world_map.chapters:
		all_chapters.append(chapter_data)

	# Add DLC chapters
	for dlc_chapter in dlc_chapters:
		all_chapters.append(dlc_chapter)

	# Sort by chapter ID
	all_chapters.sort_custom(func(a, b): return a.get("id", 0) < b.get("id", 0))

	print("[WorldMap] Displaying %d total chapters (%d built-in + %d DLC)" % [all_chapters.size(), world_map_data.world_map.chapters.size(), dlc_chapters.size()])

	# Create each chapter
	for i in range(all_chapters.size()):
		var chapter_data = all_chapters[i]
		var chapter_container = _create_chapter_container(chapter_data)
		chapters_vbox.add_child(chapter_container)
		current_chapter_containers.append(chapter_container)

		# Add spacing between chapters (except after last)
		if i < all_chapters.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 50)
			chapters_vbox.add_child(spacer)

	# After adding all chapters, ensure level button states are updated
	update_progress()

	# Debug: count created level buttons
	var total_levels = 0
	for ch in current_chapter_containers:
		var levels = ch.get_node_or_null("LevelsContainer")
		if levels:
			for n in levels.get_children():
				if n.name.begins_with("LevelContainer"):
					total_levels += 1
	print("[WorldMap] Finished populating chapters - total level buttons: %d" % total_levels)

func _create_chapter_container(chapter_data: Dictionary) -> Control:
	"""Create a complete chapter container with background and levels"""
	# Main chapter container - scale height based on screen
	var chapter = Control.new()
	chapter.name = "Chapter%d" % int(chapter_data.get("id", 0))
	var chapter_height = 900 * scale_factor.y  # Increased to accommodate y=810 button
	chapter.custom_minimum_size = Vector2(0, chapter_height)

	# Chapter Background
	var chapter_bg = TextureRect.new()
	chapter_bg.name = "ChapterBackground"
	chapter_bg.anchor_right = 1.0
	chapter_bg.anchor_bottom = 1.0
	chapter_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	chapter_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	# Load chapter background image
	var bg_texture: Texture2D = null
	var bg_path = chapter_data.background_image

	if bg_path.begins_with("res://"):
		# Built-in resource - use load()
		bg_texture = load(bg_path) as CompressedTexture2D
	elif bg_path.begins_with("user://"):
		# DLC resource - load from file system
		var absolute_path = ProjectSettings.globalize_path(bg_path)
		if FileAccess.file_exists(absolute_path):
			var image = Image.new()
			var err = image.load(absolute_path)
			if err == OK:
				bg_texture = ImageTexture.create_from_image(image)
			else:
				push_warning("[WorldMap] Failed to load DLC background image: %s (error: %d)" % [bg_path, err])
		else:
			print("[WorldMap] Background image not found: %s - using fallback" % bg_path)

	if bg_texture:
		chapter_bg.texture = bg_texture
		chapter_bg.z_index = 0
	else:
		# Fallback colored background
		var color_rect = ColorRect.new()
		color_rect.anchor_right = 1.0
		color_rect.anchor_bottom = 1.0
		color_rect.color = Color.from_string(chapter_data.theme_color, Color.BLUE)
		color_rect.color.a = 0.7  # Semi-transparent
		color_rect.z_index = 0
		chapter.add_child(color_rect)

	chapter.add_child(chapter_bg)

	# Chapter Title
	var chapter_title = _create_chapter_title(chapter_data)
	chapter_title.z_index = 10
	chapter.add_child(chapter_title)

	# Levels Container (for custom positioning)
	var levels_container = Control.new()
	levels_container.name = "LevelsContainer"
	# Ensure it fills the chapter area
	levels_container.anchor_left = 0.0
	levels_container.anchor_top = 0.0
	levels_container.anchor_right = 1.0
	levels_container.anchor_bottom = 1.0
	levels_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	levels_container.z_index = 5
	chapter.add_child(levels_container)

	# Create level buttons
	var initial_levels_count = 0
	var levels_array = chapter_data.get("levels", [])
	initial_levels_count = int(levels_array.size())
	print("[WorldMap] Chapter %s initial levels: %d" % [str(chapter_data.get("id", "?")), initial_levels_count])

	if levels_array.size() == 0:
		# Fallback: generate synthetic levels using level_grid or default 2x5
		var grid = chapter_data.get("level_grid", {})
		var rows = int(grid.get("rows", 2))
		var cols = int(grid.get("columns", 5))
		var start_num = int((chapter_data.get("id", 1) - 1) * (rows * cols) + 1)
		print("[WorldMap] No explicit levels found for chapter %s — generating %dx%d grid starting at %d" % [str(chapter_data.get("id", "?")), rows, cols, start_num])
		var generated = []
		for r in range(rows):
			for c in range(cols):
				var lvl = start_num + r * cols + c
				# Position grid with spacing; base positions are chosen to fit typical chapter layout
				var gx = 120 + c * 110
				var gy = 160 + r * 120
				generated.append({"level": lvl, "pos": [gx, gy], "unlocked": true, "name": "Level %d" % lvl})
		chapter_data["levels"] = generated
		levels_array = chapter_data.get("levels", [])
		print("[WorldMap] Generated %d levels for chapter %s" % [levels_array.size(), str(chapter_data.get("id", "?"))])

	var created_in_chapter = 0
	for level_data in levels_array:
		var level_button = _create_level_button(level_data)
		levels_container.add_child(level_button)
		created_in_chapter += 1

	print("[WorldMap] Chapter %s created %d level buttons (had %d levels)" % [str(chapter_data.get("id", "?")), created_in_chapter, initial_levels_count])

	# Next Chapter Button (if not last chapter)
	if chapter_data.has("next_chapter_button_pos"):
		var next_button = Button.new()
		var chapter_complete = chapter_data.get("complete", false)
		next_button.text = tr("UI_NEXT_CHAPTER") if chapter_complete else tr("UI_COMPLETE_CHAPTER")
		# ...existing code to position and style button ...
		chapter.add_child(next_button)

	return chapter

func _create_chapter_title(chapter_data: Dictionary) -> Control:
	var container = HBoxContainer.new()
	container.name = "ChapterTitle"
	container.anchor_left = 0.5
	container.anchor_right = 0.5
	container.custom_minimum_size = Vector2(0, 40)
	container.alignment = BoxContainer.ALIGNMENT_CENTER

	var title = Label.new()
	title.text = chapter_data.title
	ThemeManager.apply_bangers_font(title, 20)
	container.add_child(title)
	return container

func _create_level_button(level_data: Dictionary) -> Control:
	"""Create a positioned level button inside a LevelsContainer.
	Returns a Control named 'LevelContainer{N}' with a child Button 'LevelButton{N}'.
	This handles positioning (using pos or grid), locked state, and stars display.
	"""
	# Defensive: ensure level_data is a dictionary
	if not level_data or typeof(level_data) != TYPE_DICTIONARY:
		var empty_container = Control.new()
		empty_container.name = "LevelContainer_invalid"
		return empty_container

	var level_num = int(level_data.get("level", 0))
	var level_name = str(level_data.get("name", ""))
	var pos_arr = level_data.get("pos", null)

	# Container to allow positioned children without being affected by VBox layout
	var container = Control.new()
	container.name = "LevelContainer%d" % level_num
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	# Determine position (scale JSON pos to screen)
	var position = Vector2.ZERO
	if pos_arr and typeof(pos_arr) == TYPE_ARRAY and pos_arr.size() >= 2:
		# Coerce to floats safely
		var x = float(pos_arr[0])
		var y = float(pos_arr[1])
		position = _scale_position([x, y])
	else:
		# Fallback grid layout: staggered positions based on level number
		position = Vector2(100 + ((level_num-1) % 5) * 110, 100 + int((level_num-1) / 5) * 120) * scale_factor

	# We'll treat 'position' as the desired center for the button; compute container top-left
	# Determine expected button size (use fixed fallback)
	var expected_btn_size = Vector2(72, 72)

	# Position container so that the button inside (anchored at 0,0) is centered at `position`
	container.position = position - expected_btn_size / 2.0
	container.custom_minimum_size = Vector2(96, 96)
	container.z_index = 6

	# Create the visible button
	var btn = Button.new()
	btn.name = "LevelButton%d" % level_num
	# Prefer level name if provided, else numeric label
	if level_name.strip_edges() != "":
		btn.text = level_name
	else:
		btn.text = str(level_num)

	# Styling: apply themed font if ThemeManager exists, else keep default
	if typeof(ThemeManager) != TYPE_NIL and ThemeManager and ThemeManager.has_method("apply_bangers_font_to_button_styled"):
		ThemeManager.apply_bangers_font_to_button_styled(btn, 18, Color.WHITE, Color(0,0,0), 2)

	# Size and anchors: keep absolute positioning inside LevelsContainer
	btn.anchor_left = 0
	btn.anchor_top = 0
	btn.anchor_right = 0
	btn.anchor_bottom = 0
	btn.position = Vector2(0,0)
	btn.custom_minimum_size = Vector2(72, 72)
	btn.z_index = 7

	# Connect press to selection
	btn.pressed.connect(func() -> void:
		_on_level_selected(level_num)
	)

	container.add_child(btn)

	# Visual indicator for locked/completed state will be updated later in _update_level_button_state
	btn.disabled = true

	# Optional star container (will be populated in update)
	var stars_container = Control.new()
	stars_container.name = "StarsContainer"
	stars_container.custom_minimum_size = Vector2(90, 20)
	# Keep placeholder just below the button; real positioning computed in update
	stars_container.position = Vector2(0, 72)
	stars_container.z_index = 8
	container.add_child(stars_container)

	print("[WorldMap] Created level button: %d at %s" % [level_num, str(position)])
	return container

func _scroll_to_next_chapter(current_chapter_id: int):
	"""Scroll to the next chapter"""
	var next_chapter_index = current_chapter_id  # 0-based index for containers
	if next_chapter_index < current_chapter_containers.size():
		var next_chapter = current_chapter_containers[next_chapter_index]
		# Calculate scroll position to show the next chapter
		var scroll_position = next_chapter.position.y + chapters_vbox.position.y
		chapters_scroll.scroll_vertical = int(scroll_position)

func _update_progress_display():
	"""Update the progress display at the top"""
	var rm = _rm()
	var total_stars = 0
	var levels_completed = 0
	if rm:
		total_stars = rm.total_stars
		levels_completed = rm.levels_completed

	# Update the combined progress text (star icon is a texture in the container)
	var progress_text = get_node_or_null("TopUI/ProgressContainer/ProgressText")
	if progress_text and progress_text is Label:
		progress_text.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]
	else:
		# Fallback: try to assign to module-level progress_label if created earlier
		if progress_label and progress_label is Label:
			progress_label.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]

func _get_level_stars(level_num: int) -> int:
	"""Return number of stars earned for given level.
	First check RewardManager.level_stars (the persisted save), then fall back to StarRatingManager.
	Logs the resolved value for diagnostics.
	"""
	var key = "level_%d" % level_num
	var stars = 0
	var rm_local = _rm()
	if rm_local and rm_local.level_stars.has(key):
		stars = int(rm_local.level_stars[key])
		print("[WorldMap][DIAG] _get_level_stars -> RewardManager key %s = %d" % [key, stars])
		return stars

	if typeof(StarRatingManager) != TYPE_NIL and StarRatingManager and StarRatingManager.has_method("get_level_stars"):
		var v = StarRatingManager.get_level_stars(level_num)
		stars = int(v) if v != null else 0
		print("[WorldMap][DIAG] _get_level_stars -> StarRatingManager returned %d for level %d" % [stars, level_num])
		return stars

	# Fallback: no star info available
	print("[WorldMap][DIAG] _get_level_stars -> no data for level %d" % level_num)
	return 0


func _on_level_selected(level_num: int):
	"""Handle level selection"""
	print("[WorldMap] Level %d selected" % level_num)
	var _am_local = _am()
	if _am_local and _am_local.has_method("play_sfx"):
		_am_local.play_sfx("ui_click")
	level_selected.emit(level_num)

func _on_back_pressed():
	"""Handle back button"""
	print("[WorldMap] Back to menu")
	var _am_local2 = _am()
	if _am_local2 and _am_local2.has_method("play_sfx"):
		_am_local2.play_sfx("ui_click")
	back_to_menu.emit()

func update_progress():
	"""Update the map display when progress changes"""
	print("[WorldMap] Updating progress display")
	_update_progress_display()

	# Defer heavy layout-dependent updates to the next idle so Controls have correct rect_size
	call_deferred("_deferred_update_level_buttons")


func _deferred_update_level_buttons(retries := 5):
	# If RewardManager hasn't loaded save data yet, retry a few times
	var rm_check = _rm()
	if rm_check:
		var ls_count = rm_check.level_stars.keys().size()
		if ls_count == 0 and rm_check.levels_completed == 0 and retries > 0:
			print("[WorldMap][DIAG] RewardManager not ready (level_stars=0). Retrying in 0.05s (retries=%d)" % retries)
			await get_tree().create_timer(0.05).timeout
			# Defer to avoid blocking layout
			call_deferred("_deferred_update_level_buttons", retries - 1)
			return

	# Run a layout-sensitive update after the current frame so rect_size/anchors settle
	# Diagnostic: print RewardManager star state for debugging missing stars
	var rm_diag = _rm()
	if rm_diag:
		print("[WorldMap][DIAG] RewardManager.total_stars=%d levels_completed=%d level_stars_count=%d" % [rm_diag.total_stars, rm_diag.levels_completed, rm_diag.level_stars.keys().size()])
		# Build a safe sample of keys without using Python-style slicing
		var rm_keys = rm_diag.level_stars.keys()
		if rm_keys.size() > 0:
			# Print only the first sample key/value to keep diagnostics simple and parser-friendly
			var sample_key = rm_keys[0]
			print("[WorldMap][DIAG] level_stars sample: %s = %s" % [str(sample_key), str(rm_diag.level_stars.get(sample_key, "<nil>"))])
	# If StarRatingManager is available, print its total as well
	if typeof(StarRatingManager) != TYPE_NIL:
		print("[WorldMap][DIAG] StarRatingManager available. get_total_stars(): %d" % StarRatingManager.get_total_stars())

	for container in current_chapter_containers:
		var levels_container = container.get_node_or_null("LevelsContainer")
		if not levels_container:
			continue
		for level_container in levels_container.get_children():
			if level_container.name.begins_with("LevelContainer"):
				var level_num_str = level_container.name.replace("LevelContainer", "")
				var level_num = int(level_num_str)
				# Diagnostic: fetch stars
				var stars = 0
				if typeof(StarRatingManager) != TYPE_NIL and StarRatingManager and StarRatingManager.has_method("get_level_stars"):
					stars = StarRatingManager.get_level_stars(level_num)
				else:
					var key = "level_%d" % level_num
					var rm_local2 = _rm()
					if rm_local2 and rm_local2.level_stars.has(key):
						stars = int(rm_local2.level_stars[key])
				print("[WorldMap][DIAG] Level %d -> stars=%d" % [level_num, stars])
				_update_level_button_state(level_container)

func _update_level_button_state(level_container: Control):
	"""Update a single level button's state"""
	var level_num_str = level_container.name.replace("LevelContainer", "")
	var level_num = int(level_num_str)

	var rm = _rm()
	var level_unlocked = false
	var level_completed = false
	if rm:
		level_unlocked = level_num <= rm.levels_completed + 1
		level_completed = level_num <= rm.levels_completed

	var stars_earned = _get_level_stars(level_num)

	var level_button = level_container.get_node_or_null("LevelButton%d" % level_num)
	if level_button:
		# Update button state
		if level_unlocked:
			if level_completed:
				level_button.modulate = Color.GREEN
			else:
				level_button.modulate = Color.WHITE
			level_button.disabled = false
		else:
			level_button.modulate = Color.GRAY
			level_button.disabled = true

		# Update stars display
		var existing_stars = level_container.get_node_or_null("StarsContainer")
		if existing_stars:
			existing_stars.queue_free()

		# Always show a 3-star row under the button to make progress visible
		var max_stars_display = 3
		var stars_container = Control.new()
		stars_container.name = "StarsContainer"
		# Create centered placement beneath the level button
		var star_size = 16
		var spacing = 4
		var total_width = max_stars_display * star_size + max(0, max_stars_display - 1) * spacing

		# Determine button width/height using custom_minimum_size first (avoid rect_size access which can fail in some contexts)
		var btn_width = 72
		var btn_height = 72
		if level_button and level_button is Control:
			# Prefer explicit custom_minimum_size if available
			if level_button.custom_minimum_size.x > 0:
				btn_width = int(level_button.custom_minimum_size.x)
			elif level_button.custom_minimum_size.x == 0 and level_button.get_child_count() > 0:
				# fallback: attempt to infer size from child textures or default
				btn_width = int(max(72, level_button.custom_minimum_size.x))
			if level_button.custom_minimum_size.y > 0:
				btn_height = int(level_button.custom_minimum_size.y)
			elif level_button.custom_minimum_size.y == 0:
				btn_height = int(max(72, level_button.custom_minimum_size.y))

		var x = int(max((btn_width - total_width) / 2, 0))
		var y = int(btn_height + 6)

		stars_container.position = Vector2(x, y)
		stars_container.custom_minimum_size = Vector2(total_width, star_size)
		stars_container.z_index = 8

		for i in range(max_stars_display):
			var star_tex = TextureRect.new()
			star_tex.texture = gold_star_texture
			if star_tex.texture == null:
				print("[WorldMap][DIAG] star_tex.texture is null for level %d index %d" % [level_num, i])
			star_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			star_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star_tex.custom_minimum_size = Vector2(star_size, star_size)
			star_tex.position = Vector2(i * (star_size + spacing), 0)
			star_tex.z_index = 9
			# Color: gold for earned, grey for unearned
			if typeof(StarRatingManager) != TYPE_NIL and StarRatingManager and StarRatingManager.has_method("get_star_color"):
				star_tex.modulate = StarRatingManager.get_star_color(i + 1, stars_earned)
			else:
				if i < stars_earned:
					star_tex.modulate = Color(1.0, 0.9, 0.2)
				else:
					star_tex.modulate = Color(0.4, 0.4, 0.4, 0.6)
			stars_container.add_child(star_tex)

		level_container.add_child(stars_container)
		print("[WorldMap] Level %d stars displayed (earned=%d) at %s total_width=%d (btn_w=%d)" % [level_num, stars_earned, str(stars_container.position), total_width, btn_width])

# DLC Chapter Management

func _on_dlc_list_updated(chapters: Array):
	"""Handle DLC list update from server"""
	available_dlc = chapters
	print("[WorldMap] Received %d available DLC chapters" % chapters.size())
	_display_dlc_download_options()

func _on_dlc_download_complete(chapter_id: String, success: bool):
	"""Handle DLC download completion"""
	print("[WorldMap] _on_dlc_download_complete called: chapter_id=%s, success=%s" % [chapter_id, success])

	# Close progress dialog first
	if progress_dialog:
		print("[WorldMap] Closing progress dialog")
		progress_dialog.queue_free()
		progress_dialog = null
	else:
		print("[WorldMap] No progress dialog to close")

	if success:
		print("[WorldMap] DLC chapter '%s' downloaded successfully" % chapter_id)

		# Remove the download card
		var card_name = "DLCCard_" + chapter_id
		var download_card = chapters_vbox.get_node_or_null(card_name)
		if download_card:
			print("[WorldMap] Removing download card: %s" % card_name)
			download_card.queue_free()

		# Reload chapters to display the new DLC chapter
		_reload_dlc_chapters()

		# Show success message after a short delay to ensure cleanup
		print("[WorldMap] Scheduling success dialog")
		await get_tree().create_timer(0.1).timeout
		_show_download_success(chapter_id)
	else:
		print("[WorldMap] Failed to download DLC chapter '%s'" % chapter_id)
		# Use await for error dialog as well
		await get_tree().create_timer(0.1).timeout
		_show_download_error(chapter_id)

func _on_dlc_chapter_installed(chapter_id: String):
	"""Handle DLC chapter installation"""
	print("[WorldMap] DLC chapter '%s' installed" % chapter_id)
	_reload_dlc_chapters()

func _reload_dlc_chapters():
	"""Reload DLC chapters and update UI"""
	print("[WorldMap] _reload_dlc_chapters called - clearing DLC chapters array")
	dlc_chapters.clear()

	print("[WorldMap] Loading DLC chapters...")
	_load_dlc_chapters()

	print("[WorldMap] Repopulating world map with %d DLC chapters" % dlc_chapters.size())
	_populate_chapters()

func _display_dlc_download_options():
	"""Display download buttons for available DLC chapters"""
	for dlc_info in available_dlc:
		var chapter_id = dlc_info.get("chapter_id", "")

		# Skip if already installed
		var ar2 = _ar()
		if ar2 and ar2.is_chapter_installed(chapter_id):
			continue

		# Create download card
		var download_card = _create_dlc_download_card(dlc_info)
		chapters_vbox.add_child(download_card)

func _create_dlc_download_card(dlc_info: Dictionary) -> Control:
	"""Create a small card control with DLC title/desc and a Download button."""
	var card = HBoxContainer.new()
	card.name = "DLCCard_%s" % str(dlc_info.get("chapter_id", "unknown"))
	card.custom_minimum_size = Vector2(0, 80)
	card.alignment = BoxContainer.ALIGNMENT_CENTER

	var vbox = VBoxContainer.new()
	vbox.name = "DLCCardVBox"

	var title = Label.new()
	title.name = "DLCTitle"
	title.text = dlc_info.get("name", "New Chapter")
	ThemeManager.apply_bangers_font(title, 16)
	vbox.add_child(title)

	var desc = Label.new()
	desc.name = "DLCDesc"
	desc.text = dlc_info.get("description", "")
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	card.add_child(vbox)

	var btn = Button.new()
	btn.name = "DLCDownloadButton"
	btn.text = tr("UI_DOWNLOAD")
	btn.focus_mode = Control.FOCUS_NONE
	# Connect to an inline callable that captures dlc_info safely
	btn.pressed.connect(func(): _on_download_dlc_pressed(dlc_info))
	card.add_child(btn)

	return card


func _on_download_dlc_pressed(dlc_info: Dictionary):
	"""Handle DLC download button press"""
	var chapter_id = dlc_info.get("chapter_id", "")
	var is_free = dlc_info.get("is_free", true)

	print("[WorldMap] Download requested for: %s" % chapter_id)

	if is_free:
		_start_dlc_download(chapter_id)
	else:
		# TODO: Integrate with payment system
		_show_purchase_dialog(dlc_info)

func _start_dlc_download(chapter_id: String):
	"""Start downloading a DLC chapter"""
	var dlc3 = _get_dlc()
	if dlc3 == null:
		print("[WorldMap] DLCManager not available")
		return

	print("[WorldMap] Starting download: %s" % chapter_id)
	dlc3.download_chapter(chapter_id)

	_show_download_progress(chapter_id)

func _show_download_progress(chapter_id: String):
	"""Show a progress dialog while a DLC chapter is downloading.
	This connects to DLCManager.download_progress to update the UI and disconnects on completion.
	"""
	# Ensure any existing dialog is cleared
	if progress_dialog:
		progress_dialog.queue_free()
		progress_dialog = null

	# Create a dialog with a progress bar
	progress_dialog = AcceptDialog.new()
	progress_dialog.title = tr("UI_DOWNLOADING")
	# Add a VBox to hold a label and a ProgressBar
	var v = VBoxContainer.new()
	v.name = "DLProgressVBox"
	var label = Label.new()
	label.name = "DLProgressLabel"
	label.text = tr("UI_DOWNLOADING_CHAPTER") + ": %s" % chapter_id
	v.add_child(label)

	var pb = ProgressBar.new()
	pb.name = "DLProgressBar"
	pb.min_value = 0
	pb.max_value = 100
	pb.value = 0
	pb.custom_minimum_size = Vector2(300, 24)
	v.add_child(pb)

	progress_dialog.add_child(v)
	progress_dialog.dialog_close_on_escape = false
	progress_dialog.ok_button_text = tr("UI_BACKGROUND")
	add_child(progress_dialog)
	progress_dialog.popup_centered()

	# Connect to DLCManager signals if available
	var dlc4 = _get_dlc()
	if dlc4 and dlc4.has_signal("download_progress"):
		dlc4.connect("download_progress", self, "_on_dlc_download_progress")
	# Also listen for completion (existing handler will close dialog)
	if dlc4 and dlc4.has_signal("download_complete"):
		dlc4.connect("download_complete", self, "_on_dlc_download_complete")

func _show_purchase_dialog(dlc_info: Dictionary):
	"""Show purchase confirmation dialog"""
	var dialog = ConfirmationDialog.new()
	dialog.title = "Purchase Chapter"
	dialog.dialog_text = "Purchase '%s' for $%.2f?" % [dlc_info.get("name", ""), dlc_info.get("price_usd", 0.0)]
	dialog.ok_button_text = "Purchase"
	dialog.cancel_button_text = "Cancel"

	dialog.confirmed.connect(func(): _process_purchase(dlc_info))

	add_child(dialog)
	dialog.popup_centered()

func _process_purchase(dlc_info: Dictionary):
	"""Process DLC purchase"""
	# TODO: Integrate with in-app purchase system
	print("[WorldMap] Purchase initiated for: %s" % dlc_info.get("chapter_id", ""))

	# For now, just download if it's "purchased"
	_start_dlc_download(dlc_info.get("chapter_id", ""))

func _show_download_error(chapter_id: String):
	"""Show download error dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Download Failed"
	dialog.dialog_text = "Failed to download chapter. Please check your internet connection and try again."
	add_child(dialog)
	dialog.popup_centered()

func _show_download_success(chapter_id: String):
	"""Show download success dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Download Complete!"
	dialog.dialog_text = "Chapter downloaded successfully! You can now play the new levels."
	add_child(dialog)
	dialog.popup_centered()


func _on_dlc_download_progress(chapter_id: String, bytes_downloaded: int, total_bytes: int):
	"""Update progress dialog when DLCManager emits download_progress."""
	if not progress_dialog:
		return
	# Resolve progress bar
	var pb = progress_dialog.get_node_or_null("DLProgressVBox/DLProgressBar")
	if not pb:
		# Try to find directly under dialog
		pb = progress_dialog.get_node_or_null("DLProgressBar")
	if not pb:
		return

	if total_bytes and total_bytes > 0:
		var pct = int(float(bytes_downloaded) / float(total_bytes) * 100.0)
		pb.value = clamp(pct, 0, 100)
	else:
		# Unknown size - use indeterminate animation by pulsing value
		pb.value = (pb.value + 5) % 100

	# Auto close when complete
	if total_bytes and total_bytes > 0 and bytes_downloaded >= total_bytes:
		# Give a short delay then close
		await get_tree().create_timer(0.15).timeout
		if progress_dialog:
			progress_dialog.queue_free()
			progress_dialog = null
		# Disconnect signals to avoid dangling references
		var dlc5 = _get_dlc()
		if dlc5 and dlc5.has_signal("download_progress") and dlc5.is_connected("download_progress", self, "_on_dlc_download_progress"):
			dlc5.disconnect("download_progress", self, "_on_dlc_download_progress")
		if dlc5 and dlc5.has_signal("download_complete") and dlc5.is_connected("download_complete", self, "_on_dlc_download_complete"):
			dlc5.disconnect("download_complete", self, "_on_dlc_download_complete")
