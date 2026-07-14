// Balanceo sinusoidal por altura del vértice. Solo cosmético (usa TIME real).
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(0.47, 0.6, 0.33, 1.0);
uniform float sway_strength = 0.06;
uniform float sway_speed = 1.2;
uniform float height_ref = 2.0;

// Estaciones (Q1): tinte de hoja global + nieve
global uniform vec4 season_leaf_tint;
global uniform float snow_amount;

void vertex() {
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.35;
	VERTEX.x += sin(phase) * sway_strength * h * h;
	VERTEX.z += cos(phase * 0.8) * sway_strength * 0.7 * h * h;
}

void fragment() {
	vec3 base = mix(albedo.rgb, season_leaf_tint.rgb, season_leaf_tint.a);
	ALBEDO = mix(base, vec3(0.93, 0.94, 0.96), snow_amount * 0.75);
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
