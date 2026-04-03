extends Node
class_name EffectExecutorPlayAnimation

# PlayAnimationExecutor: robust, minimal runtime animation fallback to avoid loading external .tres files

func execute(context: Dictionary) -> void:
	# Start deferred attempt sequence to handle race conditions where GameBoard isn't yet instanced
	_deferred_play(context, 0, 8, 0.04)

# Attempt to play animation, retrying a few times until a SceneTree and/or GameBoard is available
func _deferred_play(context: Dictionary, attempt: int, max_retries: int, delay: float) -> void:
	var params = context.get("params", {})
	var animation_id = params.get("animation", "test_anim")
	var board_node = context.get("board", null)

	# If board_node not valid, try to resolve it from the SceneTree root/current_scene
	if (not board_node or not is_instance_valid(board_node)):
		var tree = null
		if has_method("get_tree") and get_tree() != null:
			tree = get_tree()
		if tree:
			# try to find GameBoard under current scene or root
			var cs = tree.get_current_scene()
			if cs and cs.has_method("find_node"):
				board_node = cs.find_node("GameBoard", true, false)
			if not board_node:
				var root = tree.get_root()
				if root and root.has_method("find_node"):
					board_node = root.find_node("GameBoard", true, false)

	# If still not found, and retries remain, schedule another attempt
	if (not board_node or not is_instance_valid(board_node)) and attempt < max_retries:
		var tree2 = null
		if has_method("get_tree") and get_tree() != null:
			tree2 = get_tree()
		if tree2:
			var t = tree2.create_timer(delay)
			# Connect timeout to another attempt
			t.timeout.connect(Callable(self, "_deferred_play"), [context, attempt + 1, max_retries, delay])
			print("[PlayAnimationExecutor] Board not found, retrying play_animation (attempt %d)" % (attempt + 1))
			return
		else:
			call_deferred("_deferred_play", context, attempt + 1, max_retries, delay)
			return

	# We have a board_node (or we've exhausted retries) - play runtime animation
	_play_runtime_animation(context, animation_id, board_node)

# Create and play a simple runtime animation that nudges the GameBoard up and back
func _play_runtime_animation(context: Dictionary, animation_id: String, board_node: Node) -> void:
	var viewport = context.get("viewport", null)

	# Build animation
	var runtime_anim = Animation.new()
	runtime_anim.length = 0.8
	runtime_anim.loop_mode = Animation.LOOP_NONE
	runtime_anim.add_track(Animation.TYPE_VALUE)
	runtime_anim.track_set_interpolation_type(0, Animation.INTERPOLATION_CUBIC)
	runtime_anim.track_insert_key(0, 0.0, Vector2(0, 0))
	runtime_anim.track_insert_key(0, 0.4, Vector2(0, -80))
	runtime_anim.track_insert_key(0, 0.8, Vector2(0, 0))

	# Prepare AnimationPlayer and parent it where tracks will resolve
	var temp_player = AnimationPlayer.new()
	temp_player.name = "PlayAnimPlayer_Runtime_%s" % animation_id
	var parent_target: Node = null
	var track_path = null

	if board_node and is_instance_valid(board_node) and board_node.get_parent():
		# parent under GameBoard parent and target GameBoard:position
		parent_target = board_node.get_parent()
		track_path = NodePath(board_node.name + ":position")
	else:
		# fallback: try viewport/current_scene/root resolution
		var tree = null
		if has_method("get_tree") and get_tree() != null:
			tree = get_tree()
		if tree:
			var cs = tree.get_current_scene()
			if cs and cs.has_node("GameBoard"):
				parent_target = cs
				track_path = NodePath("GameBoard:position")
			else:
				var root = tree.get_root()
				if root and root.has_method("find_node"):
					var found = root.find_node("GameBoard", true, false)
					if found and found.get_parent():
						parent_target = found.get_parent()
						track_path = NodePath(found.name + ":position")
		# last resort parent
		if parent_target == null and tree and tree.get_current_scene() != null:
			parent_target = tree.get_current_scene()
			if track_path == null:
				track_path = NodePath("../GameBoard:position")

	if parent_target:
		parent_target.add_child(temp_player)
		print("[PlayAnimationExecutor] Parenting runtime AnimationPlayer under %s for track resolution" % parent_target.name)
	elif viewport and viewport is Node:
		viewport.add_child(temp_player)
		print("[PlayAnimationExecutor] Parenting runtime AnimationPlayer under viewport (fallback)")
	else:
		add_child(temp_player)
		print("[PlayAnimationExecutor] Parenting runtime AnimationPlayer under executor node (last resort)")

	if track_path == null:
		track_path = NodePath("../GameBoard:position")
	runtime_anim.track_set_path(0, track_path)

	# Godot 4: Use AnimationLibrary instead of add_animation
	var anim_library = AnimationLibrary.new()
	anim_library.add_animation("runtime_anim", runtime_anim)
	temp_player.add_animation_library("", anim_library)
	temp_player.play("runtime_anim")
	if temp_player.has_signal("animation_finished"):
		# animation_finished passes animation name, but queue_free takes no args
		# Use lambda to ignore the argument
		temp_player.animation_finished.connect(func(_anim_name): temp_player.queue_free())
	print("[PlayAnimationExecutor] Played runtime animation '%s' (track=%s, parent=%s)" % [animation_id, str(track_path), parent_target.name if parent_target else "(none)"])
	print("[NARR:PLAY_ANIM_DONE] animation_id=%s parent=%s track=%s" % [animation_id, parent_target.name if parent_target else "(none)", str(track_path)])

# Utility: recursive search under a node by name
func _recurse_search_node(root: Node, name: String) -> Node:
	if not root:
		return null
	var cc = 0
	if root.has_method("get_child_count"):
		cc = root.get_child_count()
	for i in range(cc):
		var c = root.get_child(i)
		if not c:
			continue
		if str(c.name) == name:
			return c
		var f = _recurse_search_node(c, name)
		if f:
			return f
	return null

# Utility: find node safely under viewport or across the scene tree
func _safe_resolve_node(name: String, viewport: Node) -> Node:
	if not name or name == "":
		return null
	if viewport and viewport is Node and viewport.has_node(name):
		return viewport.get_node(name)
	if viewport and viewport is Node and viewport.has_method("get_child_count"):
		return _recurse_search_node(viewport, name)
	if has_method("get_tree") and get_tree() != null:
		var root = get_tree().get_root()
		if root and root.has_method("find_node"):
			var found = root.find_node(name, true, false)
			if found:
				return found
	return null
