// Follaje/props TEXTURIZADOS (MegaKit) con vida: balanceo por viento, tinte
// estacional que respeta la pincelada (via luminancia) y NIEVE dinámica que
// se posa en las caras que miran al cielo (snow_amount global del
// season_controller: nieva → se cargan las copas; sol → se derrite).
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float alpha_cut = 0.45;
uniform float sway_strength = 0.04;
uniform float sway_speed = 1.1;
uniform float height_ref = 4.0;
uniform float season_mix = 1.0;  // hojas 1 · corteza/roca 0
uniform float snow_mix = 1.0;

global uniform vec4 season_leaf_tint;
global uniform float snow_amount;

varying vec3 v_normal_w;

void vertex() {
	float h = clamp(VERTEX.y / height_ref, 0.0, 1.0);
	float phase = TIME * sway_speed + (MODEL_MATRIX[3].x + MODEL_MATRIX[3].z) * 0.35;
	VERTEX.x += sin(phase) * sway_strength * h * h;
	VERTEX.z += cos(phase * 0.8) * sway_strength * 0.7 * h * h;
	v_normal_w = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	// Otoño: recolorea conservando el dibujo (luminancia × tinte global)
	float lum = dot(t.rgb, vec3(0.299, 0.587, 0.114));
	vec3 autumn = lum * season_leaf_tint.rgb * 2.1;
	vec3 base = mix(t.rgb, autumn, season_leaf_tint.a * season_mix);
	// Nieve acumulada: caras hacia arriba, con banda suave (abs para que las
	// tarjetas de hoja vistas del reves tambien blanqueen)
	float up = smoothstep(0.15, 0.65, abs(v_normal_w.y));
	float snow_w = clamp(snow_amount * snow_mix, 0.0, 1.0) * up;
	base = mix(base, vec3(0.93, 0.95, 0.97), snow_w * 0.92);
	ALBEDO = base;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 0.85;
	METALLIC = 0.0;
	SPECULAR = 0.1;
}
