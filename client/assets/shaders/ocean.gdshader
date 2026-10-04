shader_type canvas_item;

// Mar procedural em coordenadas de mundo: a onda é calculada a partir da
// posição global do fragmento, então o padrão é contínuo entre telas e não
// depende do tamanho do retângulo que o desenha.

uniform vec4 deep_color : source_color = vec4(0.04, 0.22, 0.34, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.09, 0.38, 0.52, 1.0);

/// Escala espacial das ondas (menor = ondas maiores).
uniform float wave_scale: hint_range(0.001, 0.2) = 0.02;

/// Velocidade de deslocamento das ondas.
uniform float wave_speed: hint_range(0.0, 2.0) = 0.15;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = world_pos * wave_scale;

	float w = sin(p.x * 3.0 + t)
		+ sin(p.y * 4.0 - t * 1.3)
		+ sin((p.x + p.y) * 2.0 + t * 0.7);

	// Soma de três senos está em [-3, 3]; normaliza para [0, 1].
	w = w / 6.0 + 0.5;

	COLOR = mix(deep_color, shallow_color, w);
}
