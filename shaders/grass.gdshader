// Hierba instanciada (S1): briznas mecidas por el viento, con color por
// instancia, tinte estacional global y fundido a blanco bajo la nieve.
shader_type spatial;
render_mode cull_disabled;

uniform float sway_strength = 0.09;
uniform float sway_speed = 1.4;
// Textura pintada (MegaKit): tex_mix 1 = tarjetas con textura y recorte alfa;
// el COLOR de instancia tiñe (clima: paja en sabana, gris en tundra).
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float tex_mix = 0.0;

global uniform vec4 season_grass_tint;
global uniform float snow_amount;

varying float vheight;

void vertex() {
	float h = clamp(VERTEX.y / 0.45, 0.0, 1.0);
	vheight = h;
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.6;
	VERTEX.x += sin(phase) * sway_strength * h * h;
	VERTEX.z += cos(phase * 0.83) * sway_strength * 0.6 * h * h;
	// Normal forzada hacia ARRIBA: la mata se sombrea como el suelo que pisa
	// (sin caos de facetas al amanecer/atardecer). Truco estándar de hierba.
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// Textura pintada × tinte de instancia (reforzado: los verdes de paleta
	// rondan 0.3 en lineal). Techo 1.0: las puntas claras de la textura se
	// disparaban a blanco en masa. El modo legado (tex_mix 0) usa solo COLOR.
	vec3 tex_rgb = t.rgb * 0.92 * clamp(COLOR.rgb * 2.2, vec3(0.35), vec3(1.0));
	vec3 base = mix(COLOR.rgb, tex_rgb, tex_mix);
	base = mix(base, season_grass_tint.rgb, season_grass_tint.a);
	// Volumen: base en sombra -> punta al sol.
	base *= 0.72 + 0.24 * vheight;
	ALBEDO = mix(base, vec3(0.93, 0.94, 0.96), snow_amount * 0.85);
	ALPHA = mix(1.0, t.a, tex_mix);
	ALPHA_SCISSOR_THRESHOLD = 0.45;
	ROUGHNESS = 0.9;
	METALLIC = 0.0;
	SPECULAR = 0.05;
}
