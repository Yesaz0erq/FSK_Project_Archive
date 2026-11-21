shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.15;
uniform vec4 shadow_color : source_color = vec4(0.16, 0.19, 0.34, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.85, 0.77, 1.0);

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

vec3 hot_pixel(vec2 uv) {
	vec3 c = textureLod(screen_texture, uv, 0.0).rgb;
	float brightness = mix(luminance(c), max(c.r, max(c.g, c.b)), 0.35);
	return c * smoothstep(0.76, 0.97, brightness);
}

void fragment() {
	// Preserve each rasterized pixel. The terrain art and faceted materials
	// supply the pixel shapes; grading only changes their colour.
	vec2 uv = SCREEN_UV;
	vec3 base = textureLod(screen_texture, uv, 0.0).rgb;
	float radius = clamp(round(1.0 / (540.0 * SCREEN_PIXEL_SIZE.y)), 1.0, 4.0);
	vec2 dx = vec2(SCREEN_PIXEL_SIZE.x * radius, 0.0);
	vec2 dy = vec2(0.0, SCREEN_PIXEL_SIZE.y * radius);
	vec3 glow = 0.25 * (hot_pixel(uv + dx) + hot_pixel(uv - dx)
		+ hot_pixel(uv + dy) + hot_pixel(uv - dy));
	float luma = luminance(base);
	// Steer shadow, body colour and glancing light separately, without
	// blurring the source or quantizing the luminance of a moving silhouette.
	float shade = 1.0 - smoothstep(0.09, 0.48, luma);
	float sunlit = smoothstep(0.37, 0.87, luma);
	vec3 color = mix(vec3(luma),base,1.08);
	color += (shadow_color.rgb - luminance(shadow_color.rgb)) * 0.21 * shade;
	color += (highlight_color.rgb - luminance(highlight_color.rgb)) * 0.13 * sunlit;
	color *= 1.0 - 0.095 * shade;
	color += vec3(0.032) * sunlit * (1.0 - luma);
	color += glow * bloom_strength * (1.0 - luma);
	color = mix(color, floor(color * 63.0 + 0.5) / 63.0, 0.36);
	vec2 perimeter = (uv - 0.5) * vec2(1.85, 1.65);
	color *= 1.0 - 0.11 * smoothstep(0.36, 1.15, dot(perimeter, perimeter));
	COLOR = vec4(color, 1.0);
}
