shader_type spatial;
render_mode unshaded, cull_disabled;
uniform vec4 deep_color : source_color = vec4(0.035,0.10,0.18,1.0);
uniform vec4 reflection_color : source_color = vec4(0.68,0.30,0.57,1.0);
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.54);}
void fragment(){
	vec2 p=floor(world.xz*12.0)/12.0;
	float ripple=sin(p.y*9.0+TIME*0.7+sin(p.x*2.3))*0.5+0.5;
	float column=pow(max(0.0,1.0-abs(sin(p.x*0.43+sin(p.y*0.6)*0.25))),4.0);
	float sparkle=step(0.94,hash(floor(p*vec2(2.0,5.0))+floor(TIME*0.6)))*0.16;
	vec3 reflected=reflection_color.rgb*column*step(0.52,ripple)*0.65;
	ALBEDO=deep_color.rgb+reflected+vec3(0.12,0.32,0.36)*sparkle;
}
