// Race track surface: deep violet deck, glowing edge rails, a dashed center line and chevrons
// that drift forward. UV.x runs across the track (0..1), UV.y along it in meters / 10.
shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec3 deck : source_color = vec3(0.2, 0.17, 0.3);
uniform vec3 edge : source_color = vec3(1.0, 0.78, 0.4);
uniform vec3 chevron : source_color = vec3(0.45, 0.85, 0.85);

void fragment() {
	float x = UV.x;
	float y = UV.y;
	vec3 col = deck * (0.9 + 0.1 * step(0.5, fract(y * 0.5)));
	float rail = smoothstep(0.035, 0.0, x) + smoothstep(0.965, 1.0, x);
	col = mix(col, edge, rail);
	float center = step(abs(x - 0.5), 0.006) * step(0.5, fract(y * 1.5));
	col = mix(col, vec3(0.95, 0.9, 0.8), center * 0.7);
	float cx = abs(x - 0.5) * 2.0;
	float chev = fract(y * 0.5 - cx * 0.25 - TIME * 0.6);
	float lane = step(0.12, cx) * step(cx, 0.85);
	col += chevron * smoothstep(0.08, 0.0, abs(chev - 0.5)) * lane * 0.12;
	ALBEDO = col;
}
