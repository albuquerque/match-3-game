extends Node
class_name EffectExecutorBackgroundTint

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		return

	var tint_color = params.get("color", "blue")
	var intensity = params.get("intensity", 0.3)
	var duration = params.get("duration", 0.5)

	print("[BackgroundTintExecutor] Tinting background '%s' at %d%% for %ss" % [tint_color, int(intensity * 100), duration])

	var tint = viewport.get_node_or_null("BackgroundTintOverlay")
	if not tint:
		tint = ColorRect.new()
		tint.name = "BackgroundTintOverlay"
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.anchor_left = 0
		tint.anchor_top = 0
		tint.anchor_right = 1
		tint.anchor_bottom = 1
		tint.z_index = 99
		viewport.add_child(tint)

	var color: Color
	if typeof(tint_color) == TYPE_STRING and tint_color.begins_with("#"):
		color = Color(tint_color)
		color.a = intensity
		print("[BackgroundTintExecutor] Using hex color: %s (R:%.2f G:%.2f B:%.2f A:%.2f)" % [tint_color, color.r, color.g, color.b, color.a])
	else:
		match tint_color:
			"blue": color = Color(0.2, 0.3, 0.6, intensity)
			"gold": color = Color(0.9, 0.8, 0.3, intensity)
			"purple": color = Color(0.5, 0.2, 0.6, intensity)
			"red": color = Color(0.6, 0.2, 0.2, intensity)
			"green": color = Color(0.2, 0.6, 0.3, intensity)
			_:
				color = Color(0.2, 0.3, 0.6, intensity)
		print("[BackgroundTintExecutor] Using named color '%s': (R:%.2f G:%.2f B:%.2f A:%.2f)" % [tint_color, color.r, color.g, color.b, color.a])

	tint.color = Color(color.r, color.g, color.b, 0)
	var tween = viewport.create_tween()
	tween.tween_property(tint, "color", color, 0.2)
	tween.tween_interval(duration * 0.7)
	tween.tween_property(tint, "color:a", 0.0, duration * 0.3)
	tween.tween_callback(tint.queue_free)
	print("[BackgroundTintExecutor] Tint animation started")
