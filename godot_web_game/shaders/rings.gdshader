// Planetary rings on a flat plane: bands and gaps by radius, thinning toward both edges.
// UV spans the plane, with the planet at the center.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform float inner = 0.42;
uniform vec3 tint_a : source_color = vec3(0.95, 0.82, 0.62);
uniform vec3 tint_b : source_color = vec3(0.55, 0.72, 0.85);

float hash(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

float noise(float x) {
	float i = floor(x);
	float f = fract(x);
	return mix(hash(i), hash(i + 1.0), f * f * (3.0 - 2.0 * f));
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	if (r < inner || r > 1.0) {
		discard;
	}
	float t = (r - inner) / (1.0 - inner);
	float bands = noise(t * 40.0) * 0.6 + noise(t * 160.0) * 0.4;
	float gap = smoothstep(0.02, 0.0, abs(t - 0.62)) + smoothstep(0.012, 0.0, abs(t - 0.35));
	float a = smoothstep(0.0, 0.08, t) * smoothstep(1.0, 0.85, t) * (0.25 + bands * 0.6) * (1.0 - gap);
	ALBEDO = mix(tint_a, tint_b, noise(t * 7.0 + 3.0));
	ALPHA = a * 0.75;
}
