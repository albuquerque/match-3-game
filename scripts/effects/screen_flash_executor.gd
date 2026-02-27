extends Node
class_name EffectExecutorScreenFlash

var NodeResolvers = null

func _ensure_resolvers():
	if NodeResolvers == null:
		var s = load("res://scripts/helpers/node_resolvers_api.gd")
		if s != null and typeof(s) != TYPE_NIL and s.has_method("_get_vam"):
			NodeResolvers = s
		else:
			NodeResolvers = load("res://scripts/helpers/node_resolvers_shim.gd")

func execute(context: Dictionary) -> void:
	_ensure_resolvers()
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		return

	var flash_color = params.get("color", "white")
	var intensity = params.get("intensity", 1.0)
	var duration = params.get("duration", 0.3)

	print("[ScreenFlashExecutor] Flashing '%s' for %ss at intensity %.2f" % [flash_color, duration, intensity])

	# Trigger vibration for high-intensity flashes (like lightning)
	if intensity >= 0.5:
		# Use fallback autoload lookup to avoid analyzer errors on _get_vm
		var vm = NodeResolvers._fallback_autoload("VibrationManager")
		if vm and vm.has_method("vibrate_lightning"):
			vm.vibrate_lightning()

	var flash = ColorRect.new()
	flash.name = "ScreenFlash"
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.anchor_left = 0
	flash.anchor_top = 0
	flash.anchor_right = 1
	flash.anchor_bottom = 1
	flash.z_index = 998

	var color: Color
	if typeof(flash_color) == TYPE_STRING and flash_color.begins_with("#"):
		color = Color(flash_color)
		color.a = intensity
		print("[ScreenFlashExecutor] Using hex color: %s (R:%.2f G:%.2f B:%.2f A:%.2f)" % [flash_color, color.r, color.g, color.b, color.a])
	else:
		match flash_color:
			"white": color = Color(1.0, 1.0, 1.0, intensity)
			"gold": color = Color(1.0, 0.9, 0.3, intensity)
			"blue": color = Color(0.3, 0.5, 1.0, intensity)
			"purple": color = Color(0.8, 0.3, 1.0, intensity)
			"green": color = Color(0.0, 1.0, 0.0, intensity)
			"red": color = Color(1.0, 0.0, 0.0, intensity)
			_:
				color = Color(1.0, 1.0, 1.0, intensity)
		print("[ScreenFlashExecutor] Using named color '%s': (R:%.2f G:%.2f B:%.2f A:%.2f)" % [flash_color, color.r, color.g, color.b, color.a])

	flash.color = color

	viewport.add_child(flash)

	var tween = viewport.create_tween()
	tween.tween_property(flash, "color:a", 0.0, duration)
	tween.tween_callback(Callable(flash, "queue_free"))
	print("[ScreenFlashExecutor] Flash animation started")
