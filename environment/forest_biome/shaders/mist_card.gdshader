// Soft drifting mist band. Used on large quads between depth layers to separate
// foreground / midground / background and to sell scale. Unshaded, no depth write.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 mist_color : source_color = vec4(0.55, 0.68, 0.72, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float bottom_fade = 0.15;
uniform float top_fade = 0.6;
uniform float edge_fade = 0.12;
uniform float noise_scale = 3.0;
uniform vec2 drift = vec2(0.012, 0.0);
uniform float near_fade_distance = 14.0;
uniform int octaves : hint_range(1, 4) = 4;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { if (i >= octaves) { break; } v += a * noise(p); p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 uv = UV;
	float vert = smoothstep(0.0, bottom_fade, 1.0 - uv.y) * (1.0 - smoothstep(1.0 - top_fade, 1.0, 1.0 - uv.y));
	float horiz = smoothstep(0.0, edge_fade, uv.x) * smoothstep(0.0, edge_fade, 1.0 - uv.x);
	vec2 q = vec2(uv.x * noise_scale * 4.0, uv.y * noise_scale) + TIME * drift * vec2(10.0, 4.0);
	float n = fbm(q) * 0.75 + fbm(q * 2.7 - TIME * drift * 6.0) * 0.5;
	float cam_fade = smoothstep(near_fade_distance * 0.4, near_fade_distance, -VERTEX.z);
	ALBEDO = mist_color.rgb;
	ALPHA = clamp(density * vert * horiz * n * cam_fade, 0.0, 1.0);
}
