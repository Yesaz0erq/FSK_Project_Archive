shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D paint_0 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_1 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_2 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_3 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_4 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_5 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
uniform sampler2D paint_6 : source_color, filter_nearest_mipmap_anisotropic, repeat_disable;
// Each arm carries up to eleven lanes, ordered west to east in river space.
uniform float river_levels[22];
uniform ivec2 mouth_widths = ivec2(1,1);
uniform int district = 0;

varying vec3 ground;
varying vec3 face;

float water_level(float reach) {
	int arm = reach < 0.0 ? 0 : 1;
	int width = mouth_widths[arm];
	float lane = clamp((abs(reach) - 3.0) * float(width) - 0.5, 0.0, float(width - 1));
	int left = int(floor(lane));
	return mix(river_levels[arm*11+left], river_levels[arm*11+int(ceil(lane))], fract(lane));
}

void vertex() {
	if (abs(UV2.y) > 1.0) {
		float u = abs(UV2.y) - 3.0;
		float bank = 1.0 - smoothstep(0.0,0.5,max(-u,u-1.0));
		float level = water_level(UV2.y);
		float drop = level < 0.5 ? mix(-0.14,-0.08,level*2.0) : mix(-0.08,0.0,level*2.0-1.0);
		VERTEX.y += drop * bank * smoothstep(0.0,1.5,abs(VERTEX.z)-8.8);
	}
	ground = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	face = MODEL_NORMAL_MATRIX * NORMAL;
}

float hash21(vec2 x) {
	vec3 p = fract(vec3(x.xyx) * vec3(.1031,.1030,.0973));
	p += dot(p,p.yzx + 33.33);
	return fract((p.x+p.y)*p.z);
}
float noise2(vec2 p) {
	vec2 cell=floor(p), f=fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(cell),hash21(cell+vec2(1,0)),f.x),
		mix(hash21(cell+vec2(0,1)),hash21(cell+vec2(1,1)),f.x),f.y);
}

vec3 edge_paint(float which, vec2 uv) {
	if (which < 0.5) { return texture(paint_0,uv).rgb; }
	if (which < 1.5) { return texture(paint_1,uv).rgb; }
	if (which < 2.5) { return texture(paint_2,uv).rgb; }
	if (which < 3.5) { return texture(paint_3,uv).rgb; }
	if (which < 4.5) { return texture(paint_4,uv).rgb; }
	if (which < 5.5) { return texture(paint_5,uv).rgb; }
	return texture(paint_6,uv).rgb;
}

void fragment() {
	// Keep material coordinates continuous. Nearest sampling preserves the
	// painted texels; the GPU needs continuous UV derivatives to filter them
	// at the oblique camera angle as the field moves underneath it.
	vec2 p=ground.xz;
	float patches=noise2(p*0.13);
	float flecks=noise2(p*0.61);
	vec2 slot=vec2(float(district%2),floor(float(district)/2.0))*0.5+2.0/512.0;
	vec2 warped=p*vec2(0.085,0.11)+vec2(0.27*patches,0.19*flecks);
	vec2 uv=slot+(1.0-abs(mod(warped,2.0)-1.0))*(252.0/512.0);
	vec3 earth=texture(paint_0,uv).rgb;
	vec3 cover=texture(paint_1,uv).rgb;
	vec3 stone=texture(paint_4,uv).rgb;
	float slope=1.0-clamp(face.y,0.0,1.0);
	float vegetation=patches*0.75+flecks*0.25;
	float stream=0.0;
	float threshold=0.52;
	if(district==0) {threshold=0.32;}
	if(district==1) {threshold=0.80;}
	if(district==2) {
		earth=mix(earth,texture(paint_2,uv).rgb,0.80);
		threshold=0.82;
	}
	if(district==3) {threshold=0.58;}
	vec3 pigment=mix(earth,cover,smoothstep(threshold-0.08,threshold+0.07,vegetation));
	float strata=0.5+0.5*sin(ground.y*4.0+noise2(p*0.24)*3.0);
	stone*=0.85+0.16*step(0.50,strata);
	pigment=mix(pigment,stone,smoothstep(0.09,0.32,slope));
	// Small changes of value sit inside large coherent shapes; the geometry,
	// lighting and atmosphere still define the legibility of the landscape.
	pigment*=0.94+0.11*floor(5.0*flecks)/4.0;
	// Both banks are explicit mesh lines. Interpolate the source mouth's
	// water levels along this reach as the river meanders through the scene.
	float across=abs(UV2.y)-3.0;
	if (across>=0.0 && across<=1.0) {
		float level=water_level(UV2.y);
		vec2 flow=p*vec2(0.20,0.22)+vec2(patches*0.12,0.0);
		vec2 water_uv=slot+(1.0-abs(mod(flow,2.0)-1.0))*(252.0/512.0);
		vec4 shallow=texture(paint_6,water_uv);
		vec3 deep=texture(paint_3,water_uv).rgb;
		float edge_distance=min(across,1.0-across);
		float shore=smoothstep(0.015,0.11,edge_distance+(flecks-0.5)*0.035);
		float flooded=smoothstep(0.52,0.99,level);
		float wet=smoothstep(0.12,0.33,level)*mix(shore,1.0,flooded);
		pigment=mix(stone,mix(shallow.rgb,deep,flooded),wet);
		stream=wet*mix(0.4*smoothstep(0.24,0.85,shallow.a),1.0,flooded);
	}
	float margin=max(abs(ground.x),abs(ground.z))-8.8;
	float transition=smoothstep(0.03,2.25+0.60*patches,margin);
	if(UV2.x > -0.5){
		vec3 border=edge_paint(UV2.x,UV);
		pigment=mix(border,pigment,transition);
		float edge_stream=1.0-step(0.4,abs(UV2.x-3.0));
		if(UV2.x > 5.5){ edge_stream=0.4*smoothstep(0.24,0.85,texture(paint_6,UV).a); }
		stream=mix(edge_stream,stream,transition);
	}
	// Only the animated glints snap to world-space pixels. Use the same
	// spacing and phase as the river parcels at the edge of the field.
	vec2 ripple=floor(p*32.0)/32.0;
	float wave=sin(ripple.y*13.6-TIME*1.54+sin(ripple.x*3.8+TIME*0.41));
	float window=sin(ripple.x*3.2+sin(ripple.y*2.7+TIME*.26))*.5+.5;
	float sheen=smoothstep(.78,.99,wave)*smoothstep(.35,.94,window);
	ALBEDO=pigment;
	EMISSION=vec3(.085,.18,.185)*stream*sheen;
	ROUGHNESS=mix(0.96,0.66,stream);
	SPECULAR=0.18;
}
