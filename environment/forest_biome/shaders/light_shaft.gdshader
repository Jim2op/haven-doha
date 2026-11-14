// Fake volumetric light shaft (additive). Guides the eye to landmarks; very cheap.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 shaft_color : source_color = vec4(0.55, 0.85, 0.9, 1.0);
uniform float intensity = 0.35;
uniform float flicker_speed = 0.35;

void vertex() {
	// Y-billboard around the (tilted) shaft axis: always faces the camera, so no plane edges show.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], MODEL_MATRIX[1], vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, MODEL_MATRIX[1].xyz)), 0.0), MODEL_MATRIX[3]);
}

void fragment() {
	float side = pow(sin(UV.x * 3.14159), 3.0);
	float vert = smoothstep(0.0, 0.25, UV.y) * smoothstep(0.0, 0.5, 1.0 - UV.y);
	float bands = 0.75 + 0.25 * sin(UV.x * 23.0 + TIME * flicker_speed) * sin(UV.x * 7.0 - TIME * flicker_speed * 0.6);
	ALBEDO = shaft_color.rgb * intensity * side * vert * bands;
}
