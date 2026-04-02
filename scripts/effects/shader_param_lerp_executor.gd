extends Node
class_name EffectExecutorShaderParamLerp

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var param_name = str(params.get("param", ""))
	var from_val = params.get("from", null)
	var to_val = params.get("to", null)
	var duration = float(params.get("duration", 0.5))
	var shader_id = str(params.get("shader", ""))
	var anchor = str(context.get("anchor", ""))

	if param_name == "" or from_val == null or to_val == null:
		push_warning("[ShaderParamLerpExecutor] Missing required params (param/from/to)")
		return

	# Resolve target node: prefer VisualAnchorManager, then viewport, then viewport root
	var target_node: Node = null
	if anchor != "":
		var vam = NodeResolvers._get_vam()
		if vam and vam.has_method("get_anchor"):
			target_node = vam.get_anchor(anchor)
		# try viewport child
		if not target_node and viewport and viewport is Node and viewport.has_node(anchor):
			target_node = viewport.get_node(anchor)

	if target_node == null:
		target_node = viewport if viewport and viewport is Node else self

	if not target_node:
		print("[ShaderParamLerpExecutor] No target node found - skipping")
		return

	# Try to obtain a Shader resource from chapter assets or direct resource path
	var shader_res: Shader = null
	if shader_id != "":
		# Step 1: resolve asset ID → path via chapter assets dict
		var resolved_path: String = shader_id
		var chapter = context.get("chapter", {})
		if chapter and typeof(chapter) == TYPE_DICTIONARY:
			var shader_assets = chapter.get("assets", {}).get("shaders", {})
			if shader_assets.has(shader_id):
				resolved_path = str(shader_assets[shader_id])

		# Step 2: load from resolved path
		if resolved_path.begins_with("res://"):
			if ResourceLoader.exists(resolved_path):
				shader_res = ResourceLoader.load(resolved_path)
		elif resolved_path.ends_with(".shader") and FileAccess.file_exists(resolved_path):
			var f = FileAccess.open(resolved_path, FileAccess.READ)
			if f:
				var code = f.get_as_text()
				f.close()
				shader_res = Shader.new()
				shader_res.code = code

	# If we still don't have a shader_res, try to find an existing ShaderMaterial on target
	var shader_material: ShaderMaterial = null
	if target_node and target_node.has_method("get") and target_node.get("material") and target_node.get("material") is ShaderMaterial:
		shader_material = target_node.get("material")

	# If no existing material but we have a shader resource, create overlay with material
	var created_overlay := false
	if shader_material == null and shader_res != null:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader_res
		# Create overlay ColorRect and apply material
		var overlay = ColorRect.new()
		overlay.name = "ShaderParamLerpOverlay_%s" % param_name
		overlay.anchor_left = 0
		overlay.anchor_top = 0
		overlay.anchor_right = 1
		overlay.anchor_bottom = 1
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.color = Color(0,0,0,0)
		overlay.material = shader_material
		if viewport and viewport is Node:
			viewport.add_child(overlay)
			created_overlay = true
		else:
			add_child(overlay)
			created_overlay = true

	if shader_material == null:
		push_warning("[ShaderParamLerpExecutor] Could not resolve ShaderMaterial to animate")
		return

	# Ensure parameter starts at from_val
	shader_material.set_shader_parameter(param_name, from_val)

	# Choose tween root (prefer viewport tree)
	var tree = null
	if viewport and viewport.has_method("get_tree") and viewport.get_tree() != null:
		tree = viewport.get_tree()
	elif has_method("get_tree") and get_tree() != null:
		tree = get_tree()
	if not tree:
		tree = Engine.get_main_loop()

	var tween = tree.create_tween()
	var prop_path = "shader_parameter/%s" % param_name
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shader_material, prop_path, to_val, duration)

	# Cleanup overlay when tween finishes
	if created_overlay:
		# Find overlay under viewport or self
		var cleanup_name = "ShaderParamLerpOverlay_%s" % param_name
		var overlay_to_cleanup = viewport.get_node_or_null(cleanup_name) if viewport and viewport is Node else get_node_or_null(cleanup_name)
		if overlay_to_cleanup and tween:
			tween.tween_callback(Callable(overlay_to_cleanup, "queue_free"))

	print("[ShaderParamLerpExecutor] Tween started for %s -> %s" % [prop_path, str(to_val)])
	return

# Helper recursive search retained from previous implementation
func _find_node_recursive(root: Node, name: String) -> Node:
	if not root:
		return null
	if str(root.name) == name:
		return root
	for child in root.get_children():
		var found = _find_node_recursive(child, name)
		if found:
			return found
	return null
