shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float bloom_strength = 0.10;
void fragment() {
	vec2 size = vec2(textureSize(screen_texture, 0));
	// Keep native-resolution silhouettes and material edges. Pixel clusters belong in the artwork.
	vec2 uv = SCREEN_UV;
	vec3 base = texture(screen_texture, uv).rgb;
	vec3 bloom = vec3(0.0);
	for (int x = -2; x <= 2; x++) {
		for (int y = -2; y <= 2; y++) {
			vec3 c = texture(screen_texture, uv + vec2(float(x),float(y)) * 3.0 / size).rgb;
			bloom += max(c - vec3(0.88), vec3(0.0)) / 25.0;
		}
	}
	vec3 color = base + bloom * bloom_strength;
	float shade = 1.0 - smoothstep(0.24, 0.79, distance(SCREEN_UV, vec2(0.5))) * 0.23;
	color *= shade;
	color += vec3(0.012, 0.006, 0.025) * (1.0 - dot(base,vec3(0.333)));
	COLOR = vec4(color, 1.0);
}
