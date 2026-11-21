shader_type spatial;
render_mode specular_disabled;

uniform sampler2D albedo_plates : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
varying vec2 paint_uv;
varying flat float plate;
varying float face_value;
varying float sky_facing;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz;
	vec3 axis = abs(NORMAL);
	bool cap = axis.y > max(axis.x,axis.z);
	paint_uv = cap ? VERTEX.xz : (axis.x > axis.z ? vec2(VERTEX.z,-VERTEX.y) : vec2(VERTEX.x,-VERTEX.y));
	if (cap && UV.x > .5) { paint_uv = paint_uv.yx; }
	plate = floor(UV2.x + .5);
	// Sculpt values locate recessed walls and upper ledges in the painting.
	// All hues and material patterns come from opaque, full-colour plates.
	face_value = dot(COLOR.rgb,vec3(.27,.56,.17));
	sky_facing = (MODEL_NORMAL_MATRIX * NORMAL).y;
	float gust = sin(dot(world.xz,vec2(.72,.35)) + TIME*1.18) + .32*sin(world.y*2.5 - TIME*1.67);
	VERTEX.xz += vec2(.045,.029) * gust * UV2.y;
}

void fragment() {
	vec2 density = vec2(.62);
	if (plate == 1.) { density = vec2(.68,.74); }
	if (plate == 2. || plate == 11. || plate == 13. || plate == 15.) { density = vec2(1.65); }
	if (plate == 3.) { density = vec2(.94,.54); }
	if (plate == 4.) { density = vec2(.46,.60); }
	if (plate == 5.) { density = vec2(.91,.43); }
	if (plate == 7. || plate == 14.) { density = vec2(.69,1.58); }
	if (plate == 9. || plate == 10.) { density = vec2(1.08,.95); }
	vec2 p = paint_uv*density;
	// Reverse alternating plates. The two repeated borders protect the hue
	// of each painting when the GPU selects a smaller mip during a pan.
	vec2 fold = 1.0 - abs(mod(p,2.0) - 1.0);
	vec2 origin = vec2(mod(plate,4.),floor(plate*.25))*.25;
	vec2 atlas_uv = origin + (16.5 + fold*31.)/256.;
	vec2 dx = clamp(dFdx(p)*31.,vec2(-12.),vec2(12.))/256.;
	vec2 dy = clamp(dFdy(p)*31.,vec2(-12.),vec2(12.))/256.;
	vec3 paint = textureGrad(albedo_plates, atlas_uv, dx, dy).rgb;
	float value = clamp(.80 + .48*face_value,.80,1.18);
	float overhead = smoothstep(-.38,.62,sky_facing);
	ALBEDO = paint * value * mix(vec3(.80,.84,.98),vec3(1.04,1.025,.99),overhead);
	ROUGHNESS = 1.;
	if (plate == 2. || plate == 8.) {
		float vein = smoothstep(.18,.78,max(paint.r,max(paint.b,paint.g)));
		EMISSION = paint*vein*(.34 + .06*sin(TIME*1.47+paint_uv.y));
	}
}

void light() {
	float angle = max(0.,dot(NORMAL,LIGHT));
	float cut = .38*smoothstep(.06,.16,angle) + .34*smoothstep(.39,.49,angle) + .28*smoothstep(.75,.85,angle);
	vec3 temperature = mix(vec3(.91,.95,1.04),vec3(1.055,1.015,.94),cut);
	DIFFUSE_LIGHT += LIGHT_COLOR*ATTENUATION*temperature*mix(angle,cut,.77)/PI;
}
