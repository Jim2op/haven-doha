shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.78, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.62, 0.22, 1.0);
uniform float progress = 0.0;
uniform float trail = 0.5;
uniform float intensity = 1.25;

void fragment() {
	float behind = progress - UV.x;
	float along = step(0.0, behind) * (1.0 - clamp(behind / trail, 0.0, 1.0));
	float r = UV.y;
	float band = smoothstep(0.0, 0.55, r) * (1.0 - smoothstep(0.88, 1.0, r));
	float core = smoothstep(0.6, 0.85, r) * (1.0 - smoothstep(0.85, 0.97, r));
	vec3 c = mix(edge_color.rgb, core_color.rgb, core);
	ALBEDO = c * along * along * band * intensity;
}
