extends Node
## EffectResolver - Central dispatcher that maps events to visual effects
## Loads effect definitions from JSON and instantiates executors
## This class must NOT contain story-specific logic

# Reference to EventBus (autoload)
var event_bus: Node = null

# Active effect definitions loaded from chapter JSON
var active_effects: Array = []

# Effect executor instances (registered by type)
var executors: Dictionary = {}

# Current chapter metadata
var current_chapter: Dictionary = {}

# Cached viewport reference for executors
var cached_viewport: Window = null

# Debug helpers
var auto_enable_camera_impulse_on_match: bool = true

# ============================================
# Executor script preloads (split into scripts/effects/)
# ============================================
var executor_scripts = {
	"play_animation": preload("res://scripts/effects/play_animation_executor.gd"),
	"state_swap": preload("res://scripts/effects/state_swap_executor.gd"),
	"timeline_sequence": preload("res://scripts/effects/timeline_sequence_executor.gd"),
	"spawn_particles": preload("res://scripts/effects/spawn_particles_executor.gd"),
	"shader_param_lerp": preload("res://scripts/effects/shader_param_lerp_executor.gd"),
	"camera_impulse": preload("res://scripts/effects/camera_impulse_executor.gd"),
	"screen_overlay": preload("res://scripts/effects/screen_overlay_executor.gd"),
	"narrative_dialogue": preload("res://scripts/effects/narrative_dialogue_executor.gd"),

	# Visual effects
	"background_dim": preload("res://scripts/effects/background_dim_executor.gd"),
	"foreground_dim": preload("res://scripts/effects/foreground_dim_executor.gd"),
	"screen_flash": preload("res://scripts/effects/screen_flash_executor.gd"),
	"vignette": preload("res://scripts/effects/vignette_executor.gd"),
	"background_tint": preload("res://scripts/effects/background_tint_executor.gd"),
	"progressive_brightness": preload("res://scripts/effects/progressive_brightness_executor.gd"),

	# New narrative effects
	"gameplay_pause": preload("res://scripts/effects/gameplay_pause_executor.gd"),
	"camera_lerp": preload("res://scripts/effects/camera_lerp_executor.gd"),
	"symbolic_overlay": preload("res://scripts/effects/symbolic_overlay_executor.gd")
}

# ============================================
# Main EffectResolver Functions
# ============================================

# Development debug flag: when true, load `chapter_level_4.json` at startup so
# play_animation bindings run on level_loaded for testing. Set to false for prod.
var DEV_FORCE_LOAD_LEVEL4_CHAPTER: bool = false

func _ready():
	print("[EffectResolver] Initializing effect resolver...")

	# Get EventBus autoload
	event_bus = get_node_or_null("/root/EventBus")
	if not event_bus:
		push_warning("[EffectResolver] EventBus autoload not found - effects disabled")
		return

	# Cache viewport reference for executors
	cached_viewport = get_tree().root
	if cached_viewport:
		print("[EffectResolver] ✓ Cached viewport reference: ", cached_viewport.name)
	else:
		push_warning("[EffectResolver] Failed to cache viewport reference")

	# Register effect executors (stub implementations)
	_register_executors()

	# Connect to all gameplay events
	_connect_event_signals()

	# Dev: force-load test chapter for level 4 if enabled
	if DEV_FORCE_LOAD_LEVEL4_CHAPTER:
		var dev_path = "res://data/chapters/chapter_level_4.json"
		if FileAccess.file_exists(dev_path):
			print("[EffectResolver] DEV_FLAG: Loading dev chapter for testing: %s" % dev_path)
			load_effects_from_file(dev_path)
			# Schedule a delayed emit of level_loaded so executors run after scene is up
			if event_bus and has_method("get_tree") and get_tree() != null:
				var t = get_tree().create_timer(0.25)
				t.timeout.connect(Callable(self, "_dev_emit_level_loaded"))
		else:
			print("[EffectResolver] DEV_FLAG: Dev chapter not found: %s" % dev_path)

	print("[EffectResolver] Ready - listening for events")

## Register all available effect executors
func _register_executors():
	print("[EffectResolver] Registering effect executors...")

	# Instantiate executor instances from preloaded scripts
	for key in executor_scripts.keys():
		var script = executor_scripts.get(key)
		if script:
			# Use instantiate() for GDScript classes in Godot 4
			var inst = null
			if script.has_method("instantiate"):
				inst = script.instantiate()
			elif script is PackedScene:
				inst = script.instantiate()
			else:
				# Fallback for older API
				inst = script.new()
			executors[key] = inst

	# Additional alias mappings
	executors["screen_shake"] = executors.get("camera_impulse")

	print("[EffectResolver] Registered %d executors" % executors.size())

## Connect to all EventBus signals
func _connect_event_signals():
	if not event_bus:
		return

	event_bus.level_loaded.connect(_on_event.bind("level_loaded"))
	event_bus.level_start.connect(_on_event.bind("level_start"))
	event_bus.level_complete.connect(_on_event.bind("level_complete"))
	event_bus.level_failed.connect(_on_event.bind("level_failed"))
	event_bus.tile_spawned.connect(_on_event_with_entity.bind("tile_spawned"))
	event_bus.tile_matched.connect(_on_event_with_entity.bind("tile_matched"))
	event_bus.tile_destroyed.connect(_on_event_with_entity.bind("tile_destroyed"))
	event_bus.match_cleared.connect(_on_match_cleared)
	event_bus.special_tile_activated.connect(_on_event_with_entity.bind("special_tile_activated"))
	event_bus.spreader_tick.connect(_on_event_with_entity.bind("spreader_tick"))
	event_bus.spreader_destroyed.connect(_on_event_with_entity.bind("spreader_destroyed"))
	event_bus.custom_event.connect(_on_custom_event)

	print("[EffectResolver] Connected to EventBus signals")

## Load effect definitions from chapter JSON
func load_effects(chapter_data: Dictionary) -> bool:
	print("[EffectResolver] Loading effects for chapter: ", chapter_data.get("chapter_id", "unknown"))

	# Validate chapter version compatibility
	var required_version = chapter_data.get("requires_engine_version", "1.0.0")
	if not _is_version_compatible(required_version):
		push_warning("[EffectResolver] Chapter requires engine version %s - skipping" % required_version)
		return false

	current_chapter = chapter_data
	active_effects = chapter_data.get("effects", [])

	print("[EffectResolver] Loaded %d effect bindings" % active_effects.size())

	# Debug: Print all loaded effects
	for i in range(active_effects.size()):
		var effect = active_effects[i]
		print("[EffectResolver]   Effect %d: on='%s', effect='%s'" % [i, effect.get("on", ""), effect.get("effect", "")])

	return true

## Load effects from JSON file path (supports both res:// and user:// for DLC)
func load_effects_from_file(path: String) -> bool:
	print("[EffectResolver] Loading effects from: ", path)

	# Check if file exists (works for both res:// and user://)
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		push_warning("[EffectResolver] Effect file not found: %s" % path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_warning("[EffectResolver] Failed to open effect file: %s" % path)
		return false

	var json_text = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_text)
	if error != OK:
		push_warning("[EffectResolver] Failed to parse JSON: %s (Error: %s)" % [path, json.get_error_message()])
		return false

	return load_effects(json.data)

## Load DLC chapter from installed chapter ID
func load_dlc_chapter(chapter_id: String) -> bool:
	print("[EffectResolver] Loading DLC chapter: ", chapter_id)

	# Check if chapter is installed
	if not AssetRegistry.is_chapter_installed(chapter_id):
		push_warning("[EffectResolver] DLC chapter not installed: %s" % chapter_id)
		return false

	# Get chapter info
	var chapter_info = AssetRegistry.get_chapter_info(chapter_id)
	var chapter_path = AssetRegistry.DLC_BASE_DIR + chapter_id + "/manifest.json"

	# Load effects from manifest
	if load_effects_from_file(chapter_path):
		# Also load assets into AssetRegistry
		AssetRegistry.load_chapter_assets(current_chapter)
		print("[EffectResolver] Successfully loaded DLC chapter: ", chapter_id)
		return true

	return false

## Clear active effects
func clear_effects():
	active_effects.clear()
	current_chapter.clear()
	print("[EffectResolver] Cleared active effects")

## Clean up all visual overlays (call when switching levels)
func cleanup_visual_overlays():
	if not cached_viewport:
		return

	print("[EffectResolver] Cleaning up visual overlays...")

	var overlay_names = [
		"BackgroundDimOverlay",
		"ForegroundDimOverlay",
		"BackgroundTintOverlay",
		"VignetteOverlay",
		"ProgressiveBrightnessOverlay",
		"ScreenFlash"
	]

	for overlay_name in overlay_names:
		var overlay = cached_viewport.get_node_or_null(overlay_name)
		if overlay and is_instance_valid(overlay):
			print("[EffectResolver] Removing overlay: %s" % overlay_name)
			overlay.queue_free()

	print("[EffectResolver] ✓ Visual overlays cleaned up")

## Generic event handler (level events)
func _on_event(level_id: String, context: Dictionary, event_name: String):
	print("[EffectResolver] _on_event called: event=%s, level_id=%s" % [event_name, level_id])
	print("[EffectResolver] Context: ", context)

	# Process the event (cleanup is handled by GameUI before loading effects)
	_process_event(event_name, "", context)

## Event handler for match_cleared (special case - has match_size instead of entity_id)
func _on_match_cleared(match_size: int, context: Dictionary):
	context["match_size"] = match_size
	_process_event("match_cleared", "", context)

## Event handler with entity ID
func _on_event_with_entity(entity_id: String, context: Dictionary, event_name: String):
	_process_event(event_name, entity_id, context)

## Custom event handler
func _on_custom_event(event_name: String, entity_id: String, context: Dictionary):
	_process_event(event_name, entity_id, context)

## Process an event and trigger matching effects
func _process_event(event_name: String, entity_id: String, context: Dictionary):
	print("[EffectResolver] Processing event: %s (entity: %s)" % [event_name, entity_id])
	print("[EffectResolver] Active effects count: %d" % active_effects.size())

	var matched_count = 0
	for i in range(active_effects.size()):
		var binding = active_effects[i]
		var binding_event = binding.get("on", "")
		print("[EffectResolver] Checking effect %d: on='%s' vs event='%s'" % [i, binding_event, event_name])

		if binding_event == event_name:
			var condition = binding.get("condition", {})
			if condition.has("level"):
				var required_level = condition.get("level")
				var current_level = context.get("level", 0)
				if current_level == 0 and GameManager:
					current_level = GameManager.level if "level" in GameManager else 0

				print("[EffectResolver] Level condition check: current=%d, required=%d" % [current_level, required_level])
				if current_level != required_level:
					print("[EffectResolver] ✗ Level mismatch - skipping")
					continue
				print("[EffectResolver] ✓ Level condition matched!")

			matched_count += 1
			print("[EffectResolver] ✓ MATCH! Calling _execute_effect for effect %d" % i)
			_execute_effect(binding, entity_id, context)
		else:
			print("[EffectResolver] ✗ No match (skipping)")

	print("[EffectResolver] Matched %d effects for event '%s'" % [matched_count, event_name])

	# Diagnostic fallback: if no effects matched for match_cleared, trigger a debug camera_impulse
	if matched_count == 0 and event_name == "match_cleared":
		print("[EffectResolver] ⚠️ No effects matched for match_cleared — invoking debug camera_impulse to verify executor")
		_execute_effect({"effect": "camera_impulse", "params": {"strength": 0.8, "duration": 0.25}}, "", context)

## Execute a single effect binding
func _execute_effect(binding: Dictionary, entity_id: String, context: Dictionary):
	var effect_type = binding.get("effect", "")

	if effect_type.is_empty():
		push_warning("[EffectResolver] Effect binding missing 'effect' type")
		return

	var executor = executors.get(effect_type)
	if not executor:
		push_warning("[EffectResolver] No executor registered for effect: %s" % effect_type)
		return

	var exec_context = {
		"binding": binding,
		"entity_id": entity_id,
		"event_context": context,
		"anchor": binding.get("anchor", ""),
		"target": binding.get("target", ""),
		"params": binding.get("params", {}),
		"viewport": cached_viewport,
		"chapter": current_chapter
	}

	# Resolve a reliable viewport/root to pass to executors (avoid stale cached_viewport)
	var resolved_viewport = null
	if has_method("get_tree") and get_tree() != null:
		var tree = get_tree()
		# Prefer the current scene (more likely to be a Node that supports find_node)
		var cs = tree.get_current_scene()
		if cs != null:
			resolved_viewport = cs
		# Fallback to the SceneTree root (Window) which contains the scene
		if resolved_viewport == null and tree.get_root() != null:
			resolved_viewport = tree.get_root()
		# Fallback to the current scene if available (redundant but safe)
		if resolved_viewport == null:
			cs = tree.get_current_scene()
			if cs != null:
				resolved_viewport = cs
	# Use cached_viewport as last resort
	if resolved_viewport == null:
		resolved_viewport = cached_viewport

	exec_context.viewport = resolved_viewport

	# Attempt to resolve GameBoard node under resolved_viewport and pass it to executors
	var board_node: Node = null
	if resolved_viewport != null:
		# Prefer a direct find_node if available
		if resolved_viewport.has_method("find_node"):
			board_node = resolved_viewport.find_node("GameBoard", true, false)
		# Fallback: search children iteratively to avoid nested function definitions
		if board_node == null and resolved_viewport.has_method("get_child_count"):
			var stack = [resolved_viewport]
			while stack.size() > 0 and board_node == null:
				var rn = stack.pop_back()
				for i in range(rn.get_child_count()):
					var c = rn.get_child(i)
					if not c:
						continue
					if str(c.name) == "GameBoard":
						board_node = c
						break
					stack.append(c)

	# Last resort: absolute path
	if not board_node:
		board_node = get_node_or_null("/root/MainGame/GameBoard")

	exec_context.board = board_node

	var vp_status = "NULL"
	if resolved_viewport != null:
		vp_status = "present"
	var board_name_str = board_node.name if board_node != null else "NULL"

	print("[EffectResolver] Executing effect: %s (anchor: %s, viewport: %s, board: %s)" % [effect_type, exec_context.anchor, vp_status, board_name_str])
	print("[EffectResolver] Chapter data: has_assets=%s, chapter_id=%s" % [current_chapter.has("assets") if current_chapter else false, current_chapter.get("chapter_id", "none") if current_chapter else "null"])

	executor.execute(exec_context)

## Check if required version is compatible
func _is_version_compatible(required: String) -> bool:
	return true

func _dev_emit_level_loaded() -> void:
	if event_bus:
		print("[EffectResolver] DEV_FLAG: Emitting level_loaded for testing (level_4)")
		event_bus.emit_level_loaded("level_4", {"level": 4, "target": 4960})
	else:
		print("[EffectResolver] DEV_FLAG: Cannot emit level_loaded - EventBus missing")
