shader_type canvas_item;
// Remove uma cor sólida (verde neon #00FF00 por padrão) da textura, com uma
// faixa de transição suave em vez de um corte binário -- usado no fundo
// `inventory_background.jpeg` da Ficha do Navio pra abrir um buraco
// transparente no retângulo verde do Viewport central, revelando a planta
// do Galeão (`galleon_blueprint.png`) desenhada atrás dele.

uniform vec4 key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);
// Quão perto da cor-chave um pixel precisa estar pra começar a sumir, e a
// largura da rampa até ficar 100% transparente -- uma faixa estreita evita
// comer anti-aliasing de verdade que não é fundo (não é o caso aqui, mas
// mantém o shader reutilizável em outra arte com esse mesmo truque).
uniform float threshold : hint_range(0.0, 1.0) = 0.25;
uniform float smoothness : hint_range(0.0, 1.0) = 0.15;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float dist = distance(tex.rgb, key_color.rgb);
	float alpha = smoothstep(threshold, threshold + smoothness, dist);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}
