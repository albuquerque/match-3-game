extends Node
class_name EffectExecutorScreenOverlay

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		print("[ScreenOverlayExecutor] No viewport - skipping")
		return

	var texture_id = params.get("texture", "")
	var fade_in = float(params.get("fade_in", 0.4))
	var hold = float(params.get("hold", 0.6))
	var fade_out = float(params.get("fade_out", 0.6))
	var intensity = float(params.get("intensity", 1.0))
	var anchor = context.get("anchor", "fullscreen_overlay")
	var scale_mode = params.get("scale", "cover")
	var tint = params.get("tint", "")
	var chapter = context.get("chapter", null)

	print("[ScreenOverlayExecutor] Showing overlay '%s' anchor=%s fade_in=%s hold=%s fade_out=%s" % [texture_id, anchor, fade_in, hold, fade_out])

	var tex_res = null
	if chapter and chapter.has("assets"):
		var assets = chapter.get("assets", {})
		if typeof(assets) == TYPE_DICTIONARY and assets.has("textures"):
			var texmap = assets.get("textures", {})
			if texmap.has(texture_id):
				var path = texmap.get(texture_id)
				print("[ScreenOverlayExecutor] Found texture path: %s" % path)
				if path:
					# Check if file exists using FileAccess (works for SVG and other files)
					if FileAccess.file_exists(path):
						tex_res = load(path)
						print("[ScreenOverlayExecutor] Loaded texture: %s (type: %s)" % [path, tex_res.get_class() if tex_res else "null"])
					else:
						print("[ScreenOverlayExecutor] Texture file not found: %s" % path)

	if not tex_res and typeof(texture_id) == TYPE_STRING and texture_id.begins_with("res://"):
		print("[ScreenOverlayExecutor] Trying direct path: %s" % texture_id)
		if FileAccess.file_exists(texture_id):
			tex_res = load(texture_id)
			print("[ScreenOverlayExecutor] Loaded texture from direct path: %s" % texture_id)

	var overlay_node: Control = null
	var z_idx = 999

	match anchor:
		"background":
			z_idx = -90
		"fullscreen_overlay":
			z_idx = 999
		"foreground":
			z_idx = 200
		_:
			z_idx = 999

	# If we have a texture, use TextureRect
	if tex_res and tex_res is Texture:
		var tex_rect = TextureRect.new()
		tex_rect.name = "ScreenOverlay_%d" % Time.get_unix_time_from_system()
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tex_rect.anchor_left = 0
		tex_rect.anchor_top = 0
		tex_rect.anchor_right = 1
		tex_rect.anchor_bottom = 1
		tex_rect.z_index = z_idx
		tex_rect.texture = tex_res

		if scale_mode == "cover":
			tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
		elif scale_mode == "contain":
			tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		else:
			tex_rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE

		overlay_node = tex_rect
	else:
		# If no texture, use ColorRect for tint
		var color_rect = ColorRect.new()
		color_rect.name = "ScreenOverlay_%d" % Time.get_unix_time_from_system()
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		color_rect.anchor_left = 0
		color_rect.anchor_top = 0
		color_rect.anchor_right = 1
		color_rect.anchor_bottom = 1
		color_rect.z_index = z_idx

		var c = Color(1,1,1,1)
		if tint != "":
			if typeof(tint) == TYPE_STRING and tint.begins_with("#"):
				c = Color(tint)
			else:
				match tint:
					"gold":
						c = Color(1.0, 0.9, 0.3, 1.0)
					"red":
						c = Color(1.0, 0.2, 0.2, 1.0)
					"green":
						c = Color(0.2, 1.0, 0.3, 1.0)
					_:
						c = Color(1, 1, 1, 1)
		color_rect.color = c
		overlay_node = color_rect

	# Add to viewport
	if overlay_node:
		viewport.add_child(overlay_node)

		# Start invisible
		overlay_node.modulate = Color(1, 1, 1, 0)
		var target_alpha = clamp(intensity, 0.0, 1.0)

		# Create tween to fade in, hold, and fade out
		var tween = viewport.create_tween()
		tween.tween_property(overlay_node, "modulate:a", target_alpha, fade_in)
		if hold > 0:
			tween.tween_interval(hold)
		if fade_out > 0:
			tween.tween_property(overlay_node, "modulate:a", 0.0, fade_out)
			tween.tween_callback(Callable(overlay_node, "queue_free"))
		else:
			print("[ScreenOverlayExecutor] Overlay set to persistent (no fade_out)")

		print("[ScreenOverlayExecutor] Overlay started: %s" % overlay_node.name)
	else:
		print("[ScreenOverlayExecutor] ERROR: Failed to create overlay node")

	return
