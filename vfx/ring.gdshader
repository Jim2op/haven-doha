shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.45, 1.0);
uniform float radius = 0.8;
uniform float thickness = 0.12;
uniform float alpha = 1.0;
uniform float fill = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float d = length(p);
	float ring = 1.0 - smoothstep(0.0, thickness, abs(d - radius));
	float ang = fract(atan(p.x, -p.y) / 6.2831853 + 1.0);
	float arc = step(ang, fill);
	ALBEDO = color.rgb * ring * arc * alpha;
}
