shader_type spatial;
render_mode specular_disabled;

// UV2.x selects stone/bark, live foliage or a luminous mineral. The second
// coordinate is a bend weight authored at the growing tips of each specimen.
varying vec3 grain_coord;
varying float tissue;
varying vec3 ink;

float grain(vec3 cell) {
	cell = fract(cell * 0.1031);
	cell += dot(cell, cell.yzx + 33.33);
	return fract((cell.x + cell.y) * cell.z);
}

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	grain_coord = world;
	tissue = UV2.x;
	ink = COLOR.rgb;
	float gust = sin(dot(world.xz, vec2(0.72, 0.35)) + TIME * 1.18)
		+ 0.32 * sin(world.y * 2.5 - TIME * 1.67);
	VERTEX.x += UV2.y * gust * 0.045;
	VERTEX.z += UV2.y * gust * 0.029;
}

void fragment() {
	vec3 cell = floor(grain_coord * vec3(9.0, 12.0, 9.0));
	float wide = grain(floor(cell / vec3(3.0, 4.0, 3.0)));
	float fleck = grain(cell);
	// Joint cliffs have elongated fractures; leaf clusters have short,
	// horizontal flecks of light caught by the upper needles and fronds.
	float fiber = grain(floor(cell / vec3(1.0, 5.0, 1.0)));
	float leaf = step(0.85, tissue) * (1.0 - step(1.6, tissue));
	float dapple = mix(0.96 + 0.08 * step(0.52, wide) - 0.13 * step(0.85, fiber),
		0.88 + 0.14 * step(0.44, wide) + 0.16 * step(0.86, fleck), leaf);
	float screen_detail = 1.0 - smoothstep(0.075, 0.20, max(length(dFdx(grain_coord)), length(dFdy(grain_coord))));
	vec3 coat = ink * mix(1.0, dapple, screen_detail);
	ALBEDO = coat;
	ROUGHNESS = 1.0;
	if (tissue > 1.6) {
		EMISSION = ink * (0.42 + 0.09 * sin(TIME * 1.65 + grain_coord.y));
	}
}

void light() {
	float incidence = max(0.0, dot(NORMAL, LIGHT));
	// Keep five broad cuts in the light while easing their boundaries.
	// Dynamic shadow maps and local light attenuation still act on every cut.
	float cuts = incidence * 5.0;
	float stepped = (floor(cuts) + smoothstep(0.40, 0.63, fract(cuts))) * 0.2;
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * mix(incidence, stepped, 0.64) / PI;
}
