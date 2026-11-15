shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back, shadows_disabled, fog_disabled;

uniform vec4 flash_color : source_color = vec4(1.0, 0.92, 0.75, 1.0);
uniform float amount : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	ALBEDO = flash_color.rgb * amount * (0.4 + 0.5 * rim);
}
