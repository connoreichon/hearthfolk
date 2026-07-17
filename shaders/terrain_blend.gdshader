// Terreno TEXTURIZADO por bioma (texturas painterly propias, seamless):
// hierba/tierra/arena/roca/nieve mezcladas por bioma, pendiente y senda.
shader_type spatial;

uniform vec4 grass_color : source_color = vec4(0.467, 0.604, 0.333, 1.0);
uniform vec4 grass_light_color : source_color = vec4(0.58, 0.722, 0.416, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.608, 0.439, 0.282, 1.0);
uniform vec4 dirt_light_color : source_color = vec4(0.714, 0.541, 0.365, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D dirt_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D snow_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.14;   // 1 tile ≈ 7 m
uniform float tex_mix_on = 0.0;   // 1 = terreno texturizado (lo activa el codigo)
// Rejilla de tráfico (S3): senda de tierra donde los colonos caminan.
uniform sampler2D traffic_tex : filter_linear, repeat_disable;
uniform float map_extent = 1024.0;

// Estaciones (Q1): tinte de hierba global + nieve
global uniform vec4 season_grass_tint;
global uniform float snow_amount;

varying float v_forest;   // COLOR.g = bosque (0 pradera .. 1 fronda)
varying float v_highland; // COLOR.b = colinas / tierras altas
varying float v_climate;  // COLOR.a = clima (0 nieve · 0.5 templado · 1 árido)
varying vec3 v_world_pos;
varying vec3 v_normal_w;

void vertex() {
	v_forest = COLOR.g;
	v_highland = COLOR.b;
	v_climate = COLOR.a;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_w = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Muestreo anti-repetición: dos escalas de la misma textura mezcladas por
// ruido ancho — la rejilla del tile desaparece a vista de águila.
vec3 tex_detile(sampler2D t, vec2 uv, float k) {
	vec3 a = texture(t, uv).rgb;
	vec3 b = texture(t, uv * 0.417 + vec2(0.37, 0.71)).rgb;
	return mix(a, b, k);
}

void fragment() {
	float n_broad = texture(noise_tex, v_world_pos.xz * 0.02).r;
	float n_fine = texture(noise_tex, v_world_pos.xz * 0.12).r;
	// Microdetalle de cerca: moteado fino que rompe el color plano del suelo
	float n_micro = texture(noise_tex, v_world_pos.xz * 0.55).r;
	vec2 tuv = v_world_pos.xz * tex_scale;
	float detile_k = smoothstep(0.35, 0.65, n_broad) * 0.6;

	// Base HIERBA: textura pintada (o color plano en modo legado)
	vec3 grass_flat = mix(grass_color.rgb, grass_light_color.rgb, n_broad * 0.75 + n_fine * 0.25);
	vec3 grass_painted = tex_detile(grass_tex, tuv, detile_k) * (0.90 + 0.18 * n_broad);
	vec3 grass = mix(grass_flat, grass_painted, tex_mix_on);
	grass *= 1.0 + (n_micro - 0.5) * 0.08;
	// Calvas de tierra dispersas: parches sutiles donde el ruido fino pica
	float bare_patch = smoothstep(0.78, 0.92, n_fine * 0.6 + n_micro * 0.4) * 0.35;
	vec3 dirt_flat = mix(dirt_color.rgb, dirt_light_color.rgb, n_fine);
	vec3 dirt_painted = tex_detile(dirt_tex, tuv * 1.35, detile_k) * (0.92 + 0.14 * n_fine);
	vec3 dirt = mix(dirt_flat, dirt_painted, tex_mix_on);
	grass = mix(grass, dirt, bare_patch);
	float slope = 1.0 - v_normal_w.y;
	// Senda emergente: tierra pisada donde el tráfico acumulado sube (S3).
	// Umbral progresivo: tráfico ligero = hierba pisada tenue, mucho = tierra.
	float path = texture(traffic_tex, v_world_pos.xz / map_extent + 0.5).r;
	float dirt_amount = clamp(smoothstep(0.16, 0.72, path) + smoothstep(0.10, 0.28, slope), 0.0, 1.0);
	grass = mix(grass, season_grass_tint.rgb, season_grass_tint.a);
	// Tinte por BIOMA (S1/estética): la fronda oscurece y enfría el verde;
	// las tierras altas lo secan hacia tostado. El valle se lee de un vistazo
	// —praderas, bosques umbríos, colinas— también desde la vista de águila.
	vec3 forest_green = grass * vec3(0.50, 0.70, 0.40);
	// En la sabana la fronda no tiñe (sus árboles son motas, no manto).
	float arid_w = clamp((v_climate - 0.5) * 2.0, 0.0, 1.0);
	float cold_w = clamp((0.5 - v_climate) * 2.0, 0.0, 1.0);
	grass = mix(grass, forest_green, clamp(v_forest, 0.0, 1.0) * 0.92 * (1.0 - arid_w));
	vec3 highland_dry = mix(grass, vec3(0.58, 0.54, 0.36), 0.7);
	grass = mix(grass, highland_dry, clamp(v_highland, 0.0, 1.0) * 0.62);
	// CLIMA (Build 004): tundra nevada y sabana seca con dunas de arena.
	vec3 snow_painted = tex_detile(snow_tex, tuv * 0.8, detile_k);
	vec3 tundra_flat = mix(vec3(0.84, 0.87, 0.90), vec3(0.90, 0.92, 0.95), n_fine);
	vec3 tundra = mix(tundra_flat, snow_painted * (0.94 + 0.08 * n_fine), tex_mix_on);
	grass = mix(grass, tundra, cold_w * (0.78 + n_broad * 0.18));
	// Sabana: la propia hierba pintada se seca a paja + dunas de ARENA pintada
	vec3 dry_flat = vec3(0.74, 0.64, 0.38) * (0.92 + n_micro * 0.16);
	vec3 dry_painted = grass_painted * vec3(1.35, 1.08, 0.52);
	vec3 dry_grass = mix(dry_flat, dry_painted, tex_mix_on);
	vec3 dune_flat = vec3(0.81, 0.71, 0.48) * (0.94 + n_fine * 0.12);
	vec3 dune_sand = mix(dune_flat, tex_detile(sand_tex, tuv, detile_k), tex_mix_on);
	vec3 savanna = mix(dry_grass, dune_sand, smoothstep(0.45, 0.85, n_broad));
	grass = mix(grass, savanna, arid_w * 0.9);
	vec3 base = mix(grass, dirt, dirt_amount);
	// Roca asomando en pendientes fuertes (textura pintada de piedra)
	vec3 rock_flat = mix(vec3(0.48, 0.49, 0.48), vec3(0.56, 0.55, 0.52), n_fine);
	vec3 rock = mix(rock_flat, tex_detile(rock_tex, tuv * 1.6, detile_k), tex_mix_on);
	base = mix(base, rock, smoothstep(0.3, 0.52, slope));
	// MONTAÑA: roca por altura (ladera alta) y NIEVE PERMANENTE en la cima
	base = mix(base, rock, smoothstep(6.5, 9.5, v_world_pos.y) * 0.85);
	float peak_snow = smoothstep(10.0, 13.5, v_world_pos.y);
	vec3 peak_col = mix(vec3(0.90, 0.92, 0.95), snow_painted, tex_mix_on);
	base = mix(base, peak_col, peak_snow * (0.75 + n_fine * 0.25));
	// Orilla húmeda: banda oscura junto al nivel del agua (-0.55)
	float wet = smoothstep(0.45, -0.05, v_world_pos.y - (-0.55));
	base = mix(base, base * 0.62, wet * 0.8);
	// Sombras de nubes deslizándose con el tiempo (mundo vivo desde arriba)
	float clouds = texture(noise_tex, v_world_pos.xz * 0.004 + vec2(TIME * 0.008, TIME * 0.005)).r;
	base *= 1.0 - smoothstep(0.62, 0.85, clouds) * 0.14;
	// Nieve: cubre la hierba, respeta un poco el camino y acumula con ruido
	float snow_mask = snow_amount * (1.0 - dirt_amount * 0.55) * (0.75 + n_fine * 0.25);
	vec3 snow_cover = mix(vec3(0.92, 0.93, 0.95), snow_painted, tex_mix_on);
	ALBEDO = mix(base, snow_cover, clamp(snow_mask, 0.0, 1.0));
	ROUGHNESS = mix(0.9, 0.65, snow_amount);
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
