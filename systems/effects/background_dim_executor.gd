extends Node
class_name EffectExecutorBackgroundDim

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		return

	var intensity = params.get("intensity", params.get("amount", 0.5))
	var duration = params.get("duration", 0.5)

	print("[BackgroundDimExecutor] Dimming with intensity %d%% over %ss" % [int(intensity * 100), duration])

	var dim_overlay = viewport.get_node_or_null("BackgroundDimOverlay")
	if not dim_overlay:
		dim_overlay = ColorRect.new()
		dim_overlay.name = "BackgroundDimOverlay"
		dim_overlay.color = Color.BLACK
		dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim_overlay.anchor_left = 0
		dim_overlay.anchor_top = 0
		dim_overlay.anchor_right = 1
		dim_overlay.anchor_bottom = 1
		dim_overlay.z_index = -75
		viewport.add_child(dim_overlay)

	var tween = viewport.create_tween()
	tween.tween_property(dim_overlay, "color:a", intensity, duration)
