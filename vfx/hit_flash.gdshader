shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	ALBEDO = flash_color.rgb;
	ALPHA = clamp(amount * flash_color.a, 0.0, 1.0);
}
