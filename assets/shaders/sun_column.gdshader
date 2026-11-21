shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled;

uniform vec4 radiance : source_color;
uniform float seed = 0.0;
varying vec3 local_position;
varying flat mat3 view_to_column;

void vertex() {
	local_position = VERTEX;
	view_to_column = inverse(mat3(MODELVIEW_MATRIX));
}

// Integrate a soft cylinder along the camera ray. A shaft keeps its width
// and lighting direction when the orthographic camera travels around it.
void fragment() {
	vec3 ray = normalize(view_to_column * -VIEW);
	float a = max(dot(ray.xz, ray.xz), 0.00001);
	float b = dot(local_position.xz, ray.xz);
	float c = dot(local_position.xz, local_position.xz) - 1.0;
	float far_side = (-b + sqrt(max(0.0, b*b - a*c))) / a;
	float end_y = ray.y < 0.0 ? -1.0 : 1.0;
	float far_cap = abs(ray.y) > 0.0001 ? (end_y - local_position.y) / ray.y : 10000.0;
	float length_inside = clamp(min(far_side, far_cap), 0.0, 2.75);
	vec3 mid = local_position + ray * length_inside * 0.5;
	float core = max(0.0, 1.0 - dot(mid.xz, mid.xz));
	float vertical = max(0.0, 1.0 - mid.y*mid.y);
	// Gaps between leaves divide the shaft into a broad streak and fine slits.
	// Their positions are fixed in the volume as the camera travels.
	float opening = mid.z*.66 + mid.x*.74;
	float slit = sin(opening*14.0 + seed) + .38*sin(opening*27.0 - seed);
	float drift = (.46 + .54*smoothstep(-.31,.18,slit)) * (.94 + .06*sin(seed+TIME*.48));
	ALBEDO = radiance.rgb;
	ALPHA = radiance.a * core*core * vertical * length_inside * drift;
}
