shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform float fill : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.247, 0.561, 0.353, 1.0);
uniform vec4 back_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	ALBEDO = UV.x <= fill ? fill_color.rgb : back_color.rgb;
}
