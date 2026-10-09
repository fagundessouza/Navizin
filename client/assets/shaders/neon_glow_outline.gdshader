shader_type canvas_item;

// Brilho neon ao redor da silhueta: várias amostras em anéis, fora da arte, tingidas
// de uma cor só. Pensado para um destaque grande e macio (um "pode clicar aqui"),
// não um contorno fino como o do navio.

uniform vec4 glow_color : source_color = vec4(1.0, 0.95, 0.15, 1.0);
/// Alcance do brilho, em pixels da textura (a imagem é grande; precisa de um raio grande).
uniform float glow_width : hint_range(0.0, 400.0) = 140.0;
uniform float glow_intensity : hint_range(0.0, 2.0) = 1.0;

const int RINGS = 3;
const int STEPS = 14;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float best = 0.0;
	if (c.a <= 0.5) {
		for (int ring = 1; ring <= RINGS; ring++) {
			float r = glow_width * float(ring) / float(RINGS);
			float falloff = 1.0 - float(ring - 1) / float(RINGS);
			for (int i = 0; i < STEPS; i++) {
				float ang = 6.2831853 * float(i) / float(STEPS);
				vec2 off = vec2(cos(ang), sin(ang)) * r * TEXTURE_PIXEL_SIZE;
				float a = texture(TEXTURE, UV + off).a;
				best = max(best, a * falloff);
			}
		}
	}
	COLOR = vec4(glow_color.rgb, glow_color.a * best * glow_intensity);
}
