shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform vec4 deep : source_color;
uniform vec4 crest : source_color;
void fragment() {
    vec2 uv = floor(UV * vec2(110.0, 140.0)) / vec2(110.0, 140.0);
    float ribs = 0.5 + 0.5 * sin(uv.x * 56.0 + 1.7 * sin(uv.x * 16.0));
    float strand = 0.5 + 0.5 * sin(uv.x * 153.0 + 0.6 * sin(uv.y * 8.0 - TIME * 2.2));
    float trail = fract(uv.y * 2.7 - TIME * 0.79 + 0.81 * sin(uv.x * 89.0));
    float lip = 1.0 - smoothstep(0.00, 0.09, uv.y);
    float bright = 0.55 * ribs + 0.30 * smoothstep(0.68, 0.79, strand) * smoothstep(0.18, 0.89, trail);
    ALBEDO = mix(deep.rgb, crest.rgb, min(1.0, bright + lip * 0.40));
    float tip = 0.71 + 0.19 * ribs + 0.09 * strand;
    ALPHA = (1.0 - smoothstep(tip - 0.22, tip, uv.y)) * (0.76 + 0.15 * ribs);
}
