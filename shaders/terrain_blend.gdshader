// Mezcla hierba/tierra por color de vértice (R = camino pintado) + pendiente.
shader_type spatial;

uniform vec4 grass_color : source_color = vec4(0.467, 0.604, 0.333, 1.0);
uniform vec4 grass_light_color : source_color = vec4(0.58, 0.722, 0.416, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.608, 0.439, 0.282, 1.0);
uniform vec4 dirt_light_color : source_color = vec4(0.714, 0.541, 0.365, 1.0);
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;

// Estaciones (Q1): tinte de hierba global + nieve
global uniform vec4 season_grass_tint;
global uniform float snow_amount;

varying float v_path;
varying vec3 v_world_pos;
varying vec3 v_normal_w;

void vertex() {
	v_path = COLOR.r;
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_normal_w = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float n_broad = texture(noise_tex, v_world_pos.xz * 0.02).r;
	float n_fine = texture(noise_tex, v_world_pos.xz * 0.12).r;
	vec3 grass = mix(grass_color.rgb, grass_light_color.rgb, n_broad * 0.75 + n_fine * 0.25);
	vec3 dirt = mix(dirt_color.rgb, dirt_light_color.rgb, n_fine);
	float slope = 1.0 - v_normal_w.y;
	float dirt_amount = clamp(v_path + smoothstep(0.10, 0.28, slope), 0.0, 1.0);
	grass = mix(grass, season_grass_tint.rgb, season_grass_tint.a);
	vec3 base = mix(grass, dirt, dirt_amount);
	// Nieve: cubre la hierba, respeta un poco el camino y acumula con ruido
	float snow_mask = snow_amount * (1.0 - dirt_amount * 0.55) * (0.75 + n_fine * 0.25);
	ALBEDO = mix(base, vec3(0.92, 0.93, 0.95), clamp(snow_mask, 0.0, 1.0));
	ROUGHNESS = mix(0.9, 0.65, snow_amount);
	METALLIC = 0.0;
	SPECULAR = 0.08;
}
