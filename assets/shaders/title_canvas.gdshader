shader_type canvas_item;
render_mode unshaded;

// The archive page dissolves into the live diorama on a stepped pixel grid.
uniform vec2 surface_size = vec2(1600.0, 960.0);
uniform float panel_width = 510.0;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(23.17, 91.71))) * 5173.23);
}

void fragment() {
	vec2 px = floor(UV * surface_size / 3.0) * 3.0;
	float t = px.y / surface_size.y;
	float ledge = panel_width + 44.0 * sin(t * 2.7) - 100.0 * pow(t, 3.0);
	float coverage = 1.0 - smoothstep(ledge - 70.0, ledge + 130.0, px.x);
	float cloud = sin(px.y * 0.004 + px.x * 0.009 + TIME * 0.11);
	vec3 ink = mix(vec3(0.028,0.055,0.10), vec3(0.079,0.153,0.191), clamp(0.45 + 0.38 * t + cloud * 0.13, 0.0, 1.0));
	float stipple = grain(floor(px / 3.0));
	float lip = floor((px.x + px.y * 0.29) / 9.0) * 9.0;
	float foil = smoothstep(0.935, 1.0, sin(lip * 0.051 - TIME * 0.1));
	ink += vec3(0.024,0.052,0.046) * foil * (0.20 + 0.75*t);
	ink += (stipple - 0.5) * 0.012;
	float alpha = clamp(coverage * (0.92 + 0.06 * (1.0 - t)) + (stipple - 0.5) * coverage * (1.0 - coverage) * 0.21, 0.0, 1.0);
	COLOR = vec4(ink, alpha);
}
