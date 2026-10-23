// Inverted hull: a dark back-face shell pushed out along normals reads as an ink outline.
shader_type spatial;
render_mode unshaded, cull_front;

uniform float width = 0.03;
uniform vec3 color : source_color = vec3(0.12, 0.08, 0.1);

void vertex() {
	// Width is in world units, so big and small parts get the same line weight.
	float scale = length(MODEL_MATRIX[0].xyz);
	VERTEX += NORMAL * width / scale;
}

void fragment() {
	ALBEDO = color;
}
