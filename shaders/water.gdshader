// Agua viva (S1): olas suaves por vértice, espuma en la orilla por
// profundidad y transparencia que deja adivinar el lecho.
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec4 water_color : source_color = vec4(0.36, 0.57, 0.65, 0.78);
uniform vec4 deep_color : source_color = vec4(0.22, 0.42, 0.52, 0.9);
uniform vec4 foam_color : source_color = vec4(0.86, 0.91, 0.89, 0.95);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// Agua CALMADA (orden del dueño): los lagos y ríos no son mar — apenas
	// un rizo lento y corto, nada de marea que sube y baja.
	float wave = sin(v_world_pos.x * 0.6 + TIME * 0.5)
		+ cos(v_world_pos.z * 0.5 + TIME * 0.35);
	VERTEX.y += wave * 0.012;
}

void fragment() {
	// Profundidad aparente comparando con lo ya dibujado debajo
	float scene_depth_raw = texture(depth_tex, SCREEN_UV).r;
	vec4 scene_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene_depth_raw, 1.0);
	scene_view.xyz /= scene_view.w;
	float depth_diff = VERTEX.z - scene_view.z;
	float shallow = 1.0 - clamp(depth_diff / 1.1, 0.0, 1.0);
	// Espuma: banda fina donde el agua casi toca la orilla, con vaivén
	float foam_band = smoothstep(0.72, 0.98, shallow + sin(TIME * 1.6 + v_world_pos.x * 0.8) * 0.03);
	vec3 body = mix(deep_color.rgb, water_color.rgb, shallow * 0.7);
	// Chispas de sol: olitas especulares baratas, discretas
	float sparkle = pow(max(sin(v_world_pos.x * 2.1 + TIME * 0.7) * cos(v_world_pos.z * 1.7 - TIME * 0.5), 0.0), 14.0);
	body += vec3(0.22) * sparkle * 0.25;
	ALBEDO = mix(body, foam_color.rgb, foam_band);
	ALPHA = mix(mix(deep_color.a, water_color.a, shallow), foam_color.a, foam_band);
	ROUGHNESS = 0.18;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
