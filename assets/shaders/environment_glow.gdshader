shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.15, 0.22);
uniform bool beam = false;
uniform float phase = 0.0;

void fragment() {
	vec2 uv = floor(UV * vec2(160.0, 240.0)) / vec2(160.0, 240.0);
	vec2 p = 2.0 * uv - 1.0;
	float radius = dot(p, p);
	float halo = max(0.0, 1.0 - radius);
	float light = halo * halo * (0.28 + 0.72 / (1.0 + 9.0 * radius));
	if (beam) {
		float cross_section = (p.x + 0.28 * p.y) / mix(0.38, 1.00, uv.y);
		float edge = 1.0 - smoothstep(0.45, 1.0, abs(cross_section));
		float striation = 0.65 + 0.35 * sin(cross_section * 15.0 + sin(uv.y * 4.0 + phase + TIME * 0.22));
		float pocket = 0.78 + 0.22 * sin(uv.y * 9.0 - TIME * 0.35 + phase);
		light = edge * striation * pocket * sin(uv.y * PI) * 0.90;
	}
	ALBEDO = glow_color.rgb;
	ALPHA = light * glow_color.a;
}
