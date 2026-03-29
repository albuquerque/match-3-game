extends "res://scripts/ui/ScreenBase.gd"
class_name WorldMap

# Local resolver helper to avoid direct autoload references
var _NodeResolvers = null

func _ensure_resolvers():
	if _NodeResolvers == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL:
			_NodeResolvers = s
		else:
			_NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

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
var current_chapter_containers: Array = []
var screen_size: Vector2 = Vector2.ZERO
var scale_factor: Vector2 = Vector2.ONE

# DLC Management
var dlc_chapters: Array = []
var available_dlc: Array = []
var progress_dialog: AcceptDialog = null
var _level_start_in_progress: bool = false

# Preload gold star texture for consistent cross-platform rendering
var gold_star_texture = load("res://textures/gold_star.svg") as Texture2D

func _ready():
	# Debug: indicate migrated UI WorldMap loaded
	print("[WorldMap] loaded (res://scripts/ui/WorldMap.gd) _ready()")
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
	# Ensure fullscreen anchors and hidden by default until PageManager.show_screen() is called
	ensure_fullscreen()
	visible = false

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
	var ar = _NodeResolvers._get_ar() if typeof(_NodeResolvers) != TYPE_NIL else null
	if not ar:
		print("[WorldMap] AssetRegistry not available")
		return

	var installed = ar.get_installed_chapters()
	print("[WorldMap] Found %d installed DLC chapters" % installed.size())

	for chapter_id in installed:
		var manifest = ar.get_chapter_info(chapter_id)
		var world_map_entry = manifest.get("world_map_entry", {})
		if not world_map_entry.is_empty():
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

func _connect_dlc_signals():
	"""Connect to DLC manager signals"""
	var dlc = _NodeResolvers._get_dlc() if typeof(_NodeResolvers) != TYPE_NIL else null
	if not dlc:
		print("[WorldMap] DLCManager not available")
		return
	# Use connect(string, callable) to avoid analyzer/parse-time references to dynamic signal properties
	if dlc.has_signal("dlc_list_updated"):
		dlc.connect("dlc_list_updated", Callable(self, "_on_dlc_list_updated"))
	if dlc.has_signal("download_complete"):
		dlc.connect("download_complete", Callable(self, "_on_dlc_download_complete"))
	if dlc.has_signal("chapter_installed"):
		dlc.connect("chapter_installed", Callable(self, "_on_dlc_chapter_installed"))

func _fetch_available_dlc():
	var _dlc_local = _NodeResolvers._get_dlc() if typeof(_NodeResolvers) != TYPE_NIL else null
	if not _dlc_local:
		return
	_dlc_local.fetch_available_chapters()

func _get_dlc_asset_path(chapter_id: String, relative_path: String) -> String:
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
	var _tm = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tm and _tm.has_method("apply_bangers_font_styled"):
		_tm.apply_bangers_font_styled(title_label, 32, Color.WHITE, Color(0,0,0), 3)
	top_ui.add_child(title_label)

	var progress_container = HBoxContainer.new()
	progress_container.name = "ProgressContainer"
	progress_container.anchor_left = 0.5
	progress_container.anchor_right = 0.5
	progress_container.anchor_top = 0.5
	progress_container.anchor_bottom = 0.8
	progress_container.offset_left = -300
	progress_container.offset_right = 300
	progress_container.alignment = BoxContainer.ALIGNMENT_CENTER

	var progress_star = TextureRect.new()
	progress_star.name = "ProgressStar"
	progress_star.texture = gold_star_texture
	progress_star.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	progress_star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	progress_star.custom_minimum_size = Vector2(18, 18)
	progress_container.add_child(progress_star)

	progress_label = Label.new()
	progress_label.name = "ProgressText"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var _tmp = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tmp and _tmp.has_method("apply_bangers_font_styled"):
		_tmp.apply_bangers_font_styled(progress_label, 18, Color.WHITE, Color(0,0,0), 2)
	progress_container.add_child(progress_label)

	top_ui.add_child(progress_container)

	var back_button = Button.new()
	back_button.name = "BackButton"
	back_button.text = tr("UI_BACK_TO_MENU")
	back_button.position = Vector2(20, 20)
	back_button.custom_minimum_size = Vector2(180, 50)
	var _tmb = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tmb and _tmb.has_method("apply_bangers_font_to_button_styled"):
		_tmb.apply_bangers_font_to_button_styled(back_button, 16, Color.WHITE, Color(0,0,0), 2)
	back_button.pressed.connect(_on_back_pressed)
	top_ui.add_child(back_button)

func _populate_chapters():
	"""Create chapter containers with background images and levels"""
	for child in chapters_vbox.get_children():
		child.queue_free()
	current_chapter_containers.clear()

	_update_progress_display()

	var all_chapters = []
	for chapter_data in world_map_data.world_map.chapters:
		all_chapters.append(chapter_data)
	for dlc_chapter in dlc_chapters:
		all_chapters.append(dlc_chapter)

	all_chapters.sort_custom(func(a, b): return a.get("id", 0) < b.get("id", 0))

	for i in range(all_chapters.size()):
		var chapter_data = all_chapters[i]
		var chapter_container = _create_chapter_container(chapter_data)
		chapters_vbox.add_child(chapter_container)
		current_chapter_containers.append(chapter_container)

		if i < all_chapters.size() - 1:
			var spacer = Control.new()
			spacer.custom_minimum_size = Vector2(0, 50)
			chapters_vbox.add_child(spacer)

	update_progress()

	var total_levels = 0
	for ch in current_chapter_containers:
		var levels = ch.get_node_or_null("LevelsContainer")
		if levels:
			for n in levels.get_children():
				if n.name.begins_with("LevelContainer"):
					total_levels += 1
	print("[WorldMap] Finished populating chapters - total level buttons: %d" % total_levels)

func _create_chapter_container(chapter_data: Dictionary) -> Control:
	var chapter = Control.new()
	chapter.name = "Chapter%d" % int(chapter_data.get("id", 0))
	var chapter_height = 900 * scale_factor.y
	chapter.custom_minimum_size = Vector2(0, chapter_height)

	var chapter_bg = TextureRect.new()
	chapter_bg.name = "ChapterBackground"
	chapter_bg.anchor_right = 1.0
	chapter_bg.anchor_bottom = 1.0
	chapter_bg.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	chapter_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var bg_texture: Texture2D = null
	var bg_path = chapter_data.background_image

	if bg_path.begins_with("res://"):
		bg_texture = load(bg_path) as CompressedTexture2D
	elif bg_path.begins_with("user://"):
		var absolute_path = ProjectSettings.globalize_path(bg_path)
		if FileAccess.file_exists(absolute_path):
			var image = Image.new()
			var err = image.load(absolute_path)
			if err == OK:
				bg_texture = ImageTexture.create_from_image(image)
			else:
				push_warning("[WorldMap] Failed to load DLC background image: %s (error: %d)" % [bg_path, err])

	if bg_texture:
		chapter_bg.texture = bg_texture
		chapter_bg.z_index = 0
	else:
		var color_rect = ColorRect.new()
		color_rect.anchor_right = 1.0
		color_rect.anchor_bottom = 1.0
		color_rect.color = Color.from_string(chapter_data.theme_color, Color.BLUE)
		color_rect.color.a = 0.7
		color_rect.z_index = 0
		chapter.add_child(color_rect)

	chapter.add_child(chapter_bg)

	var chapter_title = _create_chapter_title(chapter_data)
	chapter_title.z_index = 10
	chapter.add_child(chapter_title)

	var levels_container = Control.new()
	levels_container.name = "LevelsContainer"
	levels_container.anchor_left = 0.0
	levels_container.anchor_top = 0.0
	levels_container.anchor_right = 1.0
	levels_container.anchor_bottom = 1.0
	levels_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	levels_container.z_index = 5
	chapter.add_child(levels_container)

	var initial_levels_count = 0
	var levels_array = chapter_data.get("levels", [])
	initial_levels_count = int(levels_array.size())

	if levels_array.size() == 0:
		var grid = chapter_data.get("level_grid", {})
		var rows = int(grid.get("rows", 2))
		var cols = int(grid.get("columns", 5))
		var start_num = int((chapter_data.get("id", 1) - 1) * (rows * cols) + 1)
		var generated = []
		for r in range(rows):
			for c in range(cols):
				var lvl = start_num + r * cols + c
				var gx = 120 + c * 110
				var gy = 160 + r * 120
				generated.append({"level": lvl, "pos": [gx, gy], "unlocked": true, "name": "Level %d" % lvl})
		chapter_data["levels"] = generated
		levels_array = chapter_data.get("levels", [])

	var created_in_chapter = 0
	for level_data in levels_array:
		var level_button = _create_level_button(level_data)
		levels_container.add_child(level_button)
		created_in_chapter += 1

	if chapter_data.has("next_chapter_button_pos"):
		var next_button = Button.new()
		next_button.text = tr("UI_NEXT_CHAPTER")
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
	var _tm_local = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tm_local and _tm_local.has_method("apply_bangers_font"):
		_tm_local.apply_bangers_font(title, 20)
	container.add_child(title)
	return container

func _create_level_button(level_data: Dictionary) -> Control:
	"""Create a positioned level button inside a LevelsContainer.
	Returns a Control named 'LevelContainer{N}' with a child Button 'LevelButton{N}'.
	This handles positioning (using pos or grid), locked state, and stars display.
	"""
	if not level_data or typeof(level_data) != TYPE_DICTIONARY:
		var empty_container = Control.new()
		empty_container.name = "LevelContainer_invalid"
		return empty_container

	var level_num = int(level_data.get("level", 0))
	var level_name = str(level_data.get("name", ""))
	var pos_arr = level_data.get("pos", null)

	var container = Control.new()
	container.name = "LevelContainer%d" % level_num
	container.mouse_filter = Control.MOUSE_FILTER_STOP

	var position = Vector2.ZERO
	if pos_arr and typeof(pos_arr) == TYPE_ARRAY and pos_arr.size() >= 2:
		var x = float(pos_arr[0])
		var y = float(pos_arr[1])
		position = _scale_position([x, y])
	else:
		position = Vector2(100 + ((level_num-1) % 5) * 110, 100 + int((level_num-1) / 5) * 120) * scale_factor

	var expected_btn_size = Vector2(72, 72)

	container.position = position - expected_btn_size / 2.0
	container.custom_minimum_size = Vector2(96, 96)
	container.z_index = 6

	var btn = Button.new()
	btn.name = "LevelButton%d" % level_num
	if level_name.strip_edges() != "":
		btn.text = level_name
	else:
		btn.text = str(level_num)

	var _tm2 = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tm2 and _tm2.has_method("apply_bangers_font_to_button_styled"):
		_tm2.apply_bangers_font_to_button_styled(btn, 18, Color.WHITE, Color(0,0,0), 2)

	btn.anchor_left = 0
	btn.anchor_top = 0
	btn.anchor_right = 0
	btn.anchor_bottom = 0
	btn.position = Vector2(0,0)
	btn.custom_minimum_size = Vector2(72, 72)
	btn.z_index = 7

	btn.pressed.connect(func() -> void:
		_on_level_selected(level_num)
	)

	container.add_child(btn)

	btn.disabled = true

	var stars_container = Control.new()
	stars_container.name = "StarsContainer"
	stars_container.custom_minimum_size = Vector2(90, 20)
	stars_container.position = Vector2(0, 72)
	stars_container.z_index = 8
	container.add_child(stars_container)

	# Immediately set unlocked/completed visuals using RewardManager so UI is correct on creation
	var _rm_init = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
	var completed_init = 0
	if _rm_init:
		if _rm_init.has_method("get_levels_completed"):
			completed_init = int(_rm_init.get_levels_completed())
		elif typeof(_rm_init.levels_completed) != TYPE_NIL:
			completed_init = int(_rm_init.levels_completed)

	var unlocked_init = level_num <= (completed_init + 1)
	var completed_flag_init = level_num <= completed_init
	if unlocked_init:
		if completed_flag_init:
			btn.modulate = Color.GREEN
		else:
			btn.modulate = Color.WHITE
		btn.disabled = false
	else:
		btn.modulate = Color.GRAY
		btn.disabled = true

	# Populate initial stars (if data available)
	var initial_stars = 0
	var srm_init = _NodeResolvers._get_srm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _rm_init and _rm_init.level_stars and _rm_init.level_stars.has("level_%d" % level_num):
		initial_stars = int(_rm_init.level_stars["level_%d" % level_num])
	elif srm_init and srm_init.has_method("get_level_stars"):
		initial_stars = srm_init.get_level_stars(level_num)

	for i in range(3):
		var star_tex = TextureRect.new()
		star_tex.texture = gold_star_texture
		star_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		star_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_tex.custom_minimum_size = Vector2(16, 16)
		star_tex.position = Vector2(i * 20, 0)
		if i < initial_stars:
			star_tex.modulate = Color(1.0, 0.9, 0.2)
		else:
			star_tex.modulate = Color(0.4, 0.4, 0.4, 0.6)
		stars_container.add_child(star_tex)

	print("[WorldMap] Created level button: %d at %s" % [level_num, str(position)])
	return container

func _scroll_to_next_chapter(current_chapter_id: int):
	var next_chapter_index = current_chapter_id
	if next_chapter_index < current_chapter_containers.size():
		var next_chapter = current_chapter_containers[next_chapter_index]
		var scroll_position = next_chapter.position.y + chapters_vbox.position.y
		chapters_scroll.scroll_vertical = int(scroll_position)

func _update_progress_display():
	var rm = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
	var total_stars = 0
	var levels_completed = 0
	if rm:
		if rm.has_method("get_total_stars"):
			total_stars = int(rm.get_total_stars())
		elif typeof(rm.total_stars) != TYPE_NIL:
			total_stars = int(rm.total_stars)
		# levels_completed getter/property
		if rm.has_method("get_levels_completed"):
			levels_completed = int(rm.get_levels_completed())
		elif typeof(rm.levels_completed) != TYPE_NIL:
			levels_completed = int(rm.levels_completed)

	var progress_text = get_node_or_null("TopUI/ProgressContainer/ProgressText")
	if progress_text and progress_text is Label:
		progress_text.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]
	else:
		if progress_label and progress_label is Label:
			progress_label.text = "%d Stars Collected | 📖 %d Levels Completed" % [total_stars, levels_completed]

func _get_level_stars(level_num: int) -> int:
	var key = "level_%d" % level_num
	var stars = 0
	var _rm = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _rm and _rm.level_stars and _rm.level_stars.has(key):
		stars = int(_rm.level_stars[key])
		return stars

	# Resolver-first StarRatingManager access
	var srm = _NodeResolvers._get_srm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if srm and srm.has_method("get_level_stars"):
		var v = srm.get_level_stars(level_num)
		stars = int(v) if v != null else 0
		print("[WorldMap][DIAG] _get_level_stars -> StarRatingManager returned %d for level %d" % [stars, level_num])
		return stars

	return 0

func _on_level_selected(level_num: int):
	print("[WorldMap] Level %d selected" % level_num)
	var am = _NodeResolvers._get_am() if typeof(_NodeResolvers) != TYPE_NIL else null
	if am and am.has_method("play_sfx"):
		am.play_sfx("ui_click")
	# If a level start is already in progress, ignore subsequent presses
	if _level_start_in_progress:
		print("[WorldMap] Level start already in progress - ignoring level %d" % level_num)
		return
	_level_start_in_progress = true

	# Emit the local signal for any connected listeners
	emit_signal("level_selected", level_num)

	# Resolver-first fallback: if no external system handled the signal, proceed to set level and start it here.
	# Resolve LevelManager
	var lm = _NodeResolvers._get_lm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if lm == null and has_method("get_tree"):
		var rt = get_tree().root
		if rt:
			lm = rt.get_node_or_null("LevelManager")

	var level_index = -1
	if lm and lm.has_method("get_level_index"):
		level_index = lm.get_level_index(level_num)
		if level_index >= 0:
			lm.set_current_level(level_index)
			print("[WorldMap] LevelManager current level set to index %d for level %d" % [level_index, level_num])
		else:
			print("[WorldMap] WARNING: LevelManager could not find level_number %d" % level_num)

	# PR 5c: LevelManager index is set here; ExperienceDirector pipeline calls initialize_game()
	# via LoadLevelStep → do NOT call initialize_game() directly from WorldMap.

	# PR 5c: close WorldMap directly via PageManager — no EventBus needed
	var pm = _NodeResolvers._get_pm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if pm == null and has_method("get_tree"):
		var rt3 = get_tree().root
		if rt3:
			pm = rt3.get_node_or_null("PageManager")
	if pm and pm.has_method("close"):
		# flow_starting=true prevents PageManager from auto-reopening StartPage over the board
		pm.close("WorldMap", {"flow_starting": true})
		return
	emit_signal("back_to_menu")  # last resort legacy signal

func _on_back_pressed():
	print("[WorldMap] Back to menu")
	var am2 = _NodeResolvers._get_am() if typeof(_NodeResolvers) != TYPE_NIL else null
	if am2 and am2.has_method("play_sfx"):
		am2.play_sfx("ui_click")
	# PR 5c: close directly via PageManager
	var pm = _NodeResolvers._get_pm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if pm and pm.has_method("close"):
		pm.close("WorldMap")
		return
	emit_signal("back_to_menu")

func update_progress():
	print("[WorldMap] Updating progress display")
	_update_progress_display()
	call_deferred("_deferred_update_level_buttons")

func _deferred_update_level_buttons(retries := 5):
	var rm_check = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if rm_check:
		var ls_count = 0
		if rm_check and typeof(rm_check.level_stars) == TYPE_DICTIONARY:
			ls_count = int(rm_check.level_stars.size())
		# Determine levels_completed robustly: prefer getter if available, else property
		var levels_completed_val = 0
		if rm_check and rm_check.has_method("get_levels_completed"):
			levels_completed_val = int(rm_check.get_levels_completed())
		elif rm_check and typeof(rm_check.levels_completed) != TYPE_NIL:
			levels_completed_val = int(rm_check.levels_completed)
		if ls_count == 0 and (not levels_completed_val or levels_completed_val == 0) and retries > 0:
			print("[WorldMap][DIAG] RewardManager not ready (level_stars=0). Retrying in 0.05s (retries=%d)" % retries)
			await get_tree().create_timer(0.05).timeout
			call_deferred("_deferred_update_level_buttons", retries - 1)
			return

	if rm_check:
		var total_stars_dbg = 0
		if rm_check and rm_check.has_method("get_total_stars"):
			total_stars_dbg = int(rm_check.get_total_stars())
		elif rm_check and typeof(rm_check.total_stars) != TYPE_NIL:
			total_stars_dbg = int(rm_check.total_stars)
		var levels_completed_dbg = 0
		if rm_check and rm_check.has_method("get_levels_completed"):
			levels_completed_dbg = int(rm_check.get_levels_completed())
		elif rm_check and typeof(rm_check.levels_completed) != TYPE_NIL:
			levels_completed_dbg = int(rm_check.levels_completed)
		var ls_keys_size = 0
		if rm_check and typeof(rm_check.level_stars) == TYPE_DICTIONARY:
			ls_keys_size = int(rm_check.level_stars.size())
		print("[WorldMap][DIAG] RewardManager.total_stars=%d levels_completed=%d level_stars_count=%d" % [total_stars_dbg, levels_completed_dbg, ls_keys_size])
		if ls_keys_size > 0:
			var rm_keys = rm_check.level_stars.keys()
			var sample_key = rm_keys[0]
			print("[WorldMap][DIAG] level_stars sample: %s = %s" % [str(sample_key), str(rm_check.level_stars.get(sample_key, "<nil>"))])

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
				var stars = 0
				# Prefer resolver StarRatingManager when available
				var srm_local = _NodeResolvers._get_srm() if typeof(_NodeResolvers) != TYPE_NIL else null
				if srm_local and srm_local.has_method("get_level_stars"):
					stars = srm_local.get_level_stars(level_num)
				else:
					var key = "level_%d" % level_num
					var _rm4 = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
					if _rm4 and _rm4.level_stars and _rm4.level_stars.has(key):
						stars = int(_rm4.level_stars[key])
				print("[WorldMap][DIAG] Level %d -> stars=%d" % [level_num, stars])
				_update_level_button_state(level_container)

func _update_level_button_state(level_container: Control):
	var level_num_str = level_container.name.replace("LevelContainer", "")
	var level_num = int(level_num_str)

	var rm = _NodeResolvers._get_rm() if typeof(_NodeResolvers) != TYPE_NIL else null
	var completed = 0
	if rm:
		if rm.has_method("get_levels_completed"):
			completed = int(rm.get_levels_completed())
		elif typeof(rm.levels_completed) != TYPE_NIL:
			completed = int(rm.levels_completed)

	var level_unlocked = level_num <= (completed + 1)
	var level_completed = level_num <= completed
	var stars_earned = _get_level_stars(level_num)

	var level_button = level_container.get_node_or_null("LevelButton%d" % level_num)
	# Diagnostic logging to help debug why levels show locked/completed state
	print("[WorldMap][STATE] level=%d, reward_manager_completed=%s, unlocked=%s, completed=%s" % [level_num, str(completed), str(level_unlocked), str(level_completed)])
	if level_button:
		if level_unlocked:
			if level_completed:
				level_button.modulate = Color.GREEN
			else:
				level_button.modulate = Color.WHITE
			level_button.disabled = false
		else:
			level_button.modulate = Color.GRAY
			level_button.disabled = true

		var existing_stars = level_container.get_node_or_null("StarsContainer")
		if existing_stars:
			existing_stars.queue_free()

		var max_stars_display = 3
		var stars_container = Control.new()
		stars_container.name = "StarsContainer"
		var star_size = 16
		var spacing = 4
		var total_width = max_stars_display * star_size + max(0, max_stars_display - 1) * spacing

		var btn_width = 72
		var btn_height = 72
		if level_button and level_button is Control:
			if level_button.custom_minimum_size.x > 0:
				btn_width = int(level_button.custom_minimum_size.x)
			elif level_button.custom_minimum_size.x == 0 and level_button.get_child_count() > 0:
				btn_width = int(max(72, level_button.custom_minimum_size.x))
			if level_button.custom_minimum_size.y > 0:
				btn_height = int(level_button.custom_minimum_size.y)
			elif level_button.custom_minimum_size.y == 0:
				btn_height = int(max(72, level_button.custom_minimum_size.y))

		var x = int(max((btn_width - total_width) / 2, 0))
		var y = int(btn_height + 6)

		for i in range(max_stars_display):
			var star_tex = TextureRect.new()
			star_tex.texture = gold_star_texture
			star_tex.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			star_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			star_tex.custom_minimum_size = Vector2(star_size, star_size)
			star_tex.position = Vector2(i * (star_size + spacing), 0)
			star_tex.z_index = 9
			# Use resolver-first star color if available
			var srm_color = _NodeResolvers._get_srm() if typeof(_NodeResolvers) != TYPE_NIL else null
			if srm_color and srm_color.has_method("get_star_color"):
				star_tex.modulate = srm_color.get_star_color(i + 1, stars_earned)
			else:
				if i < stars_earned:
					star_tex.modulate = Color(1.0, 0.9, 0.2)
				else:
					star_tex.modulate = Color(0.4, 0.4, 0.4, 0.6)
			stars_container.add_child(star_tex)

		level_container.add_child(stars_container)
		print("[WorldMap] Level %d stars displayed (earned=%d) at %s total_width=%d (btn_w=%d)" % [level_num, stars_earned, str(stars_container.position), total_width, btn_width])

func _on_dlc_list_updated(chapters: Array):
	available_dlc = chapters
	print("[WorldMap] Received %d available DLC chapters" % chapters.size())
	# Defer UI work to avoid forward-reference analyzer warnings
	call_deferred("_display_dlc_download_options")

func _on_dlc_download_complete(chapter_id: String, success: bool):
	if progress_dialog:
		progress_dialog.queue_free()
		progress_dialog = null

	if success:
		print("[WorldMap] DLC chapter '%s' downloaded successfully" % chapter_id)
		var card_name = "DLCCard_" + chapter_id
		var download_card = chapters_vbox.get_node_or_null(card_name)
		if download_card:
			download_card.queue_free()
		_reload_dlc_chapters()
		await get_tree().create_timer(0.1).timeout
		call_deferred("_show_download_success", chapter_id)
	else:
		print("[WorldMap] Failed to download DLC chapter '%s'" % chapter_id)
		await get_tree().create_timer(0.1).timeout
		call_deferred("_show_download_error", chapter_id)

func _on_dlc_chapter_installed(chapter_id: String):
	_reload_dlc_chapters()

func _reload_dlc_chapters():
	dlc_chapters.clear()
	_load_dlc_chapters()

# --- DLC UI helpers (migrated from legacy WorldMap implementation) ---
func _display_dlc_download_options():
	"""Display download buttons for available DLC chapters"""
	for dlc_info in available_dlc:
		var chapter_id = dlc_info.get("chapter_id", "")

		# Skip if already installed
		var _ar2 = _NodeResolvers._get_ar() if typeof(_NodeResolvers) != TYPE_NIL else null
		if _ar2 and _ar2.is_chapter_installed(chapter_id):
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
	var _tm3 = _NodeResolvers._get_tm() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _tm3 and _tm3.has_method("apply_bangers_font"):
		_tm3.apply_bangers_font(title, 16)
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
	var _dlc4 = _NodeResolvers._get_dlc() if typeof(_NodeResolvers) != TYPE_NIL else null
	if not _dlc4:
		print("[WorldMap] DLCManager not available")
		return
	_dlc4.download_chapter(chapter_id)
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
	var _dlc2 = _NodeResolvers._get_dlc() if typeof(_NodeResolvers) != TYPE_NIL else null
	if _dlc2 and _dlc2.has_signal("download_progress"):
		_dlc2.download_progress.connect(Callable(self, "_on_dlc_download_progress"))
	# Also listen for completion
	if _dlc2 and _dlc2.has_signal("download_complete"):
		_dlc2.download_complete.connect(Callable(self, "_on_dlc_download_complete"))

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
		pb = progress_dialog.get_node_or_null("DLProgressBar")
	if not pb:
		return

	if total_bytes and total_bytes > 0:
		var pct = int(float(bytes_downloaded) / float(total_bytes) * 100.0)
		pb.value = clamp(pct, 0, 100)
	else:
		pb.value = (pb.value + 5) % 100

	# Auto close when complete
	if total_bytes and total_bytes > 0 and bytes_downloaded >= total_bytes:
		await get_tree().create_timer(0.15).timeout
		if progress_dialog:
			progress_dialog.queue_free()
			progress_dialog = null
		# Disconnect handled by DLCManager on completion; safe to ignore here
