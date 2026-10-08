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
	// Referência fixa (não SCREEN_PIXEL_SIZE): a amostra do ruído não pode depender do
	// zoom da câmera, senão o mesmo sprite dissolve diferente só por estar mais perto ou
	// mais longe. 1280 é só uma constante de referência (uma largura de tela comum),
	// não o tamanho real de nada.
	vec2 nuv = UV * (1280.0 / noise_scale) + TIME * drift;
	float n = texture(water_noise, nuv).r;

	// O ruído só DESLOCA o alfa original, não o substitui: um pixel bem interior
	// (tex.a = 1) nunca dissolve, não importa o valor do ruído ali. Só a faixa que já
	// estava perto da borda (tex.a baixo) é que pode cair pra transparente antes ou
	// depois, dependendo do ruído -- é isso que dá o contorno orgânico.
	float perturbed = tex.a + (n - 0.5) * noise_strength;
	float alpha = smoothstep(0.0, dissolve_width, perturbed) * step(0.001, tex.a);

	// Faixa de espuma/água: onde a arte ainda tinha alfa, mas o ruído já dissolveu ali.
	float shoreline = clamp(tex.a - alpha, 0.0, 1.0);
	vec3 color = mix(tex.rgb, water_tint.rgb, shoreline * 0.65);
	COLOR = vec4(color, alpha) * COLOR.a;
}
