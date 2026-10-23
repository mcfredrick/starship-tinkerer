// Bramble, the banded gas giant: latitude bands warped by drifting noise, lit by a distant sun.
shader_type spatial;
render_mode unshaded;

uniform vec3 band_a : source_color = vec3(0.24, 0.56, 0.58);
uniform vec3 band_b : source_color = vec3(0.45, 0.36, 0.62);
uniform vec3 band_c : source_color = vec3(0.93, 0.78, 0.6);
uniform vec3 sun_dir = vec3(-0.6, 0.35, 0.7);

varying vec3 local_normal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = normalize(local_normal);
	float lon = atan(n.z, n.x);
	float lat = n.y;
	float warp = noise(vec2(lon * 3.0 + TIME * 0.01, lat * 9.0)) * 0.12 + noise(vec2(lon * 9.0, lat * 30.0)) * 0.03;
	float b = sin((lat + warp) * 22.0);
	vec3 col = mix(band_a, band_b, smoothstep(-0.4, 0.4, b));
	col = mix(col, band_c, smoothstep(0.65, 0.95, sin((lat + warp * 1.4) * 9.0 + 1.3)));
	vec3 world_n = normalize((MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float lit = smoothstep(-0.15, 0.25, dot(world_n, normalize(sun_dir)));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = col * mix(0.12, 1.0, lit) + vec3(0.6, 0.85, 1.0) * rim * 0.35 * lit;
}
