shader_type canvas_item;
render_mode unshaded;

uniform sampler2D landscape : source_color, filter_nearest, repeat_disable;
uniform int district = 0;
uniform vec2 drift = vec2(0.0);
uniform vec4 weather_tint : source_color = vec4(1.0);

void fragment() {
    vec2 size = vec2(textureSize(landscape, 0));
    float image_aspect = size.x / size.y;
    float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
    vec2 crop = vec2(min(1.0, aspect / image_aspect), min(1.0, image_aspect / aspect));
    vec2 uv = (UV - 0.5) * crop * 0.94 + 0.5 + drift;
    vec2 pixel = floor(uv * size / 2.0) * 2.0 / size;
    if (district == 1 || district == 2) {
        float haze = smoothstep(0.26, 0.47, uv.y) * (1.0 - smoothstep(0.58, 0.74, uv.y));
        uv.x += sin(pixel.y * 114.0 + TIME * 1.04 + sin(pixel.x * 26.0)) * haze * 0.00085;
    }
    vec3 sky = texture(landscape, uv).rgb;
    if (district == 2) {
        float ember = smoothstep(0.24, 0.65, sky.r - sky.b);
        sky += vec3(0.08, 0.027, 0.002) * ember * (0.5 + 0.5 * sin(pixel.x * 16.0 - TIME * 1.25));
    } else {
        float light = sin(pixel.x * 36.0 - pixel.y * 17.0 + TIME * 0.37 + sin(pixel.x * 16.0));
        float gate = smoothstep(0.34, 0.83, max(sky.g, sky.r));
        sky *= 1.0 + gate * light * (district == 3 ? 0.045 : 0.026);
    }
    COLOR = vec4(sky * weather_tint.rgb, 1.0);
}
