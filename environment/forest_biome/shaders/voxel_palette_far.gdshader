// Far-layer variant of the voxel palette shader (ridges, distant mountains, far silhouettes).
// Scene fog is disabled here and replaced by a controllable distance haze, so the scene fog can be
// thick around the playfield without erasing the distant mountains. Peaks stay clearer than bases.
shader_type spatial;
render_mode fog_disabled, cull_disabled;

uniform sampler2D palette : source_color, filter_nearest_mipmap, repeat_disable;
uniform float brightness = 0.6;
uniform vec4 haze_color : source_color = vec4(0.27, 0.38, 0.43, 1.0);
uniform float haze_density = 0.004;
uniform float haze_max : hint_range(0.0, 1.0) = 0.85;
uniform float peak_clarity : hint_range(0.0, 1.0) = 0.3;
uniform float peak_height = 120.0;

varying float v_dist;
varying float v_wy;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_dist = length(w - CAMERA_POSITION_WORLD);
	v_wy = w.y;
}

void fragment() {
	vec3 c = texture(palette, UV).rgb * brightness;
	float h = (1.0 - exp(-v_dist * haze_density)) * haze_max;
	h *= 1.0 - peak_clarity * clamp(v_wy / peak_height, 0.0, 1.0);
	ALBEDO = c * (1.0 - h);
	EMISSION = haze_color.rgb * h;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
