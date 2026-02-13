extends Node

## NarrativeStageManager
## Manages narrative stage lifecycle and integration with game systems
## This is the main entry point for the narrative stage system

var controller: Node = null
var renderer: Node = null
var active_stage_id: String = ""
var _locked: bool = false  # When true, prevent external clears/auto-loads from overriding the active stage

# Preloaded scenes
var controller_scene = preload("res://scripts/NarrativeStageController.gd")
var renderer_scene = preload("res://scripts/NarrativeStageRenderer.gd")

func _ready():
	print("[NarrativeStageManager] Ready")
	_init_components()

func _init_components():
	"""Initialize controller and renderer"""
	print("[NarrativeStageManager] === INITIALIZING COMPONENTS ===")

	# Create controller
	controller = controller_scene.new()
	controller.name = "NarrativeStageController"
	add_child(controller)
	print("[NarrativeStageManager] Controller created and added")

	# Create renderer (as Control node for UI)
	renderer = renderer_scene.new()
	renderer.name = "NarrativeStageRenderer"

	print("[NarrativeStageManager] Renderer created, attempting to find MainGame...")

	# Add renderer to the MainGame scene root for proper fullscreen display
	# This allows fullscreen narratives to cover the entire screen
	var main_game = get_node_or_null("/root/MainGame")
	if main_game:
		print("[NarrativeStageManager] ✓ MainGame found!")
		main_game.add_child(renderer)
		print("[NarrativeStageManager] ✓ Renderer added to MainGame as child")
		print("[NarrativeStageManager]   Renderer parent: ", renderer.get_parent().name)
		print("[NarrativeStageManager]   Renderer path: ", renderer.get_path())
	else:
		# Fallback: add to this autoload (won't be truly fullscreen)
		add_child(renderer)
		print("[NarrativeStageManager] ⚠️ WARNING: MainGame not found!")
		print("[NarrativeStageManager] ⚠️ Renderer added to autoload (won't be fullscreen)")
		print("[NarrativeStageManager]   Renderer parent: ", renderer.get_parent().name)

	# Link controller to renderer
	controller.set_renderer(renderer)

	print("[NarrativeStageManager] === Components initialized ===")

func load_stage_for_level(level_num: int) -> bool:
	"""Load narrative stage for a specific level if available"""
	# If a stage is already active (for example the Experience pipeline explicitly loaded a stage),
	# do NOT auto-load the per-level stage. This preserves explicit flow control and avoids
	# the situation where a flow's requested stage is immediately replaced by a level-specific stage.
	if active_stage_id != "":
		print("[NarrativeStageManager] Active stage '%s' already present; skipping auto-load for level %d" % [active_stage_id, level_num])
		return false

	# Clear any existing stage
	clear_stage()

	# Try to find stage JSON for this level
	# New layout: store per-level narrative stages under data/narrative_stages/levels/
	var stage_path = "res://data/narrative_stages/levels/level_%d.json" % level_num

	if FileAccess.file_exists(stage_path):
		print("[NarrativeStageManager] Loading stage for level ", level_num)
		# Read anchor from the level-specific JSON before loading so renderer can be configured
		var file = FileAccess.open(stage_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				var stage_data = json.get_data()
				var anchor = stage_data.get("anchor", "top_banner")
				if renderer:
					renderer.set_visual_anchor(anchor)
					print("[NarrativeStageManager] ✓ Anchor set on renderer for level ", level_num, ": ", anchor)

		if controller.load_stage_from_file(stage_path):
			active_stage_id = "level_%d" % level_num

			# Preload assets for performance
			var stage_data = controller.current_stage_data
			if stage_data and renderer:
				renderer.preload_assets(stage_data)

			return true

	# Try DLC stages
	if _try_load_dlc_stage(level_num):
		return true

	print("[NarrativeStageManager] No narrative stage for level ", level_num)
	return false

func load_stage_by_id(stage_id: String) -> bool:
	"""Load a specific narrative stage by ID"""
	print("[NarrativeStageManager] === LOADING STAGE BY ID: ", stage_id, " ===")
	clear_stage()

	var stage_path = "res://data/narrative_stages/%s.json" % stage_id

	if FileAccess.file_exists(stage_path):
		print("[NarrativeStageManager] ✓ Stage file found: ", stage_path)

		# CRITICAL: Load the JSON first to get the anchor setting
		var file = FileAccess.open(stage_path, FileAccess.READ)
		if file:
			var json_text = file.get_as_text()
			file.close()

			var json = JSON.new()
			if json.parse(json_text) == OK:
				var stage_data = json.get_data()
				var anchor = stage_data.get("anchor", "top_banner")

				print("[NarrativeStageManager] 📍 Stage anchor setting: ", anchor)

				# Set the anchor BEFORE loading the stage
				if renderer:
					renderer.set_visual_anchor(anchor)
					print("[NarrativeStageManager] ✓ Anchor set on renderer BEFORE loading: ", anchor)

					# If a NarrativeContainer exists (created by ShowNarrativeStep), render into it
					var root = get_tree().root if get_tree() else null
					if root:
						# common overlay name 'EffectOverlay' used by pipeline; try to find NarrativeContainer
						var candidate = root.get_node_or_null("EffectOverlay/NarrativeContainer")
						if not candidate:
							# fallback to searching for any node named NarrativeContainer
							candidate = root.find_node("NarrativeContainer", true, false)
						if candidate and renderer.has_method("set_render_container"):
							renderer.set_render_container(candidate)
							print("[NarrativeStageManager] ✓ Renderer render_container set to: ", candidate.get_path())

		# Now load the stage (this will display it with the correct anchor)
		if controller.load_stage_from_file(stage_path):
			active_stage_id = stage_id
			print("[NarrativeStageManager] ✓ Stage loaded successfully")

			# Preload assets
			var stage_data = controller.current_stage_data
			if stage_data and renderer:
				renderer.preload_assets(stage_data)
				print("[NarrativeStageManager] ✓ Assets preloaded")

			print("[NarrativeStageManager] === Stage loading complete ===")
			return true

	print("[NarrativeStageManager] ❌ Stage not found: ", stage_id)
	return false

func load_dlc_stage(chapter_id: String, stage_name: String) -> bool:
	"""Load narrative stage from DLC chapter"""
	clear_stage()

	if controller.load_stage_from_dlc(chapter_id, stage_name):
		active_stage_id = "%s:%s" % [chapter_id, stage_name]

		# Preload assets
		var stage_data = controller.current_stage_data
		if stage_data and renderer:
			renderer.preload_assets(stage_data)

		return true

	return false

func clear_stage(force: bool=false):
	"""Clear current narrative stage"""
	if _locked and not force:
		print("[NarrativeStageManager] clear_stage called but manager is locked; skipping clear")
		return
	if controller:
		controller.clear_stage()

	# Clear renderer visuals and any render container override
	if renderer:
		if renderer.has_method("clear"):
			renderer.clear()
		if renderer.has_method("clear_render_container"):
			renderer.clear_render_container()

	active_stage_id = ""
	print("[NarrativeStageManager] Stage cleared")

func set_anchor(anchor_name: String):
	"""Set which visual anchor the renderer should use"""
	if renderer:
		renderer.set_visual_anchor(anchor_name)

func is_stage_active() -> bool:
	"""Check if a narrative stage is currently active"""
	return active_stage_id != ""

func lock_stage(val: bool=true):
	"""Lock or unlock the manager to prevent auto-reloads/clears."""
	_locked = val
	print("[NarrativeStageManager] Lock set to: ", _locked)

func is_locked() -> bool:
	return _locked

func _try_load_dlc_stage(level_num: int) -> bool:
	"""Try to load narrative stage from installed DLC chapters for this level.

	This searches installed chapters for one that contains a per-level stage file.
	Search order (first match wins):
	 - <chapter_path>/levels/level_<n>.json
	 - <chapter_path>/stages/level_<n>.json
	 - <chapter_path>/narrative_stages/levels/level_<n>.json

	We use the AssetRegistry autoload when available to enumerate installed chapters; fallback to scanning "user://dlc/chapters/".
	"""
	var asset_registry = get_node_or_null("/root/AssetRegistry")
	var chapters = {}

	if asset_registry and asset_registry.has_method("get_installed_chapters"):
		# AssetRegistry exposes installed_chapters via get_installed_chapters() or property
		# get_installed_chapters() returns keys; we need the detailed map if available
		if asset_registry.has_method("get_installed_chapters"):
			# try to access the internal installed_chapters dict if present
			if "installed_chapters" in asset_registry:
				chapters = asset_registry.installed_chapters
			else:
				# fallback: ask for keys and then read via API (best-effort)
				for cid in asset_registry.get_installed_chapters():
					if asset_registry.is_chapter_installed(cid):
						# try to read chapter info
						var info = asset_registry.get_chapter_info(cid) if asset_registry.has_method("get_chapter_info") else {}
						# try to compute path
						if info and info.has("path"):
							chapters[cid] = {"path": info.path, "manifest": info}
						else:
							# try default base dir
							chapters[cid] = {"path": AssetRegistry.DLC_BASE_DIR + cid + "/", "manifest": info}
		else:
			# No method; attempt to read property directly
			if "installed_chapters" in asset_registry:
				chapters = asset_registry.installed_chapters

	# If we didn't find chapters via AssetRegistry, fall back to scanning user://dlc/chapters/
	if chapters.size() == 0:
		var dir = DirAccess.open(AssetRegistry.DLC_BASE_DIR) if (typeof(AssetRegistry) != TYPE_NIL) else null
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if dir.current_is_dir() and not fname.begins_with("."):
					var chapter_path = AssetRegistry.DLC_BASE_DIR + fname + "/"
					chapters[fname] = {"path": chapter_path, "manifest": {}}
				fname = dir.get_next()
			dir.list_dir_end()

	# Search each chapter for possible per-level files
	for cid in chapters.keys():
		var info = chapters[cid]
		var base_path = info.get("path", "")
		if base_path == "":
			continue

		var candidates = [
			base_path + "levels/level_%d.json" % level_num,
			base_path + "stages/level_%d.json" % level_num,
			base_path + "narrative_stages/levels/level_%d.json" % level_num
		]

		for cand in candidates:
			if FileAccess.file_exists(cand):
				print("[NarrativeStageManager] Found DLC stage for level %d in chapter %s: %s" % [level_num, cid, cand])
				# Read anchor from JSON and set renderer anchor before loading
				var file = FileAccess.open(cand, FileAccess.READ)
				if file:
					var json_text = file.get_as_text()
					file.close()

					var json = JSON.new()
					if json.parse(json_text) == OK:
						var stage_data = json.get_data()
						var anchor = stage_data.get("anchor", "top_banner")
						if renderer:
							renderer.set_visual_anchor(anchor)
							print("[NarrativeStageManager] ✓ Anchor set on renderer for DLC level %d: %s (chapter %s)" % [level_num, anchor, cid])

					# Load via controller (supports user:// paths)
					if controller.load_stage_from_file(cand):
						active_stage_id = "%s:level_%d" % [cid, level_num]

						# Preload assets
						var sd = controller.current_stage_data
						if sd and renderer:
							renderer.preload_assets(sd)

						return true

	# Not found in installed DLCs
	return false
