// The tea nook, painted in one pass: a warm wall, a round window onto Bramble and the stars,
// and a wooden sill catching the light.
shader_type canvas_item;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(41.3, 289.1))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 p = UV * res;
	float aspect = res.x / res.y;
	vec3 wall = mix(vec3(0.93, 0.78, 0.6), vec3(0.82, 0.6, 0.45), UV.y);
	wall *= 0.96 + 0.04 * sin(p.x * 0.05);

	vec2 c = vec2(0.73 * res.x, 0.42 * res.y);
	float r = 0.3 * res.y;
	float d = length(p - c);
	vec3 col = wall;
	if (d < r) {
		vec2 w = (p - c) / r;
		vec3 space = mix(vec3(0.16, 0.12, 0.26), vec3(0.05, 0.05, 0.12), w.y * 0.5 + 0.5);
		vec2 cell = floor(p / 3.0);
		float star = step(0.995, hash(cell)) * (0.6 + 0.4 * sin(TIME * 2.0 + hash(cell) * 30.0));
		space += vec3(star);
		vec2 g = w - vec2(-0.35, 0.45);
		float gd = length(g);
		if (gd < 0.75) {
			float band = sin((g.y + 0.06 * sin(g.x * 6.0 + TIME * 0.05)) * 18.0);
			vec3 planet = mix(vec3(0.24, 0.56, 0.58), vec3(0.45, 0.36, 0.62), smoothstep(-0.4, 0.4, band));
			planet = mix(planet, vec3(0.93, 0.78, 0.6), smoothstep(0.7, 0.95, sin(g.y * 7.0 + 1.0)));
			planet *= mix(0.25, 1.0, smoothstep(-0.2, 0.4, dot(normalize(g + 0.001), vec2(0.6, -0.5)) + 0.3));
			space = mix(space, planet, smoothstep(0.75, 0.73, gd));
		}
		col = space;
	}
	float frame = smoothstep(r - 2.0, r, d) - smoothstep(r + 18.0, r + 20.0, d);
	col = mix(col, vec3(0.55, 0.38, 0.26), frame);
	float sill = step(0.82, UV.y);
	col = mix(col, vec3(0.6, 0.4, 0.27) * (1.0 - 0.1 * step(0.84, UV.y)), sill);
	col += vec3(1.0, 0.8, 0.5) * 0.08 * smoothstep(r * 2.2, 0.0, d);
	COLOR = vec4(col, 1.0);
}
