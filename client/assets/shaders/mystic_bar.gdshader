shader_type canvas_item;

// Preenchimento de barra estilo orbe de MMORPG: gradiente líquido, brilho interno que
// pulsa suavemente e uma varredura de luz que passa na horizontal. A forma continua
// vindo da textura do TextureProgressBar (o alfa), então nada vaza pelo frame.

uniform vec4 top_color : source_color = vec4(0.86, 0.8, 0.45, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.07, 0.32, 0.24, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.87, 0.5, 1.0);
uniform float pulse_speed = 1.4;
uniform float pulse_strength = 0.22;
uniform float shimmer_speed = 0.35;
uniform float shimmer_width = 0.12;
uniform float shimmer_strength = 0.35;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float g = UV.y;
	vec3 base = mix(top_color.rgb, bottom_color.rgb, g);
	// Brilho no topo, que respira com o tempo.
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	float top_glow = pow(max(1.0 - abs(g - 0.18) * 2.6, 0.0), 2.0);
	base += glow_color.rgb * top_glow * pulse_strength * (0.6 + 0.4 * pulse);
	// Varredura de luz horizontal.
	float band = fract(UV.x - TIME * shimmer_speed);
	float sweep = smoothstep(0.0, shimmer_width, band) * (1.0 - smoothstep(shimmer_width, shimmer_width * 2.0, band));
	base += vec3(1.0) * sweep * shimmer_strength;
	COLOR = vec4(base, tex.a * COLOR.a);
}
