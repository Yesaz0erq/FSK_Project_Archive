shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D pigment : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 sky_fill : source_color = vec4(0.36, 0.50, 0.73, 1.0);
uniform float is_wall = 0.0;
varying vec3 world;

void vertex() {
    world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    // Fold the cropped painting at the seams; the strata and moss meet on both edges.
    vec2 uv = vec2(1.0) - abs(mod(UV, vec2(2.0)) - vec2(1.0));
    vec3 paint = texture(pigment, uv).rgb;
    vec2 p = floor(world.xz * 16.0) / 16.0;
    float shade = sin(dot(p, vec2(0.53, -0.36)) + sin(p.y * 0.72 + TIME * 0.14) * 1.4);
    float light_patch = smoothstep(0.17, 0.72, shade);
    float foot = mix(1.0, mix(0.56, 1.0, smoothstep(-3.5, -0.6, world.y)), is_wall);
    ALBEDO = paint * mix(0.82, 1.02, light_patch) * foot;
    EMISSION = paint * (sky_fill.rgb * 0.30 + 0.08) * foot;
    ROUGHNESS = 1.0;
}
