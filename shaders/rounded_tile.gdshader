shader_type canvas_item;

uniform float corner_radius : hint_range(0.0, 0.5) = 0.15;

void fragment() {
	// Get UV coordinates centered around 0.5
	vec2 uv = UV - vec2(0.5);

	// Calculate distance from edge for rounded corners
	vec2 abs_uv = abs(uv);
	vec2 corner_zone = abs_uv - vec2(0.5 - corner_radius);

	// If we're in the corner zone, calculate distance from corner arc
	float alpha = 1.0;
	if (corner_zone.x > 0.0 && corner_zone.y > 0.0) {
		float dist = length(corner_zone);
		if (dist > corner_radius) {
			alpha = 0.0;
		} else {
			// Smooth antialiasing at the edge
			alpha = smoothstep(corner_radius, corner_radius - 0.01, dist);
		}
	}

	// Sample the texture
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}

