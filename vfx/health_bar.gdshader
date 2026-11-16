shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.247, 0.561, 0.353, 1.0);
uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 border_color : source_color = vec4(0.07, 0.06, 0.045, 1.0);
uniform float aspect = 4.4;
uniform float roundness : hint_range(0.0, 1.0) = 1.0;
uniform float border : hint_range(0.0, 0.5) = 0.16;

float rounded_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - (half_size - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 half_size = vec2(aspect * 0.5, 0.5);
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float r = 0.5 * roundness;
	if (rounded_box(p, half_size, r) > 0.0) {
		discard;
	}
	float inner = rounded_box(p, half_size - vec2(border * 0.5), max(r - border * 0.5, 0.0));
	vec3 col = UV.x <= fill ? fill_color.rgb : back_color.rgb;
	ALBEDO = inner > 0.0 ? border_color.rgb : col;
}
