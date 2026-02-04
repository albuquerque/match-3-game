extends Node
class_name EffectExecutorShaderParamLerp

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var board_node = context.get("board", null)

	if not viewport:
		print("[ShaderParamLerpExecutor] No viewport - skipping")
		return

	var param_name = params.get("param", "")
	var from_val = params.get("from", null)
	var to_val = params.get("to", null)
	var duration = float(params.get("duration", 0.5))
	var shader_id = params.get("shader", "")
	var anchor = context.get("anchor", "")
	var target = context.get("target", "")
	var chapter = context.get("chapter", null)

	if param_name == "" or from_val == null or to_val == null:
		push_warning("[ShaderParamLerpExecutor] Missing required params (param/from/to)")
		return

	print("[ShaderParamLerpExecutor] Lerp shader param '%s' from=%s to=%s over %ss (shader=%s, anchor=%s, target=%s)" % [param_name, str(from_val), str(to_val), duration, shader_id, anchor, target])

	# Resolve target node
	var target_node: Node = null
	if anchor and anchor != "":
		# Try to resolve anchor from VisualAnchorManager
		var vam = get_node_or_null("/root/VisualAnchorManager")
		if vam and vam.has_method("get_anchor"):
			target_node = vam.get_anchor(anchor)
		# Fallback: try direct path
		if not target_node and viewport and viewport is Node and viewport.has_node(anchor):
			target_node = viewport.get_node(anchor)
	elif target == "background":
		# Search for background under viewport
		if viewport and viewport is Node:
			target_node = _find_node_by_names(viewport, ["Background", "MainBackground", "BackgroundImage", "BackgroundOverlay"])

	if not target_node:
		target_node = viewport

	if not target_node:
		print("[ShaderParamLerpExecutor] No target node found - skipping")
		return

	var shader_material: ShaderMaterial = null
	var shader_res = null
	var created_overlay = false

	print("[ShaderParamLerpExecutor] Attempting to load shader_id='%s'" % shader_id)
	print("[ShaderParamLerpExecutor] Chapter provided: %s" % (chapter != null))

	if shader_id != "":
		if chapter and chapter.has("assets"):
			print("[ShaderParamLerpExecutor] Chapter has assets")
			var assets = chapter.get("assets", {})
			print("[ShaderParamLerpExecutor] Assets type: %s" % typeof(assets))
			if typeof(assets) == TYPE_DICTIONARY and assets.has("shaders"):
				print("[ShaderParamLerpExecutor] Assets has shaders")
				var shaders = assets.get("shaders", {})
				print("[ShaderParamLerpExecutor] Shaders dict: %s" % str(shaders))
				if shaders.has(shader_id):
					var sh_path = shaders.get(shader_id)
					print("[ShaderParamLerpExecutor] Found shader path: %s" % sh_path)
					if sh_path:
						# For .shader files, read the source and create a Shader resource
						if sh_path.ends_with(".shader") or sh_path.ends_with(".gdshader"):
							if FileAccess.file_exists(sh_path):
								var file = FileAccess.open(sh_path, FileAccess.READ)
								if file:
									var shader_code = file.get_as_text()
									file.close()
									shader_res = Shader.new()
									shader_res.code = shader_code
									print("[ShaderParamLerpExecutor] Loaded and compiled shader from chapter assets: %s" % sh_path)
								else:
									print("[ShaderParamLerpExecutor] Failed to open shader file: %s" % sh_path)
							else:
								print("[ShaderParamLerpExecutor] Shader file doesn't exist: %s" % sh_path)
						else:
							# For other resources, use ResourceLoader
							if ResourceLoader.exists(sh_path):
								shader_res = ResourceLoader.load(sh_path)
								print("[ShaderParamLerpExecutor] Loaded shader from chapter assets using ResourceLoader: %s, type: %s" % [sh_path, shader_res.get_class() if shader_res else "null"])
							else:
								print("[ShaderParamLerpExecutor] Shader path doesn't exist (ResourceLoader): %s" % sh_path)
					else:
						print("[ShaderParamLerpExecutor] Shader path is null")
				else:
					print("[ShaderParamLerpExecutor] Shader ID '%s' not found in shaders dict" % shader_id)
			else:
				print("[ShaderParamLerpExecutor] Assets missing 'shaders' or wrong type")
		else:
			print("[ShaderParamLerpExecutor] Chapter missing or has no assets")

		if not shader_res and typeof(shader_id) == TYPE_STRING and shader_id.begins_with("res://"):
			print("[ShaderParamLerpExecutor] Trying direct path fallback: %s" % shader_id)
			if shader_id.ends_with(".shader") or shader_id.ends_with(".gdshader"):
				if FileAccess.file_exists(shader_id):
					var file = FileAccess.open(shader_id, FileAccess.READ)
					if file:
						var shader_code = file.get_as_text()
						file.close()
						shader_res = Shader.new()
						shader_res.code = shader_code
						print("[ShaderParamLerpExecutor] Loaded and compiled shader from direct path: %s" % shader_id)
					else:
						print("[ShaderParamLerpExecutor] Failed to open shader file: %s" % shader_id)
				else:
					print("[ShaderParamLerpExecutor] Shader file doesn't exist: %s" % shader_id)
			else:
				if ResourceLoader.exists(shader_id):
					shader_res = ResourceLoader.load(shader_id)
					print("[ShaderParamLerpExecutor] Loaded shader from direct path using ResourceLoader: %s" % shader_id)
				else:
					print("[ShaderParamLerpExecutor] Direct path doesn't exist: %s" % shader_id)

	# First, try to find existing material on target node
	if "material" in target_node and target_node.material and target_node.material is ShaderMaterial:
		shader_material = target_node.material
		print("[ShaderParamLerpExecutor] Using existing material from target node")
	elif target_node.get("material") and target_node.get("material") is ShaderMaterial:
		shader_material = target_node.get("material")
		print("[ShaderParamLerpExecutor] Using existing material from target node (via get)")

	# If no existing material but we have a shader resource, create overlay with material
	if not shader_material and shader_res and shader_res is Shader:
		shader_material = ShaderMaterial.new()
		shader_material.shader = shader_res
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
			print("[ShaderParamLerpExecutor] Created overlay with shader material under viewport")
		else:
			add_child(overlay)
			created_overlay = true
			print("[ShaderParamLerpExecutor] Created overlay with shader material under executor")

	# If still no shader_material, warn and exit
	if not shader_material:
		push_warning("[ShaderParamLerpExecutor] Could not resolve ShaderMaterial to animate")
		return

	# Ensure shader parameter starts at from_val
	shader_material.set_shader_parameter(param_name, from_val)

	var tree = null
	if viewport and viewport.has_method("get_tree") and viewport.get_tree() != null:
		tree = viewport.get_tree()
	elif has_method("get_tree") and get_tree() != null:
		tree = get_tree()
	if not tree:
		# fallback to global tween via root
		tree = Engine.get_main_loop()

	var tween = tree.create_tween()
	var prop_path = "shader_parameter/%s" % param_name
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(shader_material, prop_path, to_val, duration)

	print("[ShaderParamLerpExecutor] Tween started for %s -> %s" % [prop_path, str(to_val)])

	# If we created an overlay earlier, queue it for cleanup when tween finishes
	var cleanup_name = "ShaderParamLerpOverlay_%s" % param_name
	var overlay_to_cleanup = viewport.get_node_or_null(cleanup_name) if viewport and viewport is Node else null
	if overlay_to_cleanup and tween:
		tween.tween_callback(Callable(overlay_to_cleanup, "queue_free"))
	return

# Helper to find node by list of possible names (recursive search)
func _find_node_by_names(root: Node, names: Array) -> Node:
	if not root:
		return null
	for name in names:
		var found = _find_node_recursive(root, name)
		if found:
			return found
	return null

# Recursive node search by name
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

