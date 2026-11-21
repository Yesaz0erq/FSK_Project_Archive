shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;

uniform sampler2D paint : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform vec4 finish : source_color = vec4(1.0);
varying vec3 world_normal;
varying vec2 response;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	response = UV2;
}

void fragment() {
	// The painted UV rectangle belongs to the individual part before the
	// geometry is combined; all the joints therefore carry their own ink.
	vec3 pigment = texture(paint, UV).rgb * finish.rgb;
	float upward = clamp(normalize(world_normal).y * .5 + .5, 0., 1.);
	float grazing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = 1.0 - smoothstep(.055, .19, grazing);
	ALBEDO = pigment * (1.0 - .20 * edge);
	vec3 bounce = mix(vec3(.21,.21,.32), vec3(.30,.31,.37), smoothstep(.42,.60,upward));
	EMISSION = ALBEDO * (bounce + .34*response.y);
	ROUGHNESS = .82;
}

void light() {
	float facing = max(0.,dot(NORMAL,LIGHT));
	float band = .18*smoothstep(.04,.09,facing) + .37*smoothstep(.26,.33,facing)
		+ .30*smoothstep(.56,.64,facing) + .15*smoothstep(.81,.88,facing);
	DIFFUSE_LIGHT += band * mix(vec3(.85,.90,1.03),vec3(1.10,1.04,.95),band) * LIGHT_COLOR * ATTENUATION / PI;
	float gloss = max(0.,dot(NORMAL,normalize(LIGHT+VIEW)));
	float glint = .45*smoothstep(.939,.957,gloss) + .55*smoothstep(.982,.993,gloss);
	SPECULAR_LIGHT += glint * response.x * LIGHT_COLOR * ATTENUATION / PI;
}
