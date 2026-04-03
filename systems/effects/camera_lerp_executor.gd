extends Node
class_name EffectExecutorCameraLerp

var active_lerp_tween: Tween = null
var original_board_scale: Vector2 = Vector2.ONE
var original_board_position: Vector2 = Vector2.ZERO

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var board_node = context.get("board", null)

	var target_type = params.get("target", "board")
	var zoom_level = params.get("zoom", 1.0)
	var duration = params.get("duration", 1.0)
	var easing = params.get("easing", "ease_in_out")

	print("[CameraLerpExecutor] Applying zoom effect: zoom=%s duration=%s" % [zoom_level, duration])

	if not board_node:
		push_warning("[CameraLerpExecutor] No board node in context")
		return

	# Store original state on first use
	if not board_node.has_meta("original_scale"):
		original_board_scale = board_node.scale
		original_board_position = board_node.position
		board_node.set_meta("original_scale", original_board_scale)
		board_node.set_meta("original_position", original_board_position)
	else:
		original_board_scale = board_node.get_meta("original_scale")
		original_board_position = board_node.get_meta("original_position")

	# Calculate board center for proper scaling
	# In Godot 4, we adjust position to keep board centered when scaling
	var board_width = 0.0
	var board_height = 0.0
	if "GRID_WIDTH" in board_node and "GRID_HEIGHT" in board_node and "tile_size" in board_node:
		board_width = board_node.GRID_WIDTH * board_node.tile_size
		board_height = board_node.GRID_HEIGHT * board_node.tile_size
		print("[CameraLerpExecutor] Board dimensions: %sx%s" % [board_width, board_height])

	# Cancel any existing lerp
	if active_lerp_tween and active_lerp_tween.is_valid():
		active_lerp_tween.kill()

	# Calculate target scale (zoom is just scaling the board)
	var target_scale = original_board_scale * zoom_level

	# Calculate position adjustment to keep board centered
	# When scaling from top-left (default), we need to offset position to simulate center scaling
	var scale_change = target_scale - original_board_scale
	var position_offset = Vector2.ZERO
	if board_width > 0 and board_height > 0:
		# Offset is half the size change (to center the growth)
		position_offset = Vector2(
			-(board_width * scale_change.x) / 2.0,
			-(board_height * scale_change.y) / 2.0
		)

	var target_position = original_board_position + position_offset

	# Create smooth scaling animation
	if viewport and viewport.has_method("create_tween"):
		active_lerp_tween = viewport.create_tween()
		active_lerp_tween.set_parallel(true)  # Animate scale and position together

		# Set easing
		match easing:
			"ease_in":
				active_lerp_tween.set_ease(Tween.EASE_IN)
			"ease_out":
				active_lerp_tween.set_ease(Tween.EASE_OUT)
			"ease_in_out":
				active_lerp_tween.set_ease(Tween.EASE_IN_OUT)

		active_lerp_tween.set_trans(Tween.TRANS_CUBIC)

		# Animate board scale and position together
		active_lerp_tween.tween_property(board_node, "scale", target_scale, duration)
		active_lerp_tween.tween_property(board_node, "position", target_position, duration)

		print("[CameraLerpExecutor] Animating board scale to %s and position to %s" % [target_scale, target_position])

func reset_camera(viewport: Node, board_node: Node) -> void:
	"""Reset board to original scale and position - called on level transitions"""
	if not board_node or not is_instance_valid(board_node):
		return

	if board_node.has_meta("original_scale"):
		board_node.scale = board_node.get_meta("original_scale")
		board_node.position = board_node.get_meta("original_position")
		board_node.remove_meta("original_scale")
		board_node.remove_meta("original_position")
		print("[CameraLerpExecutor] Board reset to original scale and position")
