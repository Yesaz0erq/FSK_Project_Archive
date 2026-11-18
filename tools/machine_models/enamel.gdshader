shader_type spatial;
render_mode cull_disabled, ambient_light_disabled;

uniform vec4 pigment : source_color = vec4(1.0);
uniform bool luminous = false;
varying vec3 surface_pos;
varying vec3 normal_world;

float hash3(vec3 p) {
	p = fract(p * vec3(.1031,.11369,.13787));
	p += dot(p, p.yxz + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0 - 2.0*f);
	return mix(mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),
		mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y),
		mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),
		mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1)),f.x),f.y),f.z);
}

void vertex() {
	// Attach the stipple to the moving part and keep its frequency in world units.
	surface_pos = VERTEX * vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	normal_world = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 p = floor(surface_pos * 63.0) / 63.0;
	float grain = noise3(p * 24.0 + 13.7);
	float field = noise3(p * vec3(5.5, 7.2, 5.5) + 9.2) * 0.74 + grain * 0.26;
	float mottling = floor(field * 7.0) / 6.0 - 0.5;
	vec3 base = pigment.rgb;
	bool metal = base.r > base.b * 1.28 && base.g > base.r * 0.62 && base.g < base.r * 0.93;
	bool foliage = base.g > base.r * 1.10 && base.g > base.b * 1.08;
	if (!luminous) {
		base *= 0.95 + 0.43 * mottling;
		if (metal) {
			// Cool oxidation pockets break up copper bands; the burnished metal survives at their edges.
			float patina = smoothstep(0.55,0.72,field);
			base = mix(base, vec3(0.16,0.40,0.38) * (0.8 + 0.3 * grain), patina * 0.65);
			base += vec3(0.09,0.06,0.025) * step(0.82, grain);
		} else if (foliage) {
			float vein = sin((p.x + p.z) * 42.0 + p.y * 21.0 + noise3(p * 3.1) * 3.0);
			base *= 1.0 - 0.20 * smoothstep(0.77,0.96,vein);
			base += vec3(0.075,0.070,0.008) * smoothstep(0.57,0.78,field);
		} else {
			float brush = noise3(p * vec3(12.0,46.0,10.0));
			base += vec3(0.056,0.031,0.013) * step(0.74,brush);
		}
	}
	ALBEDO = base;
	float facing = 1.0 - abs(dot(normalize(NORMAL), VIEW));
	float sky = 0.5 + 0.5 * normal_world.y;
	EMISSION = base * mix(vec3(0.15,0.23,0.34), vec3(0.34,0.40,0.48),sky) + vec3(0.018,0.024,0.049);
	EMISSION += vec3(0.03,0.061,0.080) * smoothstep(0.69,0.98,facing) * sky;
	if (luminous) { EMISSION += pigment.rgb * 0.58; }
}

void light() {
	float lambert = max(dot(NORMAL, LIGHT), 0.0);
	float bands = floor(lambert * 6.0 + 0.35) / 6.0;
	float key = mix(bands, lambert, 0.20);
	float gloss = max(dot(NORMAL, normalize(LIGHT + VIEW)), 0.0);
	float highlight = smoothstep(0.955, 0.988, gloss) * 0.12;
	DIFFUSE_LIGHT += LIGHT_COLOR / PI * ATTENUATION * (key * 0.85 + highlight);
}
