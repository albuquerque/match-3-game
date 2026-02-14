extends Control
class_name NarrativeStageRenderer

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

var override_parent: Node = null

func _ready():
	print("[NarrativeStageRenderer] === RENDERER READY ===")
	print("[NarrativeStageRenderer] Parent: ", get_parent().name if get_parent() else "NO PARENT")
	print("[NarrativeStageRenderer] Path: ", get_path())
	print("[NarrativeStageRenderer] Position: ", position)
	print("[NarrativeStageRenderer] Size: ", size)
	print("[NarrativeStageRenderer] Anchors: L=", anchor_left, " T=", anchor_top, " R=", anchor_right, " B=", anchor_bottom)

	# Diagnostics: print whether key methods exist on this instance
	print("[NarrativeStageRenderer] has_method('render_state'): ", has_method("render_state"))
	print("[NarrativeStageRenderer] has_method('_load_asset'): ", has_method("_load_asset"))
	print("[NarrativeStageRenderer] has_method('_display_texture'): ", has_method("_display_texture"))

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
	var text_content = state_data.get("text", "")

	# If there's no asset but there is text/content, render a text-only state
	if asset_path == "" and text_content != "":
		print("[NarrativeStageRenderer] Text-only state detected")

		# Clear any existing visuals
		clear()

		# Determine anchor/parent node
		# Prefer explicit state position if provided, otherwise fall back to renderer anchor_name, then default to top_banner
		var position_mode = state_data.get("position", "").strip_edges()
		if position_mode == "":
			position_mode = anchor_name if anchor_name != "" else state_data.get("position", "top_banner")

		var anchor_node = self
		# Prefer override_parent (set by ShowNarrativeStep) for all modes if present so pipeline overlay captures visuals
		if override_parent and override_parent.is_inside_tree():
			anchor_node = override_parent
		else:
			# if not overriding parent, and not fullscreen, try anchor manager
			if position_mode != "fullscreen":
				var candidate_anchor = _get_anchor_node()
				if candidate_anchor and candidate_anchor.is_inside_tree():
					anchor_node = candidate_anchor
				else:
					anchor_node = self

		# If anchor_node appears to be 'self' (or not in tree), try to find any NarrativeContainer created by pipeline
		if (anchor_node == self or not anchor_node.is_inside_tree()):
			var rt = get_tree()
			if rt:
				var root = rt.root
				var pipeline_container = _find_node_recursive(root, "NarrativeContainer")
				if pipeline_container:
					anchor_node = pipeline_container
					print("[NarrativeStageRenderer] Using pipeline NarrativeContainer as anchor: ", anchor_node.get_path())

		# Create a background ColorRect (use background_color if provided)
		var bg_color_str = state_data.get("background_color", "#000000")
		var bg_col = _color_from_hex(bg_color_str)
		var bg = ColorRect.new()
		bg.name = "NarrativeBackground"
		# Fullscreen or banner sizing handled similarly to texture configuration
		match position_mode:
			"fullscreen":
				bg.anchor_left = 0
				bg.anchor_top = 0
				bg.anchor_right = 1
				bg.anchor_bottom = 1
				# No rect_min_size on ColorRect in Godot 4; anchors suffice
				bg.z_index = 99
			"top_banner":
				bg.anchor_left = 0
				bg.anchor_top = 0
				bg.anchor_right = 1
				bg.anchor_bottom = 0.25
				bg.z_index = -5
			_:
				bg.anchor_left = 0
				bg.anchor_top = 0
				bg.anchor_right = 1
				bg.anchor_bottom = 1

		bg.color = bg_col
		anchor_node.add_child(bg)
		current_visual = bg

		# Add the text overlay (pass text_color if provided)
		var text_color = state_data.get("text_color", "#FFFFFF")
		_add_text_overlay(text_content, position_mode, anchor_node, text_color)

		print("[NarrativeStageRenderer] ✓ Rendered text-only state: ", state_data.get("name", "unknown"))
		return

	# Check if this is a DLC asset (format: "chapter_id:asset_name")
	var texture = _load_asset(asset_path) if asset_path != "" else null
	if asset_path != "" and not texture:
		print("[NarrativeStageRenderer] Failed to load asset: ", asset_path)
		return

	# If we have a texture, display it
	if texture:
		# Create or update visual element
		_display_texture(texture, state_data)
		return

	# No asset and no text -> clear visuals and warn
	print("[NarrativeStageRenderer] No asset specified for state")
	clear()
	return

func clear():
	"""Clear current visual"""
	print("[NarrativeStageRenderer] Clearing visuals")

	if current_visual:
		# Fade out and remove
		var visual_to_remove = current_visual
		current_visual = null
		var tween = create_tween()
		tween.tween_property(visual_to_remove, "modulate:a", 0.0, fade_out_duration)
		# Use callable to queue_free safely
		var _v = visual_to_remove
		tween.tween_callback(Callable(_v, "queue_free"))

	if current_text_label:
		# Fade out and remove text label
		var label_to_remove = current_text_label
		current_text_label = null
		var tween2 = create_tween()
		tween2.tween_property(label_to_remove, "modulate:a", 0.0, fade_out_duration)
		var _l = label_to_remove
		tween2.tween_callback(Callable(_l, "queue_free"))

func set_visual_anchor(anchor: String):
	"""Set which visual anchor to use"""
	anchor_name = anchor
	print("[NarrativeStageRenderer] Anchor set to: ", anchor_name)

func set_render_container(node: Node) -> void:
	"""Set an explicit parent/container to render visuals into (overrides anchor manager)."""
	override_parent = node
	print("[NarrativeStageRenderer] render container override set: ", node.get_path() if node else "null")

func clear_render_container() -> void:
	override_parent = null
	print("[NarrativeStageRenderer] render container override cleared")

func _get_anchor_node() -> Node:
	"""Get the visual anchor node from VisualAnchorManager"""
	# If an override parent is set (for pipeline-driven overlay), use it first
	if override_parent and override_parent.is_inside_tree():
		return override_parent

	var anchor_manager = get_node_or_null("/root/VisualAnchorManager")
	if anchor_manager and anchor_manager.has_method("get_anchor"):
		var anchor_node = anchor_manager.get_anchor(anchor_name)
		if anchor_node:
			return anchor_node

	# Fallback to self if anchor not found
	return self

# Recursive search helper because Node.find_node may not be available
func _find_node_recursive(start_node: Node, target_name: String) -> Node:
	if not start_node:
		return null
	for child in start_node.get_children():
		if typeof(child) == TYPE_OBJECT and child is Node:
			if child.name == target_name:
				return child
			var found = _find_node_recursive(child, target_name)
			if found:
				return found
	return null

# Simple hex color parser (#RRGGBB or #RRGGBBAA)
func _color_from_hex(hex_str: String) -> Color:
	if not hex_str or hex_str == "":
		return Color(0,0,0,1)
	var s = hex_str.strip_edges()
	if s.begins_with("#"):
		s = s.substr(1, s.length() - 1)
	# expect RRGGBB or RRGGBBAA
	if s.length() == 6:
		var r = int("0x" + s.substr(0,2))
		var g = int("0x" + s.substr(2,2))
		var b = int("0x" + s.substr(4,2))
		return Color(r/255.0, g/255.0, b/255.0, 1.0)
	elif s.length() == 8:
		var r2 = int("0x" + s.substr(0,2))
		var g2 = int("0x" + s.substr(2,2))
		var b2 = int("0x" + s.substr(4,2))
		var a2 = int("0x" + s.substr(6,2))
		return Color(r2/255.0, g2/255.0, b2/255.0, a2/255.0)
	# fallback
	return Color(0,0,0,1)

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

func _add_text_overlay(text_content: String, position_mode: String, parent_node: Node, text_color: String = "#FFFFFF"):
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

	# Parse requested color
	var parsed_color = _color_from_hex(text_color)
	# Compute a contrasting outline color (black for light text, white for dark text)
	var luminance = parsed_color.r * 0.299 + parsed_color.g * 0.587 + parsed_color.b * 0.114
	var outline_col = Color(0,0,0,1) if luminance > 0.5 else Color(1,1,1,1)

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
			label.add_theme_color_override("font_color", parsed_color)
			label.add_theme_color_override("font_outline_color", outline_col)
			label.add_theme_constant_override("outline_size", 8)
			label.z_index = 101  # Above the image

			# Try to apply Bangers font
			var theme_manager = get_node_or_null("/root/ThemeManager")
			if theme_manager and theme_manager.has_method("apply_bangers_font"):
				theme_manager.apply_bangers_font(label, 32)

			print("[NarrativeStageRenderer] ✓ Configured fullscreen text")

		"top_banner":
			# Full area from top of screen to top of board (HUD overlays on top)
			label.anchor_left = 0
			label.anchor_top = 0
			label.anchor_right = 1
			label.anchor_bottom = 1
			label.offset_left = 20
			label.offset_top = 20
			label.offset_right = -20
			label.offset_bottom = -20
			label.add_theme_font_size_override("font_size", 24)
			label.add_theme_color_override("font_color", parsed_color)
			label.add_theme_color_override("font_outline_color", outline_col)
			label.add_theme_constant_override("outline_size", 4)
			# If parent is override_parent (overlay), place text above dimmer
			if parent_node == override_parent:
				label.z_index = 101
			else:
				label.z_index = 1

			print("[NarrativeStageRenderer] ✓ Configured banner text")

		_:
			# Default configuration
			label.anchor_left = 0
			label.anchor_top = 0
			label.anchor_right = 1
			label.anchor_bottom = 1
			label.offset_left = 40
			label.offset_top = 40
			label.offset_right = -40
			label.offset_bottom = -40
			label.add_theme_font_size_override("font_size", 20)
			label.add_theme_color_override("font_color", parsed_color)

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

func _load_asset(asset_path: String) -> Texture2D:
	"""Load texture from bundled or DLC source (cache-aware wrapper)."""
	if asset_path == null or asset_path == "":
		return null

	# Return from cache if available
	if asset_cache.has(asset_path):
		return asset_cache[asset_path]

	var texture: Texture2D = null
	if asset_path.contains(":") and not asset_path.begins_with("res://"):
		texture = _load_dlc_asset(asset_path)
	else:
		texture = _load_bundled_asset(asset_path)

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
	# If it's already a full res:// path, try it directly
	if asset_path.begins_with("res://"):
		if ResourceLoader.exists(asset_path):
			var texture = load(asset_path) as Texture2D
			if texture:
				print("[NarrativeStageRenderer] Loaded bundled asset (explicit): ", asset_path)
				return texture

	# Try several likely data image locations and legacy texture locations
	var paths_to_try = [
		"res://data/images/%s" % asset_path,
		"res://data/images/narrative/%s" % asset_path,
		"res://data/images/overlays/%s" % asset_path,
		"res://data/images/dialogue/%s" % asset_path,
		"res://textures/narrative/%s" % asset_path,
		"res://textures/%s" % asset_path
	]

	for p in paths_to_try:
		if ResourceLoader.exists(p):
			var tex = load(p) as Texture2D
			if tex:
				print("[NarrativeStageRenderer] Loaded bundled asset: ", p)
				return tex

	print("[NarrativeStageRenderer] Bundled asset not found: ", asset_path)
	return null

func display_asset(asset_path: String, position_mode: String = "") -> bool:
	"""Public API: load the given asset and render it into the renderer using the provided position mode.
	This is safe for external callers and wraps the internal load+display logic.
	Returns true if asset was loaded and a visual was created, false otherwise.
	"""
	if asset_path == null or asset_path == "":
		return false
	var tex = _load_asset(asset_path)
	if not tex:
		print("[NarrativeStageRenderer] display_asset: failed to load asset: ", asset_path)
		return false
	var state = {"asset": asset_path}
	if position_mode and position_mode != "":
		state["position"] = position_mode
	# Use internal display path so existing layout/config is applied
	_display_texture(tex, state)
	return true

func _display_texture(texture: Texture2D, state_data: Dictionary):
	"""Display texture in the narrative stage area"""
	print("[NarrativeStageRenderer] === DISPLAYING TEXTURE ===")

	# Configure based on anchor name (set via set_visual_anchor from narrative stage JSON)
	# Fall back to state data position, then default to top_banner
	var position_mode = state_data.get("position", "").strip_edges()
	if position_mode == "":
		position_mode = anchor_name if anchor_name != "" else "top_banner"
	print("[NarrativeStageRenderer] 📍 Position mode: ", position_mode)
	print("[NarrativeStageRenderer] 📍 anchor_name variable: ", anchor_name)
	print("[NarrativeStageRenderer] 📍 Renderer parent: ", get_parent().name if get_parent() else "NO PARENT")
	print("[NarrativeStageRenderer] 📍 Renderer path: ", get_path())

	# For fullscreen mode, add directly to this Control (which is fullscreen)
	# For other modes, use the visual anchor system
	var anchor_node = self
	var rendering_into_overlay: bool = false
	# Prefer explicit override_parent (set by ShowNarrativeStep) if present
	if override_parent and override_parent.is_inside_tree():
		anchor_node = override_parent
		rendering_into_overlay = true
	else:
		if position_mode != "fullscreen":
			var candidate = _get_anchor_node()
			if candidate and candidate.is_inside_tree():
				anchor_node = candidate
			else:
				anchor_node = self

	# Fade out old visual if exists
	if current_visual:
		var old_visual = current_visual
		var tween = create_tween()
		tween.tween_property(old_visual, "modulate:a", 0.0, fade_out_duration)
		var _old = old_visual
		tween.tween_callback(Callable(_old, "queue_free"))

	# Create new TextureRect
	var tex_rect = TextureRect.new()
	tex_rect.name = "NarrativeVisual"
	tex_rect.texture = texture

	_configure_texture_rect(tex_rect, position_mode)
	# If rendering into the pipeline overlay, ensure the visual is above the dimmer
	if rendering_into_overlay:
		if tex_rect.z_index <= 0:
			tex_rect.z_index = 100
			print("[NarrativeStageRenderer] Adjusted tex_rect z_index for overlay rendering to:", tex_rect.z_index)

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
	var tween_in = create_tween()
	tween_in.tween_property(tex_rect, "modulate:a", 1.0, fade_in_duration)

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
