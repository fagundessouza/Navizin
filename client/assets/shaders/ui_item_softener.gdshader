shader_type canvas_item;
// Suaviza o recorte serrilhado/colado dos PNGs de item -- aplicado no
// `TextureRect` do ícone (slots de craft/equip/tooltip), por cima da
// textura normal. Dois efeitos: (1) uma sombra projetada suave por trás da
// silhueta (amostra o alpha da própria textura deslocado e borrado por um
// pequeno kernel, não um blur de tela inteira caro); (2) um feather na
// borda da silhueta (suaviza o degrau duro entre opaco/transparente do
// corte original, via `smoothstep` numa pequena faixa ao redor do alpha).
//
// CAMINHO: pedido original dizia `res://shaders/ui_item_softener.gdshader`,
// mas todo o resto do projeto usa `res://assets/shaders/*.gdshader` (10
// shaders existentes, todo loader referencia esse caminho) -- `res://shaders/`
// já existe só pra `materials/*.tres` (recursos de ShaderMaterial, não
// `.gdshader`). Fica aqui pra não abrir uma segunda convenção de pasta só
// pra este arquivo.

uniform vec4 shadow_color : source_color = vec4(0.0, 0.0, 0.0, 0.55);
uniform vec2 shadow_offset = vec2(0.03, 0.04);
uniform float shadow_blur : hint_range(0.0, 0.1) = 0.035;
uniform float feather_width : hint_range(0.0, 0.1) = 0.02;

// Godot não deixa passar o sampler `TEXTURE` como argumento de função livre
// (erro de compilação do shader) -- o loop de "blur" barato por disco de
// amostras fica direto dentro de `fragment()`, duplicado nos 2 pontos que
// precisam (feather da própria silhueta, sombra deslocada), em vez de uma
// função helper reutilizável.
const int SOFTENER_SAMPLES = 8;

void fragment() {
	vec4 tex_color = texture(TEXTURE, UV);

	// Feather: suaviza o degrau duro do corte original numa faixa estreita
	// ao redor da borda, em vez do alpha binário 0/1 que deixa serrilhado.
	float center_alpha = tex_color.a;
	float blurred_alpha = 0.0;
	for (int i = 0; i < SOFTENER_SAMPLES; i++) {
		float angle = float(i) / float(SOFTENER_SAMPLES) * TAU;
		vec2 offset = vec2(cos(angle), sin(angle)) * feather_width;
		blurred_alpha += texture(TEXTURE, UV + offset).a;
	}
	blurred_alpha /= float(SOFTENER_SAMPLES);
	float softened_alpha = mix(center_alpha, blurred_alpha, 0.6);

	// Sombra projetada: alpha da textura deslocado (sombra "cai" pro canto
	// escolhido) e borrado, pintada na cor de sombra, só onde o ícone em si
	// não cobre (senão a sombra pintaria por cima do próprio ícone).
	vec2 shadow_uv = UV - shadow_offset;
	float shadow_alpha = 0.0;
	if (shadow_uv.x >= 0.0 && shadow_uv.x <= 1.0 && shadow_uv.y >= 0.0 && shadow_uv.y <= 1.0) {
		float shadow_sample = 0.0;
		for (int i = 0; i < SOFTENER_SAMPLES; i++) {
			float angle = float(i) / float(SOFTENER_SAMPLES) * TAU;
			vec2 offset = vec2(cos(angle), sin(angle)) * shadow_blur;
			shadow_sample += texture(TEXTURE, shadow_uv + offset).a;
		}
		shadow_alpha = (shadow_sample / float(SOFTENER_SAMPLES)) * shadow_color.a;
	}
	shadow_alpha *= 1.0 - softened_alpha;

	vec3 out_color = mix(shadow_color.rgb, tex_color.rgb, softened_alpha);
	float out_alpha = max(softened_alpha, shadow_alpha);
	COLOR = vec4(out_color, out_alpha);
}
