// Race track: a light-bridge laid across space. A deep deck with a faint hex grid, chevrons that
// stream forward, and edge rails with pulses of light racing along them.
// UV.x runs across the track (0..1), UV.y along it in meters / 10.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 deck : source_color = vec3(0.12, 0.08, 0.22);
uniform vec3 grid : source_color = vec3(0.35, 0.75, 0.95);
uniform vec3 edge : source_color = vec3(1.0, 0.72, 0.35);
uniform vec3 pulse : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 chevron : source_color = vec3(0.4, 0.95, 0.9);

float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}

void fragment() {
	float x = UV.x;
	float y = UV.y;
	float cx = abs(x - 0.5) * 2.0;
	vec3 col = deck * (1.0 - cx * cx * 0.35);
	// Hex grid, brighter toward the rails.
	float h = smoothstep(0.08, 0.0, hex(vec2(x * 7.0, y * 3.5)));
	col += grid * h * (0.08 + cx * 0.12);
	// Chevrons streaming forward down the lanes.
	float chev = fract(y * 0.5 - cx * 0.3 - TIME * 0.9);
	float lane = step(0.1, cx) * step(cx, 0.85);
	col += chevron * smoothstep(0.07, 0.0, abs(chev - 0.5)) * lane * 0.35;
	// Rails with pulses chasing along them.
	float rail = smoothstep(0.04, 0.0, x) + smoothstep(0.96, 1.0, x);
	float chase = pow(fract(y * 0.08 - TIME * 0.7), 6.0);
	col = mix(col, edge + pulse * chase * 1.5, rail);
	col += edge * smoothstep(0.12, 0.0, min(x, 1.0 - x)) * 0.25;
	ALBEDO = col;
}
