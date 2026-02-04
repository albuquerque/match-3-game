extends Node
class_name EffectExecutorCameraImpulse

# Safe recursive search for a descendant node by name
func _find_descendant_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	var cc = 0
	if root.has_method("get_child_count"):
		cc = root.get_child_count()
	for i in range(cc):
		var c = root.get_child(i)
		if not c:
			continue
		if str(c.name) == target_name:
			return c
		var found = _find_descendant_by_name(c, target_name)
		if found:
			return found
	return null

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var board_node = context.get("board", null)
	var strength = params.get("strength", 0.3)
	var duration = params.get("duration", 0.2)

	print("[CameraImpulseExecutor] Applying screen shake: strength=%s, duration=%s" % [strength, duration])

	if not viewport:
		print("[CameraImpulseExecutor] No viewport - skipping shake")
		return

	var game_board: Node = null

	# First, try using the board_node passed in context (most reliable)
	if board_node:
		game_board = board_node
		print("[CameraImpulseExecutor] Using GameBoard from context")

	# Try to get root from viewport's tree (safe - no get_node_or_null on self)
	if not game_board and viewport and viewport is Node:
		var tree = viewport.get_tree()
		if tree:
			var root = tree.get_root()
			if root:
				# Try to find via root (safe because we're using viewport's tree)
				var main_game = root.get_node_or_null("MainGame")
				if main_game:
					game_board = main_game.get_node_or_null("GameBoard")
					if game_board:
						print("[CameraImpulseExecutor] Found GameBoard via root->MainGame->GameBoard")

	# Fallback: recursive search using safe helper
	if not game_board:
		game_board = _find_descendant_by_name(viewport, "GameBoard")
		if game_board:
			print("[CameraImpulseExecutor] Found GameBoard via recursive search")

	# Additional fallback: find first Node2D child
	if not game_board:
		for child in viewport.get_children():
			if child and child is Node2D:
				game_board = child
				print("[CameraImpulseExecutor] Falling back to Node2D child: %s" % child.name)
				break

	if game_board:
		print("[CameraImpulseExecutor] Ready to shake node: %s (type=%s)" % [game_board.name, typeof(game_board)])
	else:
		print("[CameraImpulseExecutor] GameBoard not found - skipping shake")

	if game_board and (game_board is Node2D or game_board is Control):
		_shake_node(game_board, float(strength), float(duration))
	else:
		print("[CameraImpulseExecutor] GameBoard not found or not Node2D/Control - skipping shake")

func _shake_node(node: Node, strength: float, duration: float) -> void:
	var shake_amount = strength * 15.0

	var tree = null
	if node and node.has_method("get_tree"):
		tree = node.get_tree()
	elif has_method("get_tree"):
		tree = get_tree()
	if not tree:
		print("[CameraImpulseExecutor] No SceneTree available for tweening - skipping shake")
		return

	var tween = tree.create_tween()
	var shake_count = max(1, int(duration / 0.05))

	# Determine property to tween based on node type
	var is_node2d = node is Node2D
	var is_control = node is Control
	var original_pos = Vector2.ZERO
	if is_node2d:
		original_pos = (node as Node2D).position
		print("[CameraImpulseExecutor] Shaking Node2D '%s'" % node.name)
	elif is_control:
		original_pos = (node as Control).rect_position
		print("[CameraImpulseExecutor] Shaking Control '%s'" % node.name)
	else:
		print("[CameraImpulseExecutor] Node '%s' is neither Node2D nor Control - skipping" % node.name)
		return

	for i in range(shake_count):
		var random_offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
		if is_node2d:
			tween.tween_property(node, "position", original_pos + random_offset, 0.05)
		elif is_control:
			tween.tween_property(node, "rect_position", original_pos + random_offset, 0.05)

	# Return to original
	if is_node2d:
		tween.tween_property(node, "position", original_pos, 0.1)
	elif is_control:
		tween.tween_property(node, "rect_position", original_pos, 0.1)
