shader_type canvas_item;

uniform float u_intensity : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec3 col = vec3(0.0, 1.0, 0.0);
	float alpha = clamp(u_intensity * 0.9, 0.0, 1.0);
	COLOR = vec4(col * u_intensity * 1.2, alpha);
}
