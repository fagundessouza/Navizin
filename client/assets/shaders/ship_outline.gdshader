shader_type canvas_item;

// Contorno leve da silhueta do navio: uma borda da cor indicada onde o sprite é
// transparente e vizinho ao casco. Lê bem a silhueta contra o mar escuro.

/// Cor do contorno.
uniform vec4 outline_color : source_color = vec4(0.04, 0.09, 0.14, 0.9);

/// Espessura do contorno, em pixels da textura.
uniform float outline_width : hint_range(0.0, 3.0) = 1.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = TEXTURE_PIXEL_SIZE * outline_width;
	float n = 0.0;
	n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
	n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
	n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
	float inside = step(0.5, c.a);
	float edge = step(0.5, n) * (1.0 - inside);
	COLOR = mix(vec4(0.0), c, inside) + outline_color * edge;
}
