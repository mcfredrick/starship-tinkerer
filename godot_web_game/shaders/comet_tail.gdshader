// A comet's tail: brightest at the head, fading and streaking out along its length.
// The mesh is a cone whose narrow top end sits at the head; UV.y runs 0 there to 1 at the far end.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(0.75, 0.85, 1.0);
uniform vec3 core : source_color = vec3(1.0, 0.8, 0.95);

void fragment() {
	float along = UV.y;
	float streaks = 0.6 + 0.4 * sin(UV.x * 6.2832 * 7.0 + along * 3.0 + TIME * 0.3);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	vec3 c = mix(core, color, smoothstep(0.0, 0.5, along));
	ALBEDO = c * (1.0 - along) * (1.0 - along) * streaks * (0.35 + 0.65 * (1.0 - rim));
}
