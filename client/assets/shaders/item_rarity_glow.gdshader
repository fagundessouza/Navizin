shader_type canvas_item;
// Overlay de brilho pra borda de um slot de item, por cima do slot em si
// (não troca a arte do slot, só soma um brilho na borda) -- aplicado num
// ColorRect/TextureRect do tamanho do slot, com `mouse_filter = IGNORE` pra
// não atrapalhar o clique do botão por baixo.
//
// `rarity_color` vem de `CraftingManager.RARITIES[i]["color"]`. Raro/Épico/
// Místico (Azul/Amarelo/Laranja) só pulsam; Lendário/Divino (Roxo/Vermelho)
// também recebem faíscas correndo pela borda (`lightning`) -- mesma técnica
// de hash+seno já usada em `gothic_panel.gdshader`, não um sistema de
// partícula novo.
//
// `refine_boost` (0 a 2) vem do nível de refino do item equipado --
// `ship_status_modal.gd` só manda um valor > 0 a partir de +10 (rampa até
// +15), então refinar de +1 a +9 não muda o visual do brilho, só +10 pra
// cima fica progressivamente mais aceso/raivoso. Afeta tanto o pulso comum
// (todo item com brilho fica um pouco mais forte) quanto -- de forma bem
// mais visível -- a frequência e o limiar das faíscas de Lendário/Divino.

uniform vec4 rarity_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool lightning = false;
uniform float refine_boost : hint_range(0.0, 2.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 edge_dist = min(UV, vec2(1.0) - UV);
	float border = 1.0 - smoothstep(0.08, 0.18, min(edge_dist.x, edge_dist.y));

	float pulse = (0.55 + 0.45 * sin(TIME * 2.4)) * (1.0 + refine_boost * 0.3);
	float glow = border * pulse * intensity;

	if (lightning) {
		// Posição aproximada ao longo do perímetro (não é um arco-comprimento
		// exato, mas o bastante pra "correr" visivelmente pela borda).
		float perimeter_pos = UV.x + UV.y;
		float freq = 30.0 + refine_boost * 25.0;
		float speed = 8.0 + refine_boost * 6.0;
		float cell = hash21(vec2(floor(perimeter_pos * freq + TIME * speed), 0.0));
		float threshold = 0.9 - refine_boost * 0.15;
		float spark = step(threshold, cell);
		glow += border * spark * (1.6 + refine_boost) * intensity;
	}

	COLOR = vec4(rarity_color.rgb, clamp(glow, 0.0, 1.0) * rarity_color.a);
}
