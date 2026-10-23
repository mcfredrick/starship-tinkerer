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

// Livery: a pattern laid over the paint in the ship's own space (nose toward -Z), in `pattern_color`.
uniform int pattern = 0;
uniform vec3 pattern_color : source_color = vec3(1.0);

// Grime: blotchy dirt fixed in the ship's own space, minus the patches scrubbed clean.
uniform float grime = 0.0;
uniform mat4 ship_inverse;
uniform vec4 clean_spots[64];
uniform int clean_count = 0;

varying float along;
varying vec3 ship_pos;

void vertex() {
	vec4 world = MODEL_MATRIX * vec4(VERTEX, 1.0);
	along = dot(world.xyz - sweep_origin, sweep_axis);
	ship_pos = (ship_inverse * world).xyz;
}

float hash(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float livery() {
	vec3 p = ship_pos;
	if (pattern == 1) {
		return float(p.y > 0.0 && abs(abs(p.x) - 0.17) < 0.07);
	} else if (pattern == 2) {
		return float(p.y < -0.05);
	} else if (pattern == 3) {
		return float(fract(p.z * 0.9) < 0.22);
	} else if (pattern == 4) {
		vec3 cell = fract(p * 2.4) - 0.5;
		return float(length(cell.yz) < 0.2 && abs(p.x) > 0.15);
	} else if (pattern == 5) {
		float wave = abs(fract(p.z * 1.6) - 0.5) * 0.5 - 0.12;
		return float(abs(p.x) > 0.3 && abs(p.y - wave) < 0.06);
	} else if (pattern == 6) {
		vec3 c = floor(p * 3.0);
		return mod(c.x + c.y + c.z, 2.0);
	} else if (pattern == 7) {
		float tongue = 0.35 * sin(atan(p.y, p.x) * 7.0) + 0.25 * sin(p.y * 13.0);
		return float(p.z < -0.6 + tongue);
	}
	return 0.0;
}

float dirt() {
	if (grime <= 0.0) {
		return 0.0;
	}
	float blotch = noise(ship_pos * 2.3) * 0.65 + noise(ship_pos * 7.0) * 0.35;
	float d = grime * (0.3 + 0.7 * smoothstep(0.42, 0.62, blotch));
	float clean = 0.0;
	for (int i = 0; i < clean_count; i++) {
		clean = max(clean, 1.0 - smoothstep(clean_spots[i].w * 0.6, clean_spots[i].w, distance(ship_pos, clean_spots[i].xyz)));
	}
	return d * (1.0 - clean);
}

void fragment() {
	vec3 base = along < sweep ? color : old_color;
	base = mix(base, pattern_color, livery());
	float wet = 1.0 - smoothstep(0.0, 0.25, abs(along - sweep));
	base = mix(base, vec3(0.34, 0.28, 0.22), dirt() * 0.8);
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
