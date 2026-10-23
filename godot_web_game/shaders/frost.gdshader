// Frosted translucent glass for the tablet: a cheap blur of what's behind, tinted and edged.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform vec4 tint : source_color = vec4(0.78, 0.92, 0.95, 0.42);
uniform float blur = 10.0;
uniform float corner = 28.0;
uniform vec2 rect_size = vec2(800.0, 500.0);

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * blur;
	vec3 acc = vec3(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float w = 1.0 - length(vec2(float(x), float(y))) / 4.5;
			acc += texture(screen, SCREEN_UV + vec2(float(x), float(y)) * px / 3.0).rgb * w;
			total += w;
		}
	}
	vec3 behind = acc / total;
	vec2 size = rect_size;
	vec2 p = UV * size;
	vec2 q = abs(p - size * 0.5) - (size * 0.5 - corner);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner;
	float edge = smoothstep(-3.0, -1.0, d) - smoothstep(-1.0, 0.5, d);
	float sheen = smoothstep(0.0, 1.0, 1.0 - UV.y) * 0.08 + smoothstep(0.35, 0.0, abs(UV.x - UV.y * 0.6 - 0.2)) * 0.05;
	vec3 col = mix(behind, tint.rgb, tint.a) + sheen + edge * 0.5;
	COLOR = vec4(col, step(d, 0.0));
}
