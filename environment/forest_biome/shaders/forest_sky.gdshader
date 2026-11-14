// Dusk sky for the mystical forest: deep indigo zenith, teal misty horizon, a pale moon
// with a large halo, and sparse faint stars. Cheap enough for radiance updates.
shader_type sky;

uniform vec3 zenith_color : source_color = vec3(0.03, 0.05, 0.10);
uniform vec3 mid_color : source_color = vec3(0.08, 0.14, 0.20);
uniform vec3 horizon_color : source_color = vec3(0.30, 0.42, 0.44);
uniform vec3 ground_color : source_color = vec3(0.05, 0.08, 0.09);
uniform vec3 moon_dir = vec3(-0.42, 0.17, -0.89);
uniform vec3 moon_color : source_color = vec3(0.92, 0.96, 1.0);
uniform float moon_size = 0.00035;
uniform float halo_strength = 0.3;
uniform float star_density = 0.25;

float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }

void sky() {
	vec3 d = EYEDIR;
	float y = d.y;
	vec3 col = mix(horizon_color, mid_color, smoothstep(0.0, 0.18, y));
	col = mix(col, zenith_color, smoothstep(0.15, 0.7, y));
	col = mix(col, ground_color, smoothstep(0.0, -0.08, y));
	vec3 md = normalize(moon_dir);
	float c = dot(d, md);
	float disc = smoothstep(1.0 - moon_size, 1.0 - moon_size * 0.85, c);
	float halo = pow(max(c, 0.0), 1500.0) * halo_strength + pow(max(c, 0.0), 40.0) * halo_strength * 0.25;
	col += moon_color * (disc * 2.5 + halo);
	if (y > 0.05) {
		vec3 cell = floor(d * 220.0);
		float s = hash(cell);
		float star = step(1.0 - 0.004 * star_density, s) * smoothstep(0.05, 0.4, y);
		col += vec3(0.8, 0.9, 1.0) * star * (0.4 + 0.6 * hash(cell + 7.0));
	}
	COLOR = col;
}
