shader_type spatial;
render_mode cull_disabled;

uniform vec4 finish : source_color = vec4(1.0);
varying vec3 local_point;
varying vec4 enamel;

void vertex() {
	local_point = VERTEX;
	enamel = COLOR;
}

void fragment() {
	vec3 grain_cell = floor(local_point * 61.0);
	float fleck = fract(dot(fract(grain_cell * vec3(.1031, .11369, .13787)), vec3(13.13, 32.71, 18.73)));
	vec3 base = enamel.rgb;
	if (!OUTPUT_IS_SRGB) {
		base = mix(base / 12.92, pow((base + .055) / 1.055, vec3(2.4)), step(vec3(.04045), base));
	}
	ALBEDO = base * finish.rgb * (0.93 + 0.10 * step(.65, fleck));
	EMISSION = ALBEDO * (0.085 + 0.48 * enamel.a);
	ROUGHNESS = 0.72;
}

void light() {
	float lambert = max(0.0, dot(NORMAL, LIGHT));
	float band = floor(lambert * 6.0 + .32) / 6.0;
	float glint = smoothstep(.954, .983, max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0));
	DIFFUSE_LIGHT += (band * .87 + lambert * .13 + glint * .09) * LIGHT_COLOR * ATTENUATION / PI;
}
