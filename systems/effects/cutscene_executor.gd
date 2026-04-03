extends Node
class_name CutsceneExecutor

# Simple cutscene executor: plays an AnimationPlayer animation on a given node path
# or waits for a specified duration. Designed to be lightweight and reliable.

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
	var duration = float(params.get("duration", 3.0))
	var target_path = params.get("target_path", "")
	var animation = params.get("animation", "")

	print("[CutsceneExecutor] execute() called - duration=", duration, " animation=", animation, " target=", target_path)

	# Safety check: ensure we're in the tree
	if not is_inside_tree():
		print("[CutsceneExecutor] ERROR: Not in tree, cannot execute - returning immediately")
		return

	# If an animation is specified and the target exists, try to play it
	if animation != "" and target_path != "":
		var root = get_tree().root
		var target = null
		# Try get_node_or_null first (supports absolute/relative paths)
		if has_node(target_path):
			target = get_node(target_path)
		else:
			# Fallback to recursive search by name
			target = _find_descendant_by_name(root, target_path)

		if target and target.has_node("AnimationPlayer"):
			var anim_player = target.get_node("AnimationPlayer")
			if anim_player.has_animation(animation):
				print("[CutsceneExecutor] Playing animation: ", animation)
				anim_player.play(animation)
				# Wait for animation length rather than signal for robustness
				var anim = anim_player.get_animation(animation)
				if anim:
					var length = float(anim.length)
					if is_inside_tree() and get_tree():
						await get_tree().create_timer(length).timeout
					print("[CutsceneExecutor] Animation finished: ", animation)
					return
				else:
					print("[CutsceneExecutor] Failed to get animation resource length")
			# fallthrough to wait duration if animation not playable

	# Otherwise, just wait for duration
	print("[CutsceneExecutor] Waiting for duration: ", duration)
	if is_inside_tree() and get_tree():
		await get_tree().create_timer(duration).timeout
	print("[CutsceneExecutor] Duration wait complete")
	return
