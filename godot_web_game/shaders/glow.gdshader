// Lamps, nozzles and screens: flat bright color with a slow breathing pulse.
shader_type spatial;
render_mode unshaded;

uniform vec3 color : source_color = vec3(1.0, 0.85, 0.4);
uniform float pulse = 0.08;

void fragment() {
	ALBEDO = color * (1.0 + pulse * sin(TIME * 2.4));
}
