shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled;

uniform float progress = 0.0;
uniform vec2 direction = vec2(1.0, 0.0);
uniform vec4 crest_color : source_color = vec4(0.58, 0.95, 0.91, 1.0);
varying float top_face;

void vertex() {
	top_face = max(0.0, NORMAL.y);
}
void fragment() {
	vec2 p = floor(UV * 96.0) / 96.0 - 0.5;
	float along = dot(p, direction);
	float across = dot(p, vec2(direction.y, -direction.x));
	float ripple = 0.05 * sin(across * 12.0) + 0.025 * sin(across * 26.0);
	float head = mix(-0.73, 0.78, progress) + ripple - along;
	float crest = 1.0 - smoothstep(0.006, 0.075, abs(head));
	float wake = smoothstep(0.0, 0.07, head) * (1.0 - smoothstep(0.07, 0.27, head));
	ALBEDO = crest_color.rgb;
	ALPHA = top_face * (crest * 0.67 + wake * 0.17);
}
