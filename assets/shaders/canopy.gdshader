shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D canopy : source_color, filter_nearest_mipmap, repeat_disable;

void vertex() {
    vec3 origin = MODEL_MATRIX[3].xyz;
    vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x, 0.0, INV_VIEW_MATRIX[0].z));
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 front = cross(right, up);
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(front, 0.0), vec4(origin, 1.0));
    float breeze = sin(origin.x * 0.57 + origin.z * 0.31 - TIME * 1.14);
    float gust = breeze + 0.36 * sin(TIME * 2.23 + origin.z);
    VERTEX.x += max(0.0, VERTEX.y) * 0.020 * gust;
}

void fragment() {
    vec4 leaf = texture(canopy, UV);
    ALBEDO = leaf.rgb;
    ALPHA = leaf.a;
    ALPHA_SCISSOR_THRESHOLD = 0.50;
}
