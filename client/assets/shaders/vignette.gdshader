shader_type canvas_item;

// Escurece progressivamente em direção às bordas/cantos, por cima de tudo que
// já está desenhado atrás -- dá profundidade "cinematográfica" sem precisar
// de uma textura própria por cena.

uniform float radius : hint_range(0.0, 1.5) = 0.72;
uniform float softness : hint_range(0.0, 1.5) = 0.6;
uniform float strength : hint_range(0.0, 1.0) = 0.55;

void fragment() {
	vec2 uv = (UV - vec2(0.5)) * vec2(1.0, 1.0);
	float dist = length(uv) * 1.35;
	float vig = smoothstep(radius, radius - softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vig) * strength);
}
