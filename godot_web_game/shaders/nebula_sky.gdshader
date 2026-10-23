// Race sky: drifting nebula clouds in teal, magenta and amber, a dusty galaxy band across the sky,
// and three layers of twinkling stars. Sky shaders can't read TIME inside helper functions, so
// the time is passed in.
shader_type sky;

uniform vec3 deep : source_color = vec3(0.02, 0.02, 0.07);
uniform vec3 cloud_a : source_color = vec3(0.1, 0.55, 0.6);
uniform vec3 cloud_b : source_color = vec3(0.75, 0.22, 0.6);
uniform vec3 cloud_c : source_color = vec3(1.0, 0.62, 0.3);
uniform vec3 band_axis = vec3(0.35, 0.85, 0.4);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
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

vec3 nebula(vec3 dir, float t) {
	vec3 p = dir * 2.2 + vec3(t * 0.004, 0.0, t * 0.003);
	float warp = fbm(p * 1.3);
	float n = fbm(p + warp * 1.6);
	float m = fbm(p * 2.1 + 4.0);
	vec3 col = mix(cloud_a, cloud_b, smoothstep(0.35, 0.7, m));
	col = mix(col, cloud_c, smoothstep(0.62, 0.85, n * m * 1.6));
	return col * smoothstep(0.38, 0.85, n) * 0.85;
}

void sky() {
	vec3 dir = EYEDIR;
	vec3 col = deep;
	col += nebula(dir, TIME);
	// The galaxy band: a bright, dust-laned strip around one great circle.
	float off = abs(dot(dir, normalize(band_axis)));
	float band = smoothstep(0.32, 0.0, off);
	float dust = fbm(dir * 9.0);
	col += vec3(0.95, 0.85, 0.95) * band * 0.22 * smoothstep(0.35, 0.65, dust);
	col *= 1.0 - band * smoothstep(0.55, 0.7, fbm(dir * 14.0 + 2.0)) * 0.5;
	float s = stars(dir, 60.0, 0.9, TIME) + stars(dir, 140.0, 0.93, TIME) * 0.7
		+ stars(dir, 300.0, 0.95 - band * 0.06, TIME) * 0.5;
	COLOR = col + vec3(1.0, 0.95, 0.85) * s;
}
