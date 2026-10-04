shader_type canvas_item;

// Mar em tile repetido. Um único quad grande desenha tudo: cada pixel lê o tile
// pela posição de mundo, então a repetição é contínua em qualquer distância e
// não há uma instância por tile. Custo fixo: uma leitura de textura por pixel.

/// Tile do mar. `repeat_enable` faz a textura repetir fora de 0..1.
uniform sampler2D ocean_tex : repeat_enable, filter_nearest;

/// Lado do tile em pixels de mundo (a textura é 192×192).
uniform float tile_size: hint_range(16.0, 1024.0) = 192.0;

/// Velocidade da correnteza, em pixels de mundo por segundo.
uniform vec2 current_speed = vec2(6.0, 2.0);

/// Intensidade da maré: variação de brilho que sobe e desce devagar.
uniform float tide_strength: hint_range(0.0, 0.3) = 0.08;

/// Frequência da maré, em ciclos por segundo.
uniform float tide_frequency: hint_range(0.0, 1.0) = 0.12;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 drift = current_speed * TIME / tile_size;
	vec4 water = texture(ocean_tex, world_pos / tile_size + drift);

	float tide = sin(TIME * tide_frequency * 6.2831853);
	COLOR = vec4(water.rgb * (1.0 + tide * tide_strength), 1.0);
}
