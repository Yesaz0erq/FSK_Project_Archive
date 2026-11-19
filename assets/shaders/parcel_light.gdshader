shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;

uniform int family = 0;
uniform vec4 reflected_sky : source_color = vec4(0.64, 0.88, 0.87, 1.0);
uniform sampler2D paint : filter_nearest_mipmap_anisotropic, repeat_disable;
uniform vec2 atlas_corner;
uniform vec2 atlas_span;
varying vec2 ground;

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	// Hold the shape of each painted cluster while its brightness eases through the crest.
	vec2 p = floor(ground * 32.0) / 32.0;
	float strength;
	vec3 pigment = reflected_sky.rgb;
	if (family < 2 || family == 4) {
		float wave = sin(p.y * 13.6 - TIME * 1.54 + sin(p.x * 3.8 + TIME * 0.41));
		float window = sin(p.x * 3.2 + sin(p.y * 2.7 + TIME * .26)) * .5 + .5;
		float streak = smoothstep(.78, .99, wave) * smoothstep(.35, .94, window);
		float wide = .5 + .5 * sin(p.x * 1.12 + p.y * .5 + TIME * .21);
		strength = streak * (.12 + .30 * wide);
		if (family == 4) {
			float depth = texture(paint, atlas_corner + UV * atlas_span).a;
			strength *= .52 * smoothstep(.24, .85, depth);
		}
		if (family == 1) {
			float pool = length((UV - vec2(.5)) / vec2(.410, .347));
			strength *= 1.0 - smoothstep(.75, .87, pool);
		}
	} else if (family == 2) {
		vec3 rock = texture(paint, atlas_corner + UV * atlas_span).rgb;
		float vein = smoothstep(.07, .2, rock.r - rock.b);
		float ember = .56 + .44 * sin(TIME * .83 + p.x * 3.7 - p.y * 1.8);
		strength = vein * ember * .32;
		pigment = vec3(1.0, .34, .15);
	} else {
		vec3 moss = texture(paint, atlas_corner + UV * atlas_span).rgb;
		float blade = smoothstep(.50, .76, moss.g);
		float gust = sin(p.x * 2.7 + p.y * 1.6 - TIME * 1.03 + sin(p.y + TIME * .21));
		strength = blade * smoothstep(.68, 1.0, gust) * .115;
	}
	ALBEDO = pigment;
	ALPHA = strength;
}
