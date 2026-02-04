extends Node
class_name EffectExecutorSymbolicOverlay

var active_overlays: Array = []

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)

	var asset_path = params.get("asset", "")
	var blend_mode = params.get("blend", "additive")
	var motion = params.get("motion", "slow_pulse")
	var opacity = params.get("opacity", 0.4)
	var duration = params.get("duration", 4.0)
	var layer = params.get("layer", 150)  # Above board (100), below UI (999)

	print("[SymbolicOverlayExecutor] Creating overlay: asset=%s blend=%s motion=%s" % [asset_path, blend_mode, motion])

	if not viewport:
		push_warning("[SymbolicOverlayExecutor] No viewport in context")
		return

	if asset_path == "":
		push_warning("[SymbolicOverlayExecutor] No asset path provided")
		return

	# Load texture
	var texture = _load_texture(asset_path)
	if not texture:
		push_warning("[SymbolicOverlayExecutor] Failed to load texture: %s" % asset_path)
		return

	# Create overlay sprite
	var overlay = Sprite2D.new()
	overlay.name = "SymbolicOverlay_%d" % Time.get_ticks_msec()
	overlay.texture = texture
	overlay.z_index = layer

	# Set blend mode
	match blend_mode:
		"additive":
			overlay.material = CanvasItemMaterial.new()
			overlay.material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		"multiply":
			overlay.material = CanvasItemMaterial.new()
			overlay.material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
		"screen":
			overlay.material = CanvasItemMaterial.new()
			overlay.material.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
		# "mix" or default uses normal blending

	# Position at center of viewport
	var viewport_size = viewport.get_viewport_rect().size if viewport.has_method("get_viewport_rect") else Vector2(720, 1280)
	overlay.position = viewport_size / 2.0

	# Set initial opacity
	overlay.modulate = Color(1, 1, 1, opacity)

	# Add to viewport
	viewport.add_child(overlay)
	active_overlays.append(overlay)

	# Apply motion animation
	_apply_motion(overlay, motion, duration)

	# Auto-remove after duration
	if duration > 0:
		var tree = viewport.get_tree()
		if tree:
			var timer = tree.create_timer(duration)
			timer.timeout.connect(func(): _remove_overlay(overlay))

func _load_texture(asset_path: String) -> Texture2D:
	print("[SymbolicOverlayExecutor] Attempting to load texture: %s" % asset_path)

	# Try direct load
	if ResourceLoader.exists(asset_path):
		var resource = load(asset_path)
		if resource is Texture2D:
			print("[SymbolicOverlayExecutor] ✓ Loaded texture directly: %s" % asset_path)
			return resource

	# Try common texture paths
	var paths_to_try = [
		asset_path,
		"res://textures/overlays/%s" % asset_path,
		"res://assets/textures/overlays/%s" % asset_path,
		"res://textures/%s" % asset_path
	]

	for path in paths_to_try:
		print("[SymbolicOverlayExecutor] Trying path: %s" % path)
		if ResourceLoader.exists(path):
			var resource = load(path)
			if resource is Texture2D:
				print("[SymbolicOverlayExecutor] ✓ Loaded texture: %s" % path)
				return resource

	print("[SymbolicOverlayExecutor] ✗ Failed to load texture from any path")
	return null

func _apply_motion(overlay: Sprite2D, motion: String, duration: float) -> void:
	if not overlay or not is_instance_valid(overlay):
		return

	var parent = overlay.get_parent()
	if not parent or not parent.has_method("create_tween"):
		return

	match motion:
		"slow_pulse":
			var tween = parent.create_tween()
			tween.set_loops(-1)  # -1 means infinite in Godot 4
			tween.tween_property(overlay, "modulate:a", overlay.modulate.a * 0.6, 2.0)
			tween.tween_property(overlay, "modulate:a", overlay.modulate.a, 2.0)
			overlay.set_meta("animation_tween", tween)

		"fade_in_out":
			var tween = parent.create_tween()
			tween.tween_property(overlay, "modulate:a", overlay.modulate.a, duration * 0.2)
			tween.tween_property(overlay, "modulate:a", overlay.modulate.a, duration * 0.6)
			tween.tween_property(overlay, "modulate:a", 0.0, duration * 0.2)
			overlay.set_meta("animation_tween", tween)

		"float":
			var start_pos = overlay.position
			var tween = parent.create_tween()
			tween.set_loops(-1)  # -1 means infinite in Godot 4
			tween.tween_property(overlay, "position:y", start_pos.y - 20, 3.0)
			tween.tween_property(overlay, "position:y", start_pos.y + 20, 3.0)
			overlay.set_meta("animation_tween", tween)

		"rotate_slow":
			var tween = parent.create_tween()
			tween.set_loops(-1)  # -1 means infinite in Godot 4
			tween.tween_property(overlay, "rotation", TAU, duration)
			overlay.set_meta("animation_tween", tween)

		"scale_pulse":
			var tween = parent.create_tween()
			tween.set_loops(-1)  # -1 means infinite in Godot 4
			tween.tween_property(overlay, "scale", Vector2(1.1, 1.1), 1.5)
			tween.tween_property(overlay, "scale", Vector2(0.9, 0.9), 1.5)
			overlay.set_meta("animation_tween", tween)

		"static":
			# No animation, just stay visible
			pass

func _remove_overlay(overlay: Sprite2D) -> void:
	if not overlay or not is_instance_valid(overlay):
		return

	active_overlays.erase(overlay)

	# Kill any running animation tween to prevent infinite loop errors
	if overlay.has_meta("animation_tween"):
		var anim_tween = overlay.get_meta("animation_tween")
		if anim_tween and anim_tween.is_valid():
			anim_tween.kill()
		overlay.remove_meta("animation_tween")

	# Fade out before removing
	var parent = overlay.get_parent()
	if parent and parent.has_method("create_tween"):
		var tween = parent.create_tween()
		tween.tween_property(overlay, "modulate:a", 0.0, 0.5)
		await tween.finished

	if is_instance_valid(overlay):
		overlay.queue_free()

	print("[SymbolicOverlayExecutor] Removed overlay")

func cleanup_all_overlays() -> void:
	"""Remove all active overlays - called on level transitions"""
	for overlay in active_overlays:
		if is_instance_valid(overlay):
			overlay.queue_free()
	active_overlays.clear()
	print("[SymbolicOverlayExecutor] Cleaned up all overlays")
