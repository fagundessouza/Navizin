shader_type canvas_item;
// Aplicado só no NinePatchRect de fundo dos painéis (nunca na hierarquia de
// texto/botões por cima -- texto pulsando junto seria ilegível). Dá opacidade
// sutil ao miolo "de madeira" do quadro e um brilho metálico que pulsa na
// moldura ornamentada, com uma variação de tempo por célula (hash + seno),
// não um pulso uniforme sincronizado em todo o contorno.
//
// Separa miolo de moldura por BRILHO do pixel, não por posição/UV -- o
// NinePatchRect remapeia UV de um jeito não-linear pro 9-slice (corner fixo,
// borda só esticada num eixo, centro esticado nos dois), então checar
// "distância até a borda do retângulo" em UV dava uma faixa de brilho
// espalhada e borrada pelo painel inteiro. O miolo de `modal_frame_iron.png`
// é um chapado bem escuro (luma ~0.055); a moldura entalhada nunca é tão
// escura assim (~0.11 pra cima). Um corte de brilho simples separa os dois
// de forma confiável, pixel a pixel, sem depender do mapeamento de UV.

uniform float fill_alpha : hint_range(0.0, 1.0) = 0.85;
uniform float fill_threshold : hint_range(0.0, 1.0) = 0.09;
uniform float frame_softness : hint_range(0.01, 0.3) = 0.1;
uniform vec3 glow_color : source_color = vec3(1.0, 0.82, 0.42);
uniform float glow_strength : hint_range(0.0, 1.0) = 0.35;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
	float is_frame = smoothstep(fill_threshold, fill_threshold + frame_softness, luma);

	float cell = hash21(floor(SCREEN_UV * 180.0) + floor(TIME * 1.2));
	float pulse = 0.5 + 0.5 * sin(TIME * 1.7 + cell * 6.2831853);
	float glow = is_frame * pulse * glow_strength;

	vec3 color = tex.rgb + glow_color * glow * tex.a;
	float alpha = tex.a * mix(fill_alpha, 1.0, is_frame);
	COLOR = vec4(color, alpha);
}
