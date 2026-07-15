// Mezcla hierba/tierra por color de vértice (R = camino pintado) + pendiente.
shader_type spatial;

uniform vec4 grass_color : source_color = vec4(0.467, 0.604, 0.333, 1.0);
uniform vec4 grass_light_color : source_color = vec4(0.58, 0.722, 0.416, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.608, 0.439, 0.282, 1.0);
uniform vec4 dirt_light_color : source_color = vec4(0.714, 0.541, 0.365, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// Rejilla de tráfico (S3): senda de tierra donde los colonos caminan.
uniform sampler2D traffic_tex : filter_linear, repeat_disable;
uniform float map_extent = 1024.0;

// Estaciones (Q1): tinte de hierba global + nieve
global uniform vec4 season_grass_tint;
global uniform float snow_amount;

varying float v_forest;   // COLOR.g = bosque (0 pradera .. 1 fronda)
varying float v_highland; // COLOR.b = colinas / tierras altas
varying vec3 v_world_pos;
varying vec3 v_normal_w;

void vertex() {
	v_forest = COLOR.g;
	v_highland = COLOR.b;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_w = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n_broad = texture(noise_tex, v_world_pos.xz * 0.02).r;
	float n_fine = texture(noise_tex, v_world_pos.xz * 0.12).r;
	vec3 grass = mix(grass_color.rgb, grass_light_color.rgb, n_broad * 0.75 + n_fine * 0.25);
	vec3 dirt = mix(dirt_color.rgb, dirt_light_color.rgb, n_fine);
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
	grass = mix(grass, forest_green, clamp(v_forest, 0.0, 1.0) * 0.92);
	vec3 highland_dry = mix(grass, vec3(0.58, 0.54, 0.36), 0.7);
	grass = mix(grass, highland_dry, clamp(v_highland, 0.0, 1.0) * 0.62);
	vec3 base = mix(grass, dirt, dirt_amount);
	// Roca asomando en pendientes fuertes (gris frío con veta de ruido)
	vec3 rock = mix(vec3(0.48, 0.49, 0.48), vec3(0.56, 0.55, 0.52), n_fine);
	base = mix(base, rock, smoothstep(0.3, 0.52, slope));
	// Orilla húmeda: banda oscura junto al nivel del agua (-0.55)
	float wet = smoothstep(0.45, -0.05, v_world_pos.y - (-0.55));
	base = mix(base, base * 0.62, wet * 0.8);
	// Sombras de nubes deslizándose con el tiempo (mundo vivo desde arriba)
	float clouds = texture(noise_tex, v_world_pos.xz * 0.004 + vec2(TIME * 0.008, TIME * 0.005)).r;
	base *= 1.0 - smoothstep(0.62, 0.85, clouds) * 0.14;
	// Nieve: cubre la hierba, respeta un poco el camino y acumula con ruido
	float snow_mask = snow_amount * (1.0 - dirt_amount * 0.55) * (0.75 + n_fine * 0.25);
	ALBEDO = mix(base, vec3(0.92, 0.93, 0.95), clamp(snow_mask, 0.0, 1.0));
	ROUGHNESS = mix(0.9, 0.65, snow_amount);
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
