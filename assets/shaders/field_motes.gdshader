shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.62, 0.93, 0.8, 1.0);
uniform float phase = 0.0;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	vec2 p = floor(UV * vec2(56.0, 72.0)) / vec2(56.0, 72.0);
	p = vec2(p.x - 0.5, 1.0 - p.y);
	float t = TIME + phase;
	float energy = 0.0;
	float glow = 0.0;
	for (int i = 0; i < 5; i++) {
		float k = float(i);
		float age = fract(t * (0.16 + 0.018 * k) + k * 0.232);
		vec2 pos = vec2(sin(age * 5.4 + 2.39 * k + phase) * (0.06 + age * 0.28), 0.12 + age * 0.80);
		vec2 d = abs(p - pos) / vec2(0.044 + k * 0.002, 0.111 - k * 0.009);
		float fade = 0.55 * sin(age * PI);
		energy += (1.0 - smoothstep(0.78, 1.11, d.x + d.y)) * (0.40 + fade);
		glow += exp(-dot(d, d) * 0.13) * fade;
	}
	float core = min(1.0, energy);
	ALBEDO = mix(tint.rgb, vec3(1.0, 0.98, 0.89), core * 0.55);
	ALPHA = clamp(core + glow * 0.23, 0.0, 1.0);
}
