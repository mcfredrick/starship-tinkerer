// Two-band cel light with a soft warm rim and a hard glint, matching the Blender portrait look.
shader_type spatial;

uniform vec3 color : source_color = vec3(1.0);
uniform float gloss = 0.0;
uniform float shadow = 0.62;
// Brightens the whole part, for hover and scanner highlights.
uniform float highlight = 0.0;
// Pearl finish: an iridescent sheen that shifts hue with the viewing angle.
uniform float pearl = 0.0;
// Paint sweep: the old color stays ahead of a front moving along `sweep_axis` from `sweep_origin`.
uniform vec3 old_color : source_color = vec3(1.0);
uniform vec3 sweep_origin = vec3(0.0);
uniform vec3 sweep_axis = vec3(0.0, 0.0, 1.0);
uniform float sweep = 1000.0;

varying float along;

void vertex() {
	along = dot((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - sweep_origin, sweep_axis);
}

void fragment() {
	vec3 base = along < sweep ? color : old_color;
	float wet = 1.0 - smoothstep(0.0, 0.25, abs(along - sweep));
	ALBEDO = mix(base, vec3(1.0), wet * 0.5) * (1.0 + highlight * 0.5);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(1.0, 0.85, 0.6) * rim * 0.12 + vec3(1.0, 0.8, 0.4) * highlight * 0.25;
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	vec3 hue = 0.5 + 0.5 * cos(6.2832 * (sheen * 1.3 + vec3(0.0, 0.33, 0.67)));
	EMISSION += hue * sheen * pearl * 0.45;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = mix(shadow, 1.0, smoothstep(0.0, 0.04, ndl));
	DIFFUSE_LIGHT += LIGHT_COLOR * band / PI;
	float glint = smoothstep(0.96, 0.97, dot(reflect(-LIGHT, NORMAL), VIEW));
	SPECULAR_LIGHT += LIGHT_COLOR * glint * gloss * ATTENUATION;
}
