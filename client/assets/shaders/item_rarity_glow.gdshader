shader_type canvas_item;
// Overlay de brilho pra borda de um slot de item, por cima do slot em si
// (não troca a arte do slot, só soma um brilho na borda) -- aplicado num
// ColorRect/TextureRect do tamanho do slot, com `mouse_filter = IGNORE` pra
// não atrapalhar o clique do botão por baixo.
//
// `rarity_color` vem de `CraftingManager.RARITIES[i]["color"]`. Raro/Épico/
// Místico (Azul/Amarelo/Laranja) só pulsam (`aura_mode = AURA_NONE`).
//
// `aura_mode` escolhe o efeito extra, decidido em código (`ship_status_modal.gd`/
// `captain_profile_modal.gd`) por regra de prioridade: Relíquia/Grimório com
// Float ou Refino alto -> rúnico; Float >= 0.95 (quase Perfeito) -> fogo
// sombrio; Refino >= +10 -> elétrico (era o único efeito antes desta
// atualização, chamado de "lightning"). Os três reusam a mesma técnica de
// hash+seno já usada em `gothic_panel.gdshader`, só mudando frequência, cor
// e o jeito que a "borda" é varrida -- não é um sistema de partícula novo.
//
// `refine_boost` (0 a 2) vem do nível de refino -- só sobe a partir de +10
// (rampa até +15), intensifica o pulso comum e, de forma bem mais visível,
// a frequência/limiar de qualquer um dos 3 modos de aura.

const int AURA_NONE = 0;
const int AURA_ELECTRIC = 1;
const int AURA_DARK_FIRE = 2;
const int AURA_RUNIC = 3;

uniform vec4 rarity_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int aura_mode : hint_range(0, 3) = 0;
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
	vec3 color = rarity_color.rgb;

	if (aura_mode == AURA_ELECTRIC) {
		// Faíscas correndo pela borda -- posição aproximada ao longo do
		// perímetro (não é arco-comprimento exato, mas corre visivelmente).
		float perimeter_pos = UV.x + UV.y;
		float freq = 30.0 + refine_boost * 25.0;
		float speed = 8.0 + refine_boost * 6.0;
		float cell = hash21(vec2(floor(perimeter_pos * freq + TIME * speed), 0.0));
		float threshold = 0.9 - refine_boost * 0.15;
		float spark = step(threshold, cell);
		glow += border * spark * (1.6 + refine_boost) * intensity;
		color = mix(color, vec3(0.75, 0.9, 1.0), spark * 0.6);
	} else if (aura_mode == AURA_DARK_FIRE) {
		// Chama lenta e irregular, tingindo pra brasa (laranja/vermelho) nos
		// picos -- mais lenta e "respirando" que o elétrico, não corre pela
		// borda, pulsa em blocos maiores.
		float freq = 10.0 + refine_boost * 8.0;
		float cell = hash21(floor(UV * freq) + floor(TIME * (2.5 + refine_boost * 1.5)));
		float flicker = smoothstep(0.5, 1.0, cell);
		glow += border * flicker * (1.3 + refine_boost * 0.8) * intensity;
		color = mix(color, vec3(0.95, 0.35, 0.1), flicker * 0.7);
	} else if (aura_mode == AURA_RUNIC) {
		// Glifos girando lento ao redor da borda -- período mais longo que
		// os outros dois, pra parecer um encantamento ativo, não um efeito
		// de combate.
		float angle = atan(UV.y - 0.5, UV.x - 0.5);
		float ring = sin(angle * 6.0 + TIME * (0.8 + refine_boost * 0.6));
		float rune = step(0.8, hash21(vec2(floor(angle * 10.0), floor(TIME * 0.5 + refine_boost))));
		glow += border * (0.4 + 0.4 * ring) * (1.0 + refine_boost * 0.6) * intensity;
		glow += border * rune * 1.2 * intensity;
		color = mix(color, vec3(0.6, 0.85, 0.95), 0.3);
	}

	COLOR = vec4(color, clamp(glow, 0.0, 1.0) * rarity_color.a);
}
