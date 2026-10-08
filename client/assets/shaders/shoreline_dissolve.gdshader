shader_type canvas_item;

// Dissolução da borda do tile por ruído: em vez do corte reto do alfa original (a
// silhueta recortada da arte), a transparência cresce de forma orgânica perto da borda,
// guiada por um ruído, e a última faixa visível ganha uma cor de água para casar com o
// oceano por baixo. Isso NÃO reconstrói a arte pintada do tile; é uma máscara aplicada
// sobre ela. Dois estilos de pintura (os tiles do kit e o shader do oceano) nunca vão
// ficar 100% idênticos pixel a pixel — isto reduz o "recorte de figurinha", não apaga
// a diferença de estilo.

uniform sampler2D water_noise : repeat_enable, filter_linear;

/// Tamanho do ruído em pixels de tela: menor = ondas mais finas na borda.
uniform float noise_scale: hint_range(8.0, 256.0) = 64.0;

/// Largura da faixa de dissolução, em fração do alfa original (0 a 1).
uniform float dissolve_width: hint_range(0.01, 0.6) = 0.22;

/// Quanto o ruído desloca a borda para dentro/fora.
uniform float noise_strength: hint_range(0.0, 1.0) = 0.6;

/// Cor da água do oceano, para a última faixa visível da borda se misturar a ela.
uniform vec4 water_tint : source_color = vec4(0.10, 0.22, 0.28, 1.0);

/// Velocidade da deriva do ruído, para a espuma da borda não ficar parada.
uniform vec2 drift = vec2(0.015, 0.01);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 noise_uv = (SCREEN_UV * SCREEN_PIXEL_SIZE.y * 0.0) + UV; // mantém UV local ao tile
	vec2 nuv = UV * (1.0 / SCREEN_PIXEL_SIZE.x) / noise_scale + TIME * drift;
	float n = texture(water_noise, nuv).r;

	// A silhueta original já definida pelo alfa da arte: perto de onde ela cai a zero
	// (a borda recortada), o ruído decide ponto a ponto se aquele pixel dissolve antes.
	float edge = smoothstep(0.0, dissolve_width, tex.a);
	float dissolved = smoothstep(0.5 - noise_strength * 0.5, 0.5 + noise_strength * 0.5, n * edge + (1.0 - edge) * n * 0.4);

	float alpha = tex.a * dissolved;
	// Faixa de espuma/água na própria borda que sobra, para casar com o oceano por baixo.
	float shoreline = (1.0 - edge) * dissolved;
	vec3 color = mix(tex.rgb, water_tint.rgb, shoreline * 0.65);
	COLOR = vec4(color, alpha) * COLOR.a;
}
