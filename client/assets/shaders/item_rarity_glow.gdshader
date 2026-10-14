shader_type canvas_item;
// Overlay de brilho pra borda de um slot de item, por cima do slot em si
// (não troca a arte do slot, só soma um brilho na borda) -- aplicado num
// ColorRect/TextureRect do tamanho do slot, com `mouse_filter = IGNORE` pra
// não atrapalhar o clique do botão por baixo.
//
// `rarity_color` vem de `CraftingManager.RARITIES[i]["color"]`. `aura_mode`
// escolhe o efeito extra, decidido em código por regra de prioridade
// (`ship_status_modal.gd`/`captain_profile_modal.gd`): Relíquia/Grimório
// com Float ou Refino alto -> rúnico; Float >= 0.95 -> fogo sombrio;
// Lendário/Divino por padrão, ou Refino >= +10 em qualquer raridade com
// brilho -> elétrico.
//
// SEM FLICKER: a versão anterior usava `step()` puro sobre hash por célula
// recalculado a cada frame -- cada pixel virava sorteio binário ligado/
// desligado em sequência, o que lia como "piscando feio" em vez de um
// efeito fluindo. Esta troca: (1) o pulso comum agora soma 2 senoides em
// frequências diferentes (nunca repete o mesmo ciclo simples) e cada slot
// recebe um `phase_offset` próprio (`ship_status_modal.gd` passa um valor
// por índice), pra uma GRADE de 20 canhões não piscar tudo em uníssono;
// (2) as "faíscas"/"chamas"/"runas" usam `smoothstep()` sobre ruído que
// MUDA GRADUALMENTE, então a energia parece fluir pela borda em vez de
// picotar; (3) brilho em duas camadas (núcleo mais apertado + halo mais
// largo e fraco) pra um volume mais "AAA", não só uma linha fina de luz.
//
// SHADERV2 ("Visual Shader Node Library", arkology/MIT -- instalado solto
// na raiz do projeto em vez de dentro de addons/, por isso nunca apareceu
// como plugin na lista de addons): usa 3 funções de lá em vez de
// reimplementar ruído/fogo/brilho na mão -- `_simplex2dNoiseFunc` (ruído
// coerente de verdade no lugar do hash-grid caseiro de antes), `_fireFXFunc`
// (chama em camadas de verdade pro modo Fogo Sombrio, no lugar de um
// flicker genérico) e `_shineFunc` (um brilho de reflexo varrendo a borda
// na diagonal, "shine" de loot AAA, em todo item com brilho de raridade
// ativo). As funções de glow por blur da biblioteca (`_outerGlowFunc`/
// `_innerGlowFunc`) ficaram de fora: cada uma amostra a textura em até 29x29
// (841 taps) por pixel, caro demais pra grade de 20 canhões simultâneos --
// o glow em duas camadas por distância-até-a-borda já cobre o volume sem
// esse custo.
#include "res://rgba/noise/simplex2d.gdshaderinc"
#include "res://rgba/fireFX.gdshaderinc"
#include "res://rgba/shineFX.gdshaderinc"

const int AURA_NONE = 0;
const int AURA_ELECTRIC = 1;
const int AURA_DARK_FIRE = 2;
const int AURA_RUNIC = 3;

uniform vec4 rarity_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int aura_mode : hint_range(0, 3) = 0;
uniform float refine_boost : hint_range(0.0, 2.0) = 0.0;
uniform float phase_offset : hint_range(0.0, 6.2832) = 0.0;

// Wrapper fino sobre o ruído simplex do ShaderV2 -- mantém a mesma
// assinatura/faixa [0,1] que o `flow_noise()` caseiro de antes tinha, pra
// não precisar reescrever as 3 chamadas abaixo.
float flow_noise(vec2 p) {
	return _simplex2dNoiseFunc(p);
}

void fragment() {
	vec2 edge_dist = min(UV, vec2(1.0) - UV);
	float d = min(edge_dist.x, edge_dist.y);
	// Duas faixas: núcleo apertado (linha nítida) + halo largo e suave
	// (sensação de volume por trás da borda), somadas.
	float core = 1.0 - smoothstep(0.05, 0.1, d);
	float halo = 1.0 - smoothstep(0.08, 0.28, d);
	float border = core + halo * 0.45;

	float t = TIME + phase_offset;
	float pulse = 0.55 + 0.25 * sin(t * 1.6) + 0.2 * sin(t * 2.3 + 1.7);
	pulse *= (1.0 + refine_boost * 0.3);
	float glow = border * pulse * intensity;
	vec3 color = rarity_color.rgb;

	if (aura_mode == AURA_ELECTRIC) {
		// Energia correndo pela borda num fluxo contínuo (não mais sorteio
		// binário por frame) -- a "velocidade" do fluxo escala com o refino.
		float perimeter_pos = UV.x + UV.y;
		float freq = 18.0 + refine_boost * 14.0;
		float speed = 1.6 + refine_boost * 1.4;
		float flow = flow_noise(vec2(perimeter_pos * freq, t * speed));
		float spark = smoothstep(0.55, 0.95, flow);
		glow += border * spark * (1.0 + refine_boost * 0.6) * intensity;
		color = mix(color, vec3(0.75, 0.9, 1.0), spark * 0.5);
	} else if (aura_mode == AURA_DARK_FIRE) {
		// Chama de verdade (ShaderV2 `_fireFXFunc`, 3 bandas de cor sobre FBM
		// de Perlin) em vez do flicker genérico de antes -- preto -> vermelho
		// sombrio -> laranja quase branco, subindo pela UV com o tempo.
		float speed = 0.35 + refine_boost * 0.3;
		vec4 fire_col = _fireFXFunc(UV * (2.0 + refine_boost), vec2(0.0, 1.0), speed, t,
			vec4(0.0, 0.0, 0.0, 0.0), vec4(0.55, 0.08, 0.02, 1.0), vec4(1.0, 0.55, 0.15, 1.0),
			0.0, 0.45, 0.85);
		float fire = fire_col.a;
		glow += border * fire * (0.9 + refine_boost * 0.6) * intensity;
		color = mix(color, fire_col.rgb, fire * 0.6);
	} else if (aura_mode == AURA_RUNIC) {
		// Glifos girando bem devagar ao redor da borda -- período mais
		// longo que os outros dois, pra parecer um encantamento ativo.
		float angle = atan(UV.y - 0.5, UV.x - 0.5);
		float ring = sin(angle * 6.0 + t * (0.5 + refine_boost * 0.4));
		float rune_flow = flow_noise(vec2(angle * 3.0, t * 0.25 + refine_boost * 0.2));
		float rune = smoothstep(0.6, 0.9, rune_flow);
		glow += border * (0.35 + 0.35 * ring) * (1.0 + refine_boost * 0.5) * intensity;
		glow += border * rune * 0.8 * intensity;
		color = mix(color, vec3(0.6, 0.85, 0.95), 0.3);
	}

	// ShaderV2 `_shineFunc`: um brilho de reflexo varrendo a borda na
	// diagonal, igual ao "shine" que passa por um item raro num loot AAA --
	// `_loc_shine` anda de -1.4 a 1.4 ao longo do tempo pra cruzar o quadro
	// inteiro e sumir, em vez de ficar parado. Alimenta com uma base opaca
	// (alpha=1) só pra função aplicar o termo; o que entra no glow final é a
	// DIFERENÇA que ela soma, não a base em si.
	vec4 shine_base = vec4(0.0, 0.0, 0.0, 1.0);
	float shine_loc = mod(t * 0.35, 2.8) - 1.4;
	vec4 shine_result = _shineFunc(shine_base, UV - 0.5, shine_loc, 0.78, 0.5, 0.35, 1.0, 0.0, vec3(1.0));
	float shine_power = shine_result.r;
	glow += border * shine_power * intensity;
	color += shine_power * 0.6;

	COLOR = vec4(color, clamp(glow, 0.0, 1.0) * rarity_color.a);
}
