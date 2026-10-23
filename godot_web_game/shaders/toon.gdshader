// Two-band cel light with a soft warm rim and a hard glint, matching the Blender portrait look.
shader_type spatial;

uniform vec3 color : source_color = vec3(1.0);
uniform float gloss = 0.0;
uniform float shadow = 0.62;
// Brightens the whole part, for hover and scanner highlights.
uniform float highlight = 0.0;

void fragment() {
	ALBEDO = color * (1.0 + highlight * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(1.0, 0.85, 0.6) * rim * 0.12 + vec3(1.0, 0.8, 0.4) * highlight * 0.25;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = mix(shadow, 1.0, smoothstep(0.0, 0.04, ndl));
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	float glint = smoothstep(0.96, 0.97, dot(reflect(-LIGHT, NORMAL), VIEW));
	SPECULAR_LIGHT += LIGHT_COLOR * glint * gloss * ATTENUATION;
}
