shader_type spatial;
render_mode unshaded, shadows_disabled, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 ink : source_color = vec4(.085,.065,.14,1.);
uniform vec4 shade_tint : source_color = vec4(.10,.13,.24,1.);
uniform vec2 cloud_phase;
uniform float cloud_opacity = .25;

float cloud_hash(vec2 cell) {
	vec3 p = fract(cell.xyx * vec3(.1031,.1030,.0973));
	p += dot(p, p.yzx+33.33);
	return fract((p.x+p.y)*p.z);
}

float cloud_cover(vec2 p) {
	vec2 cell = floor(p), t = fract(p);
	t = t*t*(3.-2.*t);
	return mix(mix(cloud_hash(cell),cloud_hash(cell+vec2(1,0)),t.x),
	           mix(cloud_hash(cell+vec2(0,1)),cloud_hash(cell+1.),t.x),t.y);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1., 1.);
}

void fragment() {
	// In an orthographic view, reversed depth differences scale linearly to metres.
	// Put ink on the occluded side of a silhouette. The second difference drops
	// flat slopes, so stone markings, small pixel clusters and water stay intact.
	vec2 step_uv = clamp(round(VIEWPORT_SIZE.y / 750.), 1., 3.) / VIEWPORT_SIZE;
	float here = texture(scene_depth, SCREEN_UV).r;
	float x0 = texture(scene_depth, SCREEN_UV - vec2(step_uv.x,0.)).r - here;
	float x1 = texture(scene_depth, SCREEN_UV + vec2(step_uv.x,0.)).r - here;
	float y0 = texture(scene_depth, SCREEN_UV - vec2(0.,step_uv.y)).r - here;
	float y1 = texture(scene_depth, SCREEN_UV + vec2(0.,step_uv.y)).r - here;
	float relief = max(x0+x1, y0+y1) * abs(INV_PROJECTION_MATRIX[2][2]) * (1.-CLIP_SPACE_FAR);
	float line = .69 * smoothstep(.13,.80,relief);
	// Project slow cloud shadows through the scene. A tree crown, a moving
	// machine and the ground below it cross the same patch of light.
	vec3 ndc = vec3(SCREEN_UV*2.-1.,mix(CLIP_SPACE_FAR,1.,here));
	vec4 eye = INV_PROJECTION_MATRIX * vec4(ndc,1.);
	vec3 world = (INV_VIEW_MATRIX * vec4(eye.xyz/eye.w,1.)).xyz;
	vec2 p = floor((world.xz + world.y*vec2(.64,-.53))*24.)/24.;
	p = p*vec2(.125,.085) + cloud_phase + TIME*vec2(.009,.003);
	float veil = cloud_cover(p)*.74 + cloud_cover(p*2.32)*.26;
	float shade = (.65*smoothstep(.38,.51,veil) + .35*smoothstep(.54,.62,veil))
	              * cloud_opacity * step(.0001,here);
	float opacity = line+shade*(1.-line);
	ALBEDO = mix(shade_tint.rgb,ink.rgb,line/max(opacity,.00001));
	ALPHA = opacity;
}
