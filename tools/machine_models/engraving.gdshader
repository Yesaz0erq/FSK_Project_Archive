shader_type spatial;
render_mode unshaded, cull_disabled, depth_test_disabled, depth_draw_never, fog_disabled;
uniform sampler2D paint : hint_screen_texture, filter_nearest, repeat_disable;
uniform sampler2D scene_z : hint_depth_texture, filter_nearest, repeat_disable;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float depth_at(vec2 uv) {
	// The bake camera is orthographic, between 0.1 and 18 world units.
	return textureLod(scene_z, uv, 0.0).r * 17.9;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 pixel = 1.0 / VIEWPORT_SIZE;
	float z = depth_at(uv);
	vec3 base = textureLod(paint,uv,0.0).rgb;
	float cavity = 0.0;
	float nearby = 0.0;
	float border = 0.0;
	for (int i=0; i<8; i++) {
		float angle = float(i) * 0.785398;
		vec2 dir = vec2(cos(angle),sin(angle));
		float edge = depth_at(uv + dir * pixel);
		float reach = depth_at(uv + dir * pixel * max(2.0, VIEWPORT_SIZE.y * 0.014));
		nearby = max(nearby,edge);
		border += float(edge < 0.01);
		// A nearby lip or screw head casts a cool crease onto the part just behind it.
		cavity += smoothstep(0.028,0.21,edge-z) * 0.070;
		cavity += smoothstep(0.08,0.36,reach-z) * (1.0-smoothstep(0.75,1.8,reach-z)) * 0.038;
	}
	if (z < 0.01) {
		if (nearby < 0.01) discard;
		ALBEDO = vec3(0.078,0.109,0.146);
		ALPHA = 0.76;
	} else {
		vec3 ink = vec3(0.044,0.075,0.116);
		float edge_ink = smoothstep(2.0,5.0,border) * 0.20;
		ALBEDO = mix(base, ink, clamp(cavity + edge_ink,0.0,0.64));
		ALPHA = 1.0;
	}
}
