shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform sampler2D opaque_scene : hint_screen_texture, repeat_disable, filter_nearest;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 deep_color : source_color = vec4(0.04, 0.13, 0.22, 1.0);
uniform vec4 reflection_color : source_color = vec4(0.76, 0.43, 0.63, 1.0);
uniform vec4 sky_color : source_color = vec4(0.28, 0.66, 0.70, 1.0);
uniform float ice_cover : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D painted_flow : source_color, repeat_disable, filter_nearest_mipmap;
uniform int district = 0;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float view_depth(vec2 uv, mat4 inverse_projection) {
	float z = textureLod(scene_depth, uv, 0.0).r;
	vec4 clip = vec4(uv * 2.0 - 1.0, mix(CLIP_SPACE_FAR, 1.0, z), 1.0);
	vec4 view = inverse_projection * clip;
	return -view.z / view.w;
}

void fragment() {
	// Cluster the wave normals in world space, so the pixels remain on the surface as the camera turns.
	vec2 p = floor(world.xz * 18.0) / 18.0;
	float phase = dot(p, vec2(1.05, 4.8)) + TIME * 1.02 + sin(p.x * 1.3 - TIME * 0.31);
	float swell = sin(phase) + 0.36 * sin(phase * 1.63 + p.x);
	vec3 wave_normal = normalize(vec3(0.07 * cos(p.x * 2.1 + TIME * 0.62), 1.0, 0.15 * swell));
	wave_normal = normalize(mix(wave_normal, vec3(0.0, 1.0, 0.0), ice_cover * 0.85));
	vec3 ray = reflect(-VIEW, mat3(VIEW_MATRIX) * wave_normal);
	float ribbon = smoothstep(0.16, 0.86, sin(p.x * 0.62 + p.y * 0.32 + 0.68 * swell));
	vec3 sky = mix(sky_color.rgb, reflection_color.rgb, ribbon);
	vec3 reflected = mix(deep_color.rgb, sky, 0.34 + 0.19 * ribbon);
	// Short screen-space reflection ray. Offscreen scenery falls back to the painted sky.
	for (int i = 0; i < 8; i++) {
		float stride = 0.46 + float(i) * 0.32;
		vec3 probe = VERTEX + ray * (0.40 + (float(i) + 1.0) * stride);
		vec4 clip = PROJECTION_MATRIX * vec4(probe, 1.0);
		vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
		if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) { break; }
		float behind = -probe.z - view_depth(uv, INV_PROJECTION_MATRIX);
		if (behind >= 0.0 && behind < 0.45 + stride * 1.7) {
			vec2 edge = min(uv, 1.0 - uv);
			float weight = smoothstep(0.0, 0.07, min(edge.x, edge.y));
			reflected = mix(reflected, textureLod(opaque_scene, uv, 0.0).rgb, weight * 0.75);
			break;
		}
	}
	float glint = smoothstep(0.96, 1.05, swell) * smoothstep(0.45, 0.95, ribbon);
	vec3 color = mix(deep_color.rgb, reflected, 0.82) + sky_color.rgb * glint * 0.36;
	float ice_shelf = smoothstep(0.45, 0.52, sin(p.x * 0.76 + 0.42 * sin(p.y)) * cos(p.y * 0.71));
	color = mix(color, mix(sky_color.rgb, vec3(0.72, 0.85, 0.97), 0.18 + 0.30 * ice_shelf), ice_cover * 0.42);
	// The same district pigments continue beyond the last playable water tile.
	vec2 atlas_cell = vec2(float(district % 2), floor(float(district) / 2.0));
	vec2 sample_uv = 1.0 - abs(mod(p * vec2(0.14, 0.11) + wave_normal.xz * 0.025, vec2(2.0)) - vec2(1.0));
	vec3 painted = texture(painted_flow, atlas_cell * 0.5 + 0.004 + sample_uv * 0.492).rgb;
	ALBEDO = mix(painted, color, 0.29) + glint * sky_color.rgb * 0.20;
	ALPHA = 1.0;
}
