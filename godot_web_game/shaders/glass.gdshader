// Glowing glass: jelly domes and terrarium bubbles. Mostly clear in the middle, bright at the
// rim, with a slow breathing pulse.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.6, 0.9, 1.0);
uniform float body = 0.12;
uniform float pulse = 0.0;

void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float breathe = 1.0 + pulse * sin(TIME * 2.0);
	ALBEDO = tint * (1.0 + rim) * breathe;
	ALPHA = clamp(body + rim * 0.75, 0.0, 1.0);
}
