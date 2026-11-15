// Voxel palette shader for the Kytric "Voxel Path and Terrain" models.
// Samples a (derived) 256x1 palette with nearest filtering so voxel colours stay crisp,
// then adds per-instance colour variation, a height-based contact darkening (fake AO),
// optional wind sway (foliage) and optional emission. Works with MultiMesh on the Mobile and Compatibility renderers.
shader_type spatial;
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D palette : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float brightness : hint_range(0.0, 3.0) = 1.0;
// Per-instance variation (hash of the instance's world origin).
uniform float value_variation : hint_range(0.0, 0.6) = 0.15;
uniform float hue_variation : hint_range(0.0, 0.3) = 0.05;
// Contact darkening: model-space height (unscaled asset units) over which the base darkens.
uniform float ao_height = 0.6;
uniform float ao_base = 0.0; // model-space height where the ground contact is (some packs are offset)
uniform float ao_strength : hint_range(0.0, 1.0) = 0.45;
// Wind sway, in model units; only vertices above sway_start move.
uniform float sway_amount = 0.0;
uniform float sway_start = 0.2;
uniform float sway_speed = 0.9;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.95;
uniform float specular_value : hint_range(0.0, 1.0) = 0.2;

varying float v_local_y;
varying vec3 v_seed;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	v_local_y = VERTEX.y;
	vec3 origin = MODEL_MATRIX[3].xyz;
	v_seed = origin;
	if (sway_amount > 0.0) {
		float h = max(VERTEX.y - sway_start, 0.0);
		float phase = hash13(floor(origin)) * 6.2831;
		float t = TIME * sway_speed + phase;
		float s = sin(t) * 0.7 + sin(t * 2.3 + 1.7) * 0.3;
		VERTEX.x += s * sway_amount * h * h;
		VERTEX.z += cos(t * 0.8) * sway_amount * 0.5 * h * h;
	}
}

vec3 hue_shift(vec3 c, float a) {
	const vec3 k = vec3(0.57735);
	float ca = cos(a);
	return c * ca + cross(k, c) * sin(a) + k * dot(k, c) * (1.0 - ca);
}

void fragment() {
	vec4 p = texture(palette, UV);
	float r = hash13(floor(v_seed * 0.73) + 17.0);
	vec3 col = p.rgb * tint.rgb * brightness;
	col *= 1.0 + (r - 0.5) * 2.0 * value_variation;
	col = hue_shift(col, (hash13(floor(v_seed * 0.51) + 3.0) - 0.5) * 2.0 * hue_variation);
	float ao = mix(1.0 - ao_strength, 1.0, smoothstep(ao_base, ao_base + ao_height, v_local_y));
	ALBEDO = clamp(col * ao, 0.0, 1.0);
	ROUGHNESS = roughness_value;
	SPECULAR = specular_value;
	EMISSION = emission_color.rgb * emission_energy;
}
