// Contorno por back-face inflado. Se aplica como next_pass o segunda pasada.
shader_type spatial;
render_mode unshaded, cull_front;

uniform vec4 outline_color : source_color = vec4(0.851, 0.706, 0.357, 1.0);
uniform float width = 0.035;

void vertex() {
	VERTEX += NORMAL * width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
