extends Control

## NarrativeStageRenderer
## Handles visual rendering of narrative stage states
## Manages sprites, animations, particles, and transitions

var current_visual: Node = null
var current_text_label: Label = null  # Text overlay for narratives
var anchor_name: String = "top_banner"
var asset_cache: Dictionary = {}

# Animation settings
var transition_duration: float = 0.5
var fade_in_duration: float = 0.3
var fade_out_duration: float = 0.3

func _ready():
	print("[NarrativeStageRenderer] === RENDERER READY ===")
	print("[NarrativeStageRenderer] Parent: ", get_parent().name if get_parent() else "NO PARENT")
	print("[NarrativeStageRenderer] Path: ", get_path())
	print("[NarrativeStageRenderer] Position: ", position)
	print("[NarrativeStageRenderer] Size: ", size)
	print("[NarrativeStageRenderer] Anchors: L=", anchor_left, " T=", anchor_top, " R=", anchor_right, " B=", anchor_bottom)

	# Set up as fullscreen control for anchoring
	anchor_left = 0
	anchor_top = 0
	anchor_right = 1
	anchor_bottom = 1
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	print("[NarrativeStageRenderer] ✓ Configured as fullscreen (anchors set to 0,0,1,1)")
	print("[NarrativeStageRenderer] === RENDERER READY COMPLETE ===")

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
		var visual_to_remove = current_visual
		current_visual = null
		var tween = create_tween()
		tween.tween_property(visual_to_remove, "modulate:a", 0.0, fade_out_duration)
		tween.tween_callback(func():
			if visual_to_remove and is_instance_valid(visual_to_remove):
				visual_to_remove.queue_free()
		)

	if current_text_label:
		# Fade out and remove text label
		var label_to_remove = current_text_label
		current_text_label = null
		var tween2 = create_tween()
		tween2.tween_property(label_to_remove, "modulate:a", 0.0, fade_out_duration)
		tween2.tween_callback(func():
			if label_to_remove and is_instance_valid(label_to_remove):
				label_to_remove.queue_free()
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
	# But NOT a res:// path (which also contains :)
	if asset_path.contains(":") and not asset_path.begins_with("res://"):
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
	print("[NarrativeStageRenderer] === DISPLAYING TEXTURE ===")

	# Configure based on anchor name (set via set_visual_anchor from narrative stage JSON)
	# Fall back to state data position, then default to top_banner
	var position_mode = anchor_name if anchor_name != "" else state_data.get("position", "top_banner")
	print("[NarrativeStageRenderer] 📍 Position mode: ", position_mode)
	print("[NarrativeStageRenderer] 📍 anchor_name variable: ", anchor_name)
	print("[NarrativeStageRenderer] 📍 Renderer parent: ", get_parent().name if get_parent() else "NO PARENT")
	print("[NarrativeStageRenderer] 📍 Renderer path: ", get_path())

	# For fullscreen mode, add directly to this Control (which is fullscreen)
	# For other modes, use the visual anchor system
	var anchor_node = self
	if position_mode != "fullscreen":
		anchor_node = _get_anchor_node()
		if not anchor_node:
			print("[NarrativeStageRenderer] ⚠️ Anchor not found: ", anchor_name)
			anchor_node = self  # Fallback to self
		else:
			print("[NarrativeStageRenderer] Using anchor node: ", anchor_node.name, " at ", anchor_node.get_path())
	else:
		print("[NarrativeStageRenderer] ✓ Using fullscreen mode - adding to renderer Control (self)")
		print("[NarrativeStageRenderer] ✓ Self size: ", size)
		print("[NarrativeStageRenderer] ✓ Self global position: ", global_position)

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

	_configure_texture_rect(tex_rect, position_mode)

	# Add to scene
	anchor_node.add_child(tex_rect)
	current_visual = tex_rect

	print("[NarrativeStageRenderer] ✓ TextureRect added to: ", anchor_node.name)
	print("[NarrativeStageRenderer] ✓ TextureRect path: ", tex_rect.get_path())
	print("[NarrativeStageRenderer] ✓ TextureRect size: ", tex_rect.size)
	print("[NarrativeStageRenderer] ✓ TextureRect global position: ", tex_rect.global_position)
	print("[NarrativeStageRenderer] ✓ TextureRect anchors: L=", tex_rect.anchor_left, " T=", tex_rect.anchor_top, " R=", tex_rect.anchor_right, " B=", tex_rect.anchor_bottom)
	print("[NarrativeStageRenderer] ✓ TextureRect z_index: ", tex_rect.z_index)

	# Add text overlay if text is provided
	var text_content = state_data.get("text", "")
	if text_content != "":
		_add_text_overlay(text_content, position_mode, anchor_node)

	# Fade in
	tex_rect.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(tex_rect, "modulate:a", 1.0, fade_in_duration)

	print("[NarrativeStageRenderer] === TEXTURE DISPLAY COMPLETE ===")

func _configure_texture_rect(tex_rect: TextureRect, position_mode: String):
	"""Configure TextureRect based on position mode"""
	match position_mode:
		"fullscreen":
			# Full screen cinematic overlay
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 1
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tex_rect.z_index = 100  # Above everything for fullscreen experience
			print("[NarrativeStageRenderer] Configured as FULLSCREEN")

		"top_banner":
			# Full area from top of screen to top of board (HUD overlays on top)
			tex_rect.anchor_left = 0
			tex_rect.anchor_top = 0  # Start at very top
			tex_rect.anchor_right = 1
			tex_rect.anchor_bottom = 0.25  # Extend to ~25% (fills to board)
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED  # Centered, shows full image
			tex_rect.z_index = -5  # Above ALL background effects (brightness overlay is -75), below HUD

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

func _add_text_overlay(text_content: String, position_mode: String, parent_node: Node):
	"""Add text overlay for narrative content"""

	print("[NarrativeStageRenderer] === ADDING TEXT OVERLAY ===")
	print("[NarrativeStageRenderer] Text: ", text_content)
	print("[NarrativeStageRenderer] Position mode: ", position_mode)
	print("[NarrativeStageRenderer] Parent node: ", parent_node.name)

	# Remove old text label if exists
	if current_text_label and is_instance_valid(current_text_label):
		current_text_label.queue_free()
		current_text_label = null

	# Create text label
	var label = Label.new()
	label.name = "NarrativeText"
	label.text = text_content
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Configure based on position mode
	match position_mode:
		"fullscreen":
			# Text at bottom third of screen for fullscreen narratives
			label.anchor_left = 0
			label.anchor_top = 0.7
			label.anchor_right = 1
			label.anchor_bottom = 1
			label.offset_left = 40
			label.offset_top = 0
			label.offset_right = -40
			label.offset_bottom = -40
			label.add_theme_font_size_override("font_size", 32)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 8)
			label.z_index = 101  # Above the image

			# Try to apply Bangers font
			var theme_manager = get_node_or_null("/root/ThemeManager")
			if theme_manager and theme_manager.has_method("apply_bangers_font"):
				theme_manager.apply_bangers_font(label, 32)

			print("[NarrativeStageRenderer] ✓ Configured fullscreen text")
			print("[NarrativeStageRenderer]   Anchors: ", label.anchor_left, ",", label.anchor_top, ",", label.anchor_right, ",", label.anchor_bottom)
			print("[NarrativeStageRenderer]   Offsets: ", label.offset_left, ",", label.offset_top, ",", label.offset_right, ",", label.offset_bottom)

		"top_banner":
			# ...existing code...
			label.anchor_left = 0
			label.anchor_top = 0
			label.anchor_right = 1
			label.anchor_bottom = 1
			label.offset_left = 20
			label.offset_top = 20
			label.offset_right = -20
			label.offset_bottom = -20
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.add_theme_color_override("font_outline_color", Color.BLACK)
			label.add_theme_constant_override("outline_size", 4)
			label.z_index = 1

			print("[NarrativeStageRenderer] ✓ Configured banner text")

		_:
			# ...existing code...
			label.anchor_left = 0
			label.anchor_top = 0
			label.anchor_right = 1
			label.anchor_bottom = 1
			label.offset_left = 40
			label.offset_top = 40
			label.offset_right = -40
			label.offset_bottom = -40
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", Color.WHITE)

	# Add to parent
	parent_node.add_child(label)
	current_text_label = label

	print("[NarrativeStageRenderer] ✓ Label added to: ", parent_node.name)
	print("[NarrativeStageRenderer] ✓ Label path: ", label.get_path())
	print("[NarrativeStageRenderer] ✓ Label size: ", label.size)
	print("[NarrativeStageRenderer] ✓ Label global position: ", label.global_position)
	print("[NarrativeStageRenderer] ✓ Label z_index: ", label.z_index)
	print("[NarrativeStageRenderer] === TEXT OVERLAY COMPLETE ===")

	# Fade in
	label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(label, "modulate:a", 1.0, fade_in_duration)
