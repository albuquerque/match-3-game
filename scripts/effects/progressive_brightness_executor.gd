extends Node
class_name EffectExecutorProgressiveBrightness

var match_count: int = 0
var target_matches: int = 30
var dim_overlay: ColorRect = null
var use_score_mode: bool = false
var target_score: int = 0

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	var event_name = context.get("binding", {}).get("on", "")

	print("[ProgressiveBrightnessExecutor] execute called - event_name: '%s'" % event_name)

	if not viewport:
		print("[ProgressiveBrightnessExecutor] No viewport!")
		return

	if event_name == "level_loaded":
		match_count = 0
		use_score_mode = params.get("score_based", false)
		if use_score_mode:
			target_score = context.get("event_context", {}).get("target", 0)
			if target_score == 0 and GameManager:
				target_score = GameManager.target_score
			print("[ProgressiveBrightnessExecutor] Using SCORE mode - target: %d" % target_score)
		else:
			target_matches = params.get("target_matches", 30)
			print("[ProgressiveBrightnessExecutor] Using MATCH mode - target: %d matches" % target_matches)

		# Create black overlay
		dim_overlay = viewport.get_node_or_null("ProgressiveBrightnessOverlay")
		if dim_overlay:
			dim_overlay.queue_free()

		dim_overlay = ColorRect.new()
		dim_overlay.name = "ProgressiveBrightnessOverlay"
		dim_overlay.color = Color.BLACK
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_overlay.anchor_left = 0
		dim_overlay.anchor_top = 0
		dim_overlay.anchor_right = 1
		dim_overlay.anchor_bottom = 1
		dim_overlay.z_index = -75
		viewport.add_child(dim_overlay)

		if use_score_mode:
			print("[ProgressiveBrightnessExecutor] Starting completely dark - will brighten as score approaches %d" % target_score)
		else:
			print("[ProgressiveBrightnessExecutor] Starting completely dark - will brighten over %d matches" % target_matches)

	elif event_name == "match_cleared":
		if not dim_overlay or not is_instance_valid(dim_overlay):
			print("[ProgressiveBrightnessExecutor] Overlay invalid, trying to find it...")
			dim_overlay = viewport.get_node_or_null("ProgressiveBrightnessOverlay")
			if not dim_overlay:
				print("[ProgressiveBrightnessExecutor] Overlay not found in viewport!")
				return

		var progress = 0.0

		if use_score_mode:
			var current_score = 0
			if GameManager and "score" in GameManager:
				current_score = GameManager.score

			if target_score > 0:
				progress = min(float(current_score) / float(target_score), 1.0)

			print("[ProgressiveBrightnessExecutor] Score: %d/%d - Brightness: %d%%" % [current_score, target_score, int(progress * 100)])
		else:
			match_count += 1
			progress = min(float(match_count) / float(target_matches), 1.0)
			print("[ProgressiveBrightnessExecutor] Match %d/%d - Brightness: %d%%" % [match_count, target_matches, int(progress * 100)])

		var target_alpha = 1.0 - progress

		var tween = viewport.create_tween()
		tween.tween_property(dim_overlay, "color:a", target_alpha, 0.3)

		if progress >= 1.0:
			print("[ProgressiveBrightnessExecutor] ✓ Fully illuminated!")
			tween.tween_callback(dim_overlay.queue_free)
