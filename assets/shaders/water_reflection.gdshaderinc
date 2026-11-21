// The river and its playable parcels share the same world-anchored pixel strokes.
float water_glint(vec2 world_xz, float time) {
	vec2 p = floor(world_xz * vec2(27.0, 34.0)) / vec2(27.0, 34.0);
	float crest = sin(p.y * 12.3 - time * 1.46 + sin(p.x * 3.1 + time * .36));
	float openings = sin(p.x * 3.0 - p.y * .42 + sin(p.y * 2.4 + time * .24)) * .5 + .5;
	float cap = smoothstep(.79, .97, crest) * smoothstep(.52, .82, openings);
	float glimmer = smoothstep(.96, 1.0, crest) * smoothstep(.75, .93, openings);
	return cap * .58 + glimmer * .42;
}
