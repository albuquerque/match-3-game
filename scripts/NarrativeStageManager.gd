extends Node

## NarrativeStageManager
## Manages narrative stage lifecycle and integration with game systems
## This is the main entry point for the narrative stage system

var controller: Node = null
var renderer: Node = null
var active_stage_id: String = ""

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
	controller = Node.new()
	controller.name = "NarrativeStageController"
	controller.set_script(controller_scene)
	add_child(controller)
	print("[NarrativeStageManager] Controller created and added")

	# Create renderer (as Control node for UI)
	renderer = Control.new()
	renderer.name = "NarrativeStageRenderer"
	renderer.set_script(renderer_scene)

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
	# Clear any existing stage
	clear_stage()

	# Try to find stage JSON for this level
	var stage_path = "res://data/narrative_stages/level_%d.json" % level_num

	if FileAccess.file_exists(stage_path):
		print("[NarrativeStageManager] Loading stage for level ", level_num)
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

func clear_stage():
	"""Clear current narrative stage"""
	if controller:
		controller.clear_stage()

	active_stage_id = ""
	print("[NarrativeStageManager] Stage cleared")

func set_anchor(anchor_name: String):
	"""Set which visual anchor the renderer should use"""
	if renderer:
		renderer.set_visual_anchor(anchor_name)

func is_stage_active() -> bool:
	"""Check if a narrative stage is currently active"""
	return active_stage_id != ""

func _try_load_dlc_stage(level_num: int) -> bool:
	"""Try to load narrative stage from DLC for this level"""
	# Get current chapter for this level
	var level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager:
		return false

	# Check if level is in a DLC chapter
	# (This would need to be implemented based on your level-to-chapter mapping)

	return false
