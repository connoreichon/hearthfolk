// Balanceo sinusoidal por altura del vértice + volumen por COLOR de vértice.
// Retrocompatible: sin vertex color, COLOR=1 y ALBEDO=albedo (comportamiento previo).
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(0.47, 0.6, 0.33, 1.0);
uniform float sway_strength = 0.06;
uniform float sway_speed = 1.2;
uniform float height_ref = 2.0;
uniform float season_mix = 1.0;   // 1 = recibe tinte estacional de hoja, 0 = madera/piedra
uniform float snow_mix = 1.0;     // 1 = recibe nieve (independiente del tinte)

// Estaciones (Q1): tinte de hoja global + nieve
global uniform vec4 season_leaf_tint;
global uniform float snow_amount;

varying vec3 vcol;

void vertex() {
	vcol = COLOR.rgb;   // gris o color horneado = paleta*volumen (AO)
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.35;
	VERTEX.x += sin(phase) * sway_strength * h * h;
	VERTEX.z += cos(phase * 0.8) * sway_strength * 0.7 * h * h;
}

void fragment() {
	vec3 tinted = albedo.rgb * vcol;
	vec3 base = mix(tinted, season_leaf_tint.rgb, season_leaf_tint.a * season_mix);
	ALBEDO = mix(base, vec3(0.93, 0.94, 0.96), snow_amount * 0.75 * snow_mix);
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
