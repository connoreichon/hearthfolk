// Hierba instanciada (S1): briznas mecidas por el viento, con color por
// instancia, tinte estacional global y fundido a blanco bajo la nieve.
shader_type spatial;
render_mode cull_disabled;

uniform float sway_strength = 0.09;
uniform float sway_speed = 1.4;

global uniform vec4 season_grass_tint;
global uniform float snow_amount;

void vertex() {
	float h = clamp(VERTEX.y / 0.45, 0.0, 1.0);
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.6;
	VERTEX.x += sin(phase) * sway_strength * h * h;
	VERTEX.z += cos(phase * 0.83) * sway_strength * 0.6 * h * h;
}

void fragment() {
	vec3 base = mix(COLOR.rgb, season_grass_tint.rgb, season_grass_tint.a);
	ALBEDO = mix(base, vec3(0.93, 0.94, 0.96), snow_amount * 0.85);
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
