// Deep space: a dusk-violet gradient with three layers of twinkling stars.
shader_type sky;

uniform vec3 top : source_color = vec3(0.05, 0.05, 0.12);
uniform vec3 horizon : source_color = vec3(0.16, 0.12, 0.26);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir, float scale, float threshold, float t) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	float h = hash(cell);
	vec3 center = cell + 0.5 + (vec3(hash(cell + 1.7), hash(cell + 3.1), hash(cell + 5.3)) - 0.5) * 0.6;
	float d = length(p - center);
	float twinkle = 0.7 + 0.3 * sin(t * (1.0 + h * 3.0) + h * 40.0);
	return step(threshold, h) * smoothstep(0.12, 0.0, d) * twinkle;
}

void sky() {
	vec3 col = mix(horizon, top, smoothstep(-0.2, 0.7, EYEDIR.y));
	float s = stars(EYEDIR, 60.0, 0.9, TIME) + stars(EYEDIR, 140.0, 0.93, TIME) * 0.7
		+ stars(EYEDIR, 300.0, 0.95, TIME) * 0.5;
	COLOR = col + vec3(1.0, 0.95, 0.85) * s;
}
