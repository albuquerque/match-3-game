extends Control

## NarrativeStageRenderer
## Handles visual rendering of narrative stage states
## Manages sprites, animations, particles, and transitions

var current_visual: Node = null
var anchor_name: String = "top_banner"
var asset_cache: Dictionary = {}

# Animation settings
var transition_duration: float = 0.5
var fade_in_duration: float = 0.3
var fade_out_duration: float = 0.3

func _ready():
	print("[NarrativeStageRenderer] Ready")

	# Set up as fullscreen control for anchoring
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func render_state(state_data: Dictionary):
	"""Render a narrative stage state"""
	print("[NarrativeStageRenderer] Rendering state: ", state_data.get("name", "unknown"))

	# Get asset path
	var asset_path = state_data.get("asset", "")
	if asset_path == "":
		print("[NarrativeStageRenderer] No asset specified for state")
		clear()
		return

	# Check if this is a DLC asset (format: "chapter_id:asset_name")
	var texture = _load_asset(asset_path)
	if not texture:
		print("[NarrativeStageRenderer] Failed to load asset: ", asset_path)
		return

	# Create or update visual element
	_display_texture(texture, state_data)

func clear():
	"""Clear current visual"""
	print("[NarrativeStageRenderer] Clearing visuals")

	if current_visual:
		# Fade out and remove
		var tween = create_tween()
		tween.tween_property(current_visual, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func():
			if current_visual and is_instance_valid(current_visual):
				current_visual.queue_free()
			current_visual = null
		)

func set_visual_anchor(anchor: String):
	"""Set which visual anchor to use"""
	anchor_name = anchor
	print("[NarrativeStageRenderer] Anchor set to: ", anchor_name)

func _load_asset(asset_path: String) -> Texture2D:
	"""Load texture from bundled or DLC source"""
	# Check cache first
	if asset_cache.has(asset_path):
		return asset_cache[asset_path]

	var texture: Texture2D = null

	# Check if it's a DLC asset (format: "chapter_id:asset_name")
	if asset_path.contains(":"):
		texture = _load_dlc_asset(asset_path)
	else:
		# Bundled asset
		texture = _load_bundled_asset(asset_path)

	# Cache if loaded successfully
	if texture:
		asset_cache[asset_path] = texture

	return texture

func _load_dlc_asset(asset_id: String) -> Texture2D:
	"""Load asset from DLC via AssetRegistry"""
	var parts = asset_id.split(":")
	if parts.size() != 2:
		print("[NarrativeStageRenderer] Invalid DLC asset ID: ", asset_id)
		return null

	var chapter_id = parts[0]
	var asset_name = parts[1]

	# Try AssetRegistry first
	var asset_registry = get_node_or_null("/root/AssetRegistry")
	if asset_registry and asset_registry.has_method("get_texture"):
		var texture = asset_registry.get_texture(chapter_id, asset_name)
		if texture:
			print("[NarrativeStageRenderer] Loaded DLC asset: ", asset_id)
			return texture

	# Fallback: try direct path
	var dlc_path = "user://dlc/chapters/%s/assets/%s" % [chapter_id, asset_name]
	if FileAccess.file_exists(dlc_path):
		var image = Image.new()
		var error = image.load(dlc_path)
		if error == OK:
			var texture = ImageTexture.create_from_image(image)
			print("[NarrativeStageRenderer] Loaded DLC asset from path: ", dlc_path)
			return texture

	print("[NarrativeStageRenderer] DLC asset not found: ", asset_id)
	return null

func _load_bundled_asset(asset_path: String) -> Texture2D:
	"""Load bundled asset from res://"""
	# Add res:// prefix if not present
	if not asset_path.begins_with("res://"):
		asset_path = "res://textures/narrative/" + asset_path

	if ResourceLoader.exists(asset_path):
		var texture = load(asset_path) as Texture2D
		if texture:
			print("[NarrativeStageRenderer] Loaded bundled asset: ", asset_path)
			return texture

	print("[NarrativeStageRenderer] Bundled asset not found: ", asset_path)
	return null

func _display_texture(texture: Texture2D, state_data: Dictionary):
	"""Display texture in the narrative stage area"""
	# Get anchor position
	var anchor_node = _get_anchor_node()
	if not anchor_node:
		print("[NarrativeStageRenderer] Anchor not found: ", anchor_name)
		anchor_node = self  # Fallback to self

	# Fade out old visual if exists
	if current_visual:
		var old_visual = current_visual
		var tween = create_tween()
		tween.tween_property(old_visual, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func():
			if old_visual and is_instance_valid(old_visual):
				old_visual.queue_free()
		)

	# Create new TextureRect
	var tex_rect = TextureRect.new()
	tex_rect.name = "NarrativeVisual"
	tex_rect.texture = texture

	# Configure based on anchor or state data
	var position_mode = state_data.get("position", "top_banner")
	_configure_texture_rect(tex_rect, position_mode)

	# Add to scene
	anchor_node.add_child(tex_rect)
	current_visual = tex_rect

	# Fade in
	tex_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(tex_rect, "modulate:a", 1.0, fade_in_duration)

	print("[NarrativeStageRenderer] Displayed texture")

func _configure_texture_rect(tex_rect: TextureRect, position_mode: String):
	"""Configure TextureRect based on position mode"""
	match position_mode:
		"top_banner":
			# Full area from top of screen to top of board (HUD overlays on top)
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0  # Start at very top
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 0.25  # Extend to ~25% (fills to board)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Centered, shows full image
			tex_rect.z_index = -10  # Behind HUD, can hide HUD with effects if needed

		"left_panel":
			# Panel on left side
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0.2
			tex_rect.anchor_right = 0
			tex_rect.anchor_bottom = 0.8
			tex_rect.offset_right = 300  # Width
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

		"right_panel":
			# Panel on right side
			tex_rect.anchor_left = 1
			tex_rect.anchor_top = 0.2
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 0.8
			tex_rect.offset_left = -300  # Width (negative for right alignment)
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT

		"background_overlay":
			# Full screen overlay
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 1
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.z_index = -50  # Behind UI

		"foreground_character":
			# Character in foreground
			tex_rect.anchor_left = 0.5
			tex_rect.anchor_top = 0.5
			tex_rect.anchor_right = 0.5
			tex_rect.anchor_bottom = 0.5
			tex_rect.offset_left = -200
			tex_rect.offset_top = -300
			tex_rect.offset_right = 200
			tex_rect.offset_bottom = 300
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
			tex_rect.z_index = 50  # In front of UI

		_:
			# Default: top banner
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 0
			tex_rect.offset_bottom = 200
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

func _get_anchor_node() -> Node:
	"""Get the visual anchor node from VisualAnchorManager"""
	var anchor_manager = get_node_or_null("/root/VisualAnchorManager")
	if anchor_manager and anchor_manager.has_method("get_anchor"):
		var anchor_node = anchor_manager.get_anchor(anchor_name)
		if anchor_node:
			return anchor_node

	# Fallback to self if anchor not found
	return self

func preload_assets(stage_data: Dictionary):
	"""Preload all assets for a stage to improve performance"""
	if not stage_data.has("states"):
		return

	print("[NarrativeStageRenderer] Preloading assets...")
	var preload_count = 0

	for state in stage_data["states"]:
		if state.has("asset"):
			var asset_path = state["asset"]
			if not asset_cache.has(asset_path):
				var texture = _load_asset(asset_path)
				if texture:
					preload_count += 1

	print("[NarrativeStageRenderer] Preloaded ", preload_count, " assets")

func clear_cache():
	"""Clear asset cache to free memory"""
	asset_cache.clear()
	print("[NarrativeStageRenderer] Asset cache cleared")
