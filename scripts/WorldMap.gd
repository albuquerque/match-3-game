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
# Preload gold star texture for consistent cross-platform rendering
var gold_star_texture = load("res://textures/gold_star.svg") as Texture2D

func _ready():
	"""Initialize the world map"""
	screen_size = get_viewport_rect().size
	# Base design was for 720x1280, calculate scale factors
	scale_factor = Vector2(screen_size.x / 720.0, screen_size.y / 1280.0)
	_load_world_map_data()
	_setup_ui()
	_populate_chapters()
	# Ready

func _scale_position(pos: Array) -> Vector2:
	"""Convert JSON position to screen-scaled position"""
	return Vector2(pos[0] * scale_factor.x, pos[1] * scale_factor.y)

func _load_world_map_data():
	"""Load world map configuration from JSON"""
	var path = "res://levels/world_map.json"
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
	title_label.text = world_map_data.world_map.title
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
	back_button.text = "← Back to Menu"
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

	# Create each chapter
	for chapter_data in world_map_data.world_map.chapters:
		var chapter_container = _create_chapter_container(chapter_data)
		chapters_vbox.add_child(chapter_container)
		current_chapter_containers.append(chapter_container)

		# Add spacing between chapters
		if chapter_data.id < world_map_data.world_map.chapters.size():
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 50)
			chapters_vbox.add_child(spacer)

func _create_chapter_container(chapter_data: Dictionary) -> Control:
	"""Create a complete chapter container with background and levels"""
	# Main chapter container - scale height based on screen
	var chapter = Control.new()
	chapter.name = "Chapter%d" % chapter_data.id
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
	var bg_texture = load(chapter_data.background_image) as CompressedTexture2D
	if bg_texture:
		chapter_bg.texture = bg_texture
	else:
		# Fallback colored background
		var color_rect = ColorRect.new()
		color_rect.anchor_right = 1.0
		color_rect.anchor_bottom = 1.0
		color_rect.color = Color.from_string(chapter_data.theme_color, Color.BLUE)
		color_rect.color.a = 0.7  # Semi-transparent
		chapter.add_child(color_rect)

	chapter.add_child(chapter_bg)

	# Chapter Title
	var chapter_title = _create_chapter_title(chapter_data)
	chapter.add_child(chapter_title)

	# Levels Container (for custom positioning)
	var levels_container = Control.new()
	levels_container.name = "LevelsContainer"
	levels_container.anchor_right = 1.0
	levels_container.anchor_bottom = 1.0
	chapter.add_child(levels_container)

	# Create level buttons
	for level_data in chapter_data.levels:
		var level_button = _create_level_button(level_data)
		levels_container.add_child(level_button)

	# Next Chapter Button (if not last chapter)
	if chapter_data.has("next_chapter_button_pos"):
		var next_button = _create_next_chapter_button(chapter_data)
		chapter.add_child(next_button)

	return chapter

func _create_chapter_title(chapter_data: Dictionary) -> Label:
	"""Create chapter title label"""
	var title = Label.new()
	title.name = "ChapterTitle"
	title.text = chapter_data.title
	title.position = Vector2(0, 30 * scale_factor.y)
	title.anchor_right = 1.0
	title.custom_minimum_size = Vector2(0, 80 * scale_factor.y)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	var title_font_size = int(28 * min(scale_factor.x, scale_factor.y))
	ThemeManager.apply_bangers_font(title, title_font_size)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)

	return title

func _create_level_button(level_data: Dictionary) -> Control:
	"""Create a level button with stars and name"""
	var rm = RewardManager
	var level_num = level_data.level
	var level_unlocked = level_num <= rm.levels_completed + 1
	var level_completed = level_num <= rm.levels_completed
	var stars_earned = _get_level_stars(level_num)

	# Container for the entire level display - use scaled position
	var scaled_pos = _scale_position(level_data.pos)
	var button_size = 130 * min(scale_factor.x, scale_factor.y)  # Scale uniformly

	var level_container = Control.new()
	level_container.name = "LevelContainer%d" % level_num
	level_container.position = Vector2(scaled_pos.x - button_size/2, scaled_pos.y - button_size/2)
	level_container.custom_minimum_size = Vector2(button_size, button_size)

	# Main level button - scale size
	var button_actual_size = 60 * min(scale_factor.x, scale_factor.y)
	var level_button = Button.new()
	level_button.name = "LevelButton%d" % level_num
	level_button.position = Vector2((button_size - button_actual_size) / 2, (button_size - button_actual_size) / 2 - 10)
	level_button.size = Vector2(button_actual_size, button_actual_size)
	level_button.text = str(level_num)
	var font_size = int(18 * min(scale_factor.x, scale_factor.y))
	ThemeManager.apply_bangers_font_to_button(level_button, font_size)

	# Style based on status
	if level_unlocked:
		if level_completed:
			level_button.modulate = Color.GREEN
		else:
			level_button.modulate = Color.WHITE
		level_button.disabled = false
		level_button.pressed.connect(_on_level_selected.bind(level_num))
	else:
		level_button.modulate = Color.GRAY
		level_button.disabled = true

	level_container.add_child(level_button)

	# Stars display - scale positioning and size
	if level_completed and stars_earned > 0:
		var stars_container = HBoxContainer.new()
		stars_container.position = Vector2(button_size * 0.15, 5)
		stars_container.custom_minimum_size = Vector2(button_size * 0.7, 20 * scale_factor.y)
		stars_container.alignment = BoxContainer.ALIGNMENT_CENTER

		for i in range(stars_earned):
			# Use TextureRect with the provided gold star SVG so mobile renders consistently
			var star_tex = TextureRect.new()
			star_tex.texture = gold_star_texture
			star_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			star_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			# size scaled according to UI scale factor
			star_tex.custom_minimum_size = Vector2(18 * scale_factor.x, 18 * scale_factor.y)
			stars_container.add_child(star_tex)

		level_container.add_child(stars_container)

	# Level name - scale positioning and font
	var name_label = Label.new()
	name_label.text = level_data.name
	name_label.position = Vector2(0, button_size * 0.7)
	name_label.size = Vector2(button_size, 30 * scale_factor.y)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var name_font_size = int(12 * min(scale_factor.x, scale_factor.y))
	# Styled name label for consistency
	ThemeManager.apply_bangers_font_styled(name_label, name_font_size, Color.WHITE, Color(0,0,0), 2)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	level_container.add_child(name_label)

	return level_container

func _create_next_chapter_button(chapter_data: Dictionary) -> Button:
	"""Create next chapter button"""
	var rm = RewardManager
	var chapter_levels = chapter_data.levels
	var min_level = chapter_levels[0].level if chapter_levels.size() > 0 else 1
	var max_level = chapter_levels[-1].level if chapter_levels.size() > 0 else 10
	var chapter_complete = rm.levels_completed >= max_level

	var next_button = Button.new()
	next_button.name = "NextChapterButton"
	next_button.text = "Next Chapter →" if chapter_complete else "Complete Chapter to Continue"

	# Scale position and size
	var scaled_pos = _scale_position(chapter_data.next_chapter_button_pos)
	var button_width = 200 * scale_factor.x
	var button_height = 50 * scale_factor.y
	next_button.position = Vector2(scaled_pos.x - button_width/2, scaled_pos.y)
	next_button.custom_minimum_size = Vector2(button_width, button_height)
	var button_font_size = int(16 * min(scale_factor.x, scale_factor.y))
	ThemeManager.apply_bangers_font_to_button(next_button, button_font_size)

	if chapter_complete:
		next_button.modulate = Color.WHITE
		next_button.disabled = false
		next_button.pressed.connect(_scroll_to_next_chapter.bind(chapter_data.id))
	else:
		next_button.modulate = Color.GRAY
		next_button.disabled = true

	return next_button

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
	var rm = RewardManager
	var total_stars = rm.total_stars
	var levels_completed = rm.levels_completed

	# Update the combined progress text (star icon is a texture in the container)
	var progress_text = get_node_or_null("TopUI/ProgressContainer/ProgressText")
	if progress_text and progress_text is Label:
		progress_text.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]
	else:
		# Fallback: try to assign to module-level progress_label if created earlier
		if progress_label and progress_label is Label:
			progress_label.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]

func _get_level_stars(level_num: int) -> int:
	"""Get star count for a specific level"""
	var rm = RewardManager
	var level_key = "level_%d" % level_num
	return rm.level_stars.get(level_key, 0)

func _on_level_selected(level_num: int):
	"""Handle level selection"""
	print("[WorldMap] Level %d selected" % level_num)
	AudioManager.play_sfx("ui_click")
	level_selected.emit(level_num)

func _on_back_pressed():
	"""Handle back button"""
	print("[WorldMap] Back to menu")
	AudioManager.play_sfx("ui_click")
	back_to_menu.emit()

func update_progress():
	"""Update the map display when progress changes"""
	print("[WorldMap] Updating progress display")
	_update_progress_display()

	# Update level button states
	for container in current_chapter_containers:
		var levels_container = container.get_node("LevelsContainer")
		for level_container in levels_container.get_children():
			if level_container.name.begins_with("LevelContainer"):
				_update_level_button_state(level_container)

func _update_level_button_state(level_container: Control):
	"""Update a single level button's state"""
	var level_num_str = level_container.name.replace("LevelContainer", "")
	var level_num = int(level_num_str)

	var rm = RewardManager
	var level_unlocked = level_num <= rm.levels_completed + 1
	var level_completed = level_num <= rm.levels_completed
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

		if level_completed and stars_earned > 0:
			var stars_container = HBoxContainer.new()
			stars_container.name = "StarsContainer"
			stars_container.position = Vector2(20, 5)
			stars_container.custom_minimum_size = Vector2(90, 20)
			stars_container.alignment = BoxContainer.ALIGNMENT_CENTER

			for i in range(stars_earned):
				# Create TextureRect star instead of emoji label for reliable mobile rendering
				var star_tex = TextureRect.new()
				star_tex.texture = gold_star_texture
				star_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				star_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				star_tex.custom_minimum_size = Vector2(16, 16)
				stars_container.add_child(star_tex)

			level_container.add_child(stars_container)
