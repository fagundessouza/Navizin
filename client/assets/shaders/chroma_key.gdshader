shader_type canvas_item;
// Remove uma cor sólida (verde neon #00FF00 por padrão) da textura, com uma
// faixa de transição suave em vez de um corte binário -- usado no fundo
// `inventory_background.jpeg` da Ficha do Navio pra abrir um buraco
// transparente no retângulo verde do Viewport central, revelando a planta
// do Galeão (`galleon_blueprint.png`) desenhada atrás dele.
//
// CORRIGIDO (pedido explícito -- "franja verde na borda esquerda do
// papiro"): a versão anterior media `distance()` euclidiana até
// `key_color` (0,1,0) puro. Pixel de franja/anti-aliasing na borda do
// recorte original costuma ser um verde ESCURO (ex: RGB 0,40,0 -- quase
// preto, mas ainda "verde" na proporção dos canais) -- a distância
// euclidiana até um verde BRILHANTE saturado dá um número GRANDE pra esse
// pixel escuro (porque ele tá longe em brilho, não só em matiz), então o
// shader achava que não era fundo e deixava opaco: exatamente a franja
// visível relatada. Trocado pra "greenness" por DOMINÂNCIA de canal (G
// menos o maior entre R/B) -- o mesmo método que já resolveu esse problema
// nos retratos da Tripulação (`slice_crew.py`, achado nesta sessão):
// funciona igual pra verde escuro ou brilhante, porque olha a PROPORÇÃO
// entre canais, não a distância absoluta de brilho.
uniform float threshold : hint_range(0.0, 1.0) = 0.06;
uniform float smoothness : hint_range(0.0, 1.0) = 0.1;

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float greenness = tex.g - max(tex.r, tex.b);
	float alpha = 1.0 - smoothstep(threshold, threshold + smoothness, greenness);
	COLOR = vec4(tex.rgb, tex.a * alpha);
}
