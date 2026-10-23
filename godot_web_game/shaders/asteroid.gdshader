// Asteroids in a MultiMesh: each instance tumbles on its own axis, lit in two cel bands, with
// an optional glow for crystal instances (INSTANCE_CUSTOM.a > 0).
shader_type spatial;

uniform vec3 rock : source_color = vec3(0.42, 0.36, 0.42);
uniform vec3 crystal : source_color = vec3(0.5, 1.0, 0.9);

varying float glow;

mat3 axis_angle(vec3 axis, float a) {
	float c = cos(a);
	float s = sin(a);
	vec3 n = normalize(axis);
	return mat3(
		vec3(c + n.x * n.x * (1.0 - c), n.y * n.x * (1.0 - c) + n.z * s, n.z * n.x * (1.0 - c) - n.y * s),
		vec3(n.x * n.y * (1.0 - c) - n.z * s, c + n.y * n.y * (1.0 - c), n.z * n.y * (1.0 - c) + n.x * s),
		vec3(n.x * n.z * (1.0 - c) + n.y * s, n.y * n.z * (1.0 - c) - n.x * s, c + n.z * n.z * (1.0 - c)));
}

void vertex() {
	vec3 axis = INSTANCE_CUSTOM.xyz * 2.0 - 1.0 + vec3(0.001);
	mat3 spin = axis_angle(axis, TIME * (0.1 + INSTANCE_CUSTOM.x * 0.3));
	VERTEX = spin * VERTEX;
	NORMAL = spin * NORMAL;
	glow = INSTANCE_CUSTOM.a;
}

void fragment() {
	ALBEDO = mix(rock, crystal, glow);
	EMISSION = crystal * glow * 0.9;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float band = mix(0.45, 1.0, smoothstep(0.0, 0.05, dot(NORMAL, LIGHT) * ATTENUATION));
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
}
