shader_type canvas_item;
render_mode unshaded;
uniform vec4 glimmer : source_color = vec4(0.43, 0.76, 0.77, 1.0);

void fragment() {
    float progress = COLOR.a;
    vec2 pixel = floor(FRAGCOORD.xy / 4.0) * 4.0 * SCREEN_PIXEL_SIZE;
    float cut = pixel.x * 0.76 + pixel.y * 0.24;
    float front = mix(-0.16, 1.18, progress) - cut;
    float ink = smoothstep(-0.055, 0.14, front);
    float seam = smoothstep(-0.04, 0.018, front) * (1.0 - smoothstep(0.018, 0.07, front));
    vec3 paint = mix(vec3(0.033, 0.055, 0.098), glimmer.rgb, 0.36 * seam);
    COLOR = vec4(paint, ink);
}
