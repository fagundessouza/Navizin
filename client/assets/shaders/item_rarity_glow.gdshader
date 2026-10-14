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
// MUDA GRADUALMENTE (`floor(TIME*speed)` vira `TIME*speed` suave), então a
// energia parece fluir pela borda em vez de picotar; (3) brilho em duas
// camadas (núcleo mais apertado + halo mais largo e fraco) pra um volume
// mais "AAA", não só uma linha fina de luz.

const int AURA_NONE = 0;
const int AURA_ELECTRIC = 1;
const int AURA_DARK_FIRE = 2;
const int AURA_RUNIC = 3;

uniform vec4 rarity_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int aura_mode : hint_range(0, 3) = 0;
uniform float refine_boost : hint_range(0.0, 2.0) = 0.0;
uniform float phase_offset : hint_range(0.0, 6.2832) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Ruído de valor suave (interpola entre células de hash) -- em vez do hash
// cru reavaliado a cada frame, isso dá uma corrente contínua, sem saltos.
float flow_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
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
		// Chama lenta e orgânica -- mesmo `flow_noise`, frequência espacial
		// menor e movimento mais devagar, pra "respirar" em vez de tremer.
		float freq = 6.0 + refine_boost * 4.0;
		float speed = 0.6 + refine_boost * 0.5;
		float flicker = flow_noise(UV * freq + vec2(0.0, t * speed));
		float fire = smoothstep(0.4, 0.85, flicker);
		glow += border * fire * (0.9 + refine_boost * 0.6) * intensity;
		color = mix(color, vec3(0.95, 0.35, 0.1), fire * 0.6);
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

	COLOR = vec4(color, clamp(glow, 0.0, 1.0) * rarity_color.a);
}
