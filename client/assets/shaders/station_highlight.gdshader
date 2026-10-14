shader_type canvas_item;
// Luz quente pulsando atrás de um botão de estação (Loja/Fabricar/Refinar/
// Cofre) nos bairros da cidade -- "destaque visual às estações" pedido
// explicitamente. Não é Lit 2D de verdade: os bairros são telas `Control`
// com fundo em `TextureRect`, e o conversor do addon Lit só sabe converter
// Sprite2D/AnimatedSprite2D/TileMapLayer (ver nota em `city_district_base.gd`)
// -- forçar o material receptor do Lit numa Control não documentada arrisca
// quebrar de um jeito difícil de depurar sem rodar o editor interativamente.
// Isto entrega o mesmo resultado visual (estação chamando atenção com uma
// luz quente e viva) com uma técnica que sei que funciona em cima de Control.
//
// Usa o mesmo ruído simplex do ShaderV2 que `item_rarity_glow.gdshader` já
// usa, pra textura do brilho variar organicamente em vez de ser um círculo
// estático.
#include "res://rgba/noise/simplex2d.gdshaderinc"

uniform vec4 glow_color : source_color = vec4(1.0, 0.78, 0.4, 1.0);
uniform float phase_offset : hint_range(0.0, 6.2832) = 0.0;

void fragment() {
	vec2 centered = UV - 0.5;
	float dist = length(centered) * 2.0;
	float t = TIME * 0.6 + phase_offset;

	float pulse = 0.65 + 0.2 * sin(t) + 0.15 * sin(t * 1.7 + 1.1);
	float shimmer = _simplex2dNoiseFunc(centered * 3.0 + vec2(0.0, t * 0.4)) * 0.15;

	float falloff = 1.0 - smoothstep(0.0, 1.0, dist);
	falloff = pow(falloff, 1.8);

	float alpha = clamp(falloff * (pulse + shimmer), 0.0, 1.0);
	COLOR = vec4(glow_color.rgb, alpha * glow_color.a);
}
