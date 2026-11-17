shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 glow_color : source_color = vec4(1.0,0.48,0.15,0.22);
uniform bool beam = false;
void fragment(){
	vec2 p=UV-vec2(0.5);
	float a=pow(max(0.0,1.0-length(p*2.0)),2.0);
	if(beam){
		float width=mix(0.12,0.48,UV.y);
		a=smoothstep(width,width*0.65,abs(p.x))*sin(UV.y*3.14159)*0.32;
		a*=0.8+0.2*sin(floor(UV.x*90.0)+TIME*0.15);
	}
	ALBEDO=glow_color.rgb;
	ALPHA=a*glow_color.a;
}
