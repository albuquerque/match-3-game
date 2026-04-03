extends Node
class_name EffectExecutorVignette

func execute(context: Dictionary) -> void:
	var params = context.get("params", {})
	var viewport = context.get("viewport", null)
	if not viewport:
		return

	var intensity = params.get("intensity", 0.5)
	var duration = params.get("duration", 0.5)

	print("[VignetteEffector] Applying vignette at %d%% intensity" % int(intensity * 100))

	var vignette = viewport.get_node_or_null("VignetteOverlay")
	var created := false
	if not vignette:
		vignette = ColorRect.new()
		vignette.name = "VignetteOverlay"
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vignette.anchor_left = 0
		vignette.anchor_top = 0
		vignette.anchor_right = 1
		vignette.anchor_bottom = 1
		vignette.z_index = 101
		created = true

	var shader_code = """
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.5;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float dist = length(uv);
	float vignette = smoothstep(0.3, 1.2, dist);
	vignette = pow(vignette, 0.8);
	COLOR = vec4(0.0, 0.0, 0.0, vignette * intensity);
}
"""
	var shader = Shader.new()
	shader.code = shader_code
	var shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	shader_material.set_shader_parameter("intensity", 0.0)
	vignette.material = shader_material

	# Only add to viewport if it has no parent (avoid add_child errors)
	if vignette.get_parent() == null:
		viewport.add_child(vignette)

	if vignette.material and vignette.material is ShaderMaterial:
		vignette.material.set_shader_parameter("intensity", intensity)
		print("[VignetteEffector] Set vignette intensity to %.2f" % intensity)
