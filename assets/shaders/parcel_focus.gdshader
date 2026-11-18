shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 ink : source_color = vec4(1.0, 0.85, 0.52, 1.0);
uniform bool selected = false;

void fragment() {
	vec2 grid = floor(UV * 96.0) + 0.5;
	vec2 edge = min(grid, 96.0 - grid);
	float near_edge = min(edge.x, edge.y);
	float corner = max(edge.x, edge.y);
	float reach = selected ? 23.0 : 14.0;
	float brace = (1.0 - step(3.0, near_edge)) * (1.0 - step(reach, corner));
	float inner_line = step(5.0, near_edge) * (1.0 - step(6.0, near_edge)) * (1.0 - step(10.0, corner));
	float seam = (1.0 - step(1.0, near_edge)) * (selected ? 0.48 : 0.18);
	float breath = 0.90 + 0.10 * sin(TIME * 2.8);
	ALBEDO = ink.rgb * (0.83 + 0.17 * breath);
	ALPHA = max(brace, max(seam, inner_line * 0.7)) * breath;
}
