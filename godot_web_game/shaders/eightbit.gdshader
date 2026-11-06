// Redraws whatever is already on screen under this rect as chunky pixels in a fixed bright palette.
shader_type canvas_item;

uniform sampler2D screen : hint_screen_texture, filter_nearest;
// Size of one chunky pixel, in real window pixels.
uniform float cell = 3.0;
uniform float saturation = 2.2;

const int COLORS = 32;
// Holds every UI color from ui.gd too, so a panel behind a portrait comes through unchanged.
const vec3 PALETTE[COLORS] = {
	vec3(0.051, 0.043, 0.149), vec3(0.102, 0.102, 0.306), vec3(0.071, 0.165, 0.549), vec3(0.122, 0.361, 1.000),
	vec3(0.247, 0.706, 1.000), vec3(0.118, 0.902, 0.902), vec3(0.000, 0.702, 0.643), vec3(0.024, 0.333, 0.369),
	vec3(0.043, 0.561, 0.302), vec3(0.137, 0.820, 0.376), vec3(0.651, 0.941, 0.000), vec3(1.000, 0.941, 0.302),
	vec3(1.000, 0.784, 0.000), vec3(1.000, 0.604, 0.000), vec3(1.000, 0.353, 0.122), vec3(0.878, 0.094, 0.176),
	vec3(1.000, 0.180, 0.576), vec3(1.000, 0.478, 0.722), vec3(1.000, 0.769, 0.839), vec3(0.761, 0.122, 0.839),
	vec3(0.482, 0.184, 0.878), vec3(0.239, 0.122, 0.561), vec3(0.302, 0.137, 0.094), vec3(0.541, 0.263, 0.133),
	vec3(0.851, 0.510, 0.290), vec3(1.000, 0.722, 0.549), vec3(1.000, 0.984, 0.878), vec3(1.000, 0.910, 0.620),
	vec3(1.000, 1.000, 1.000), vec3(0.831, 0.831, 0.941), vec3(0.608, 0.608, 0.784), vec3(0.353, 0.353, 0.549)
};

void fragment() {
	vec2 grid = floor(SCREEN_UV / SCREEN_PIXEL_SIZE / cell);
	vec3 c = texture(screen, (grid + 0.5) * cell * SCREEN_PIXEL_SIZE).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(luma), c, saturation);
	vec3 best = PALETTE[0];
	float nearest = 1e6;
	for (int i = 0; i < COLORS; i++) {
		vec3 d = (c - PALETTE[i]) * vec3(0.9, 1.2, 0.7);
		float dist = dot(d, d);
		if (dist < nearest) {
			nearest = dist;
			best = PALETTE[i];
		}
	}
	COLOR = vec4(best, 1.0);
}
