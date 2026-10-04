shader_type canvas_item;

// Mar em tile repetido, com iluminação. Um único quad grande desenha tudo: cada
// pixel lê o tile pela posição de mundo, então a repetição não tem limite.
// A luminância do desenho vira uma altura, e a inclinação dessa altura vira uma
// normal. Com ela, um sol de canto sombreia as cristas e produz reflexos que a
// maré faz deslizar. Custo: seis leituras de textura por pixel.

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

/// Intensidade do relevo: quanto a luz segue as cristas do desenho.
uniform float relief: hint_range(0.0, 3.0) = 1.2;

/// Intensidade dos reflexos do sol na superfície.
uniform float glint_strength: hint_range(0.0, 1.0) = 0.4;

/// Escurecimento das bordas da tela, para focar o centro.
uniform float vignette_strength: hint_range(0.0, 1.0) = 0.35;

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float luma(vec2 uv) {
	return dot(texture(ocean_tex, uv).rgb, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 drift = current_speed * TIME / tile_size;
	vec2 uv = world_pos / tile_size + drift;
	vec2 texel = 1.0 / vec2(textureSize(ocean_tex, 0));
	vec3 base = texture(ocean_tex, uv).rgb;

	// Segunda leitura em outra escala e deslocamento: quebra a grade de repetição
	// do tile sem precisar de mais arte.
	vec2 uv2 = world_pos / (tile_size * 1.37) + vec2(0.31, 0.57) - drift * 0.6;
	base = mix(base, texture(ocean_tex, uv2).rgb, 0.35);

	// Relevo: a inclinação do brilho vira a normal da superfície.
	float dx = luma(uv + vec2(texel.x, 0.0)) - luma(uv - vec2(texel.x, 0.0));
	float dy = luma(uv + vec2(0.0, texel.y)) - luma(uv - vec2(0.0, texel.y));
	vec3 normal = normalize(vec3(-dx * relief * 4.0, -dy * relief * 4.0, 1.0));

	// Sol de canto, vindo do alto à esquerda, com uma deriva lenta.
	float sun = 0.35 + 0.12 * sin(TIME * 0.05);
	vec3 light = normalize(vec3(-cos(sun), -sin(sun), 0.9));

	// Superfície plana tem diffuse 1.0; as cristas viradas para o sol ficam mais claras.
	float diffuse = dot(normal, light) / light.z;
	vec3 lit = base * mix(1.0, diffuse, 0.55);

	// Reflexo especular, que a maré faz deslizar pela superfície.
	vec3 half_vec = normalize(light + vec3(0.0, 0.0, 1.0));
	float glint = pow(max(dot(normal, half_vec), 0.0), 36.0);
	glint *= 0.7 + 0.3 * sin(TIME * 1.3 + world_pos.x * 0.01);
	lit += vec3(0.85, 0.95, 1.0) * glint * glint_strength;

	// Variação de grande escala, para quebrar a sensação de repetição do tile.
	float patch = 0.93 + 0.07 * sin(world_pos.x * 0.0031 + sin(world_pos.y * 0.0017) * 2.0) * cos(world_pos.y * 0.0023);
	lit *= patch;

	// Maré.
	lit *= 1.0 + sin(TIME * tide_frequency * 6.2831853) * tide_strength;

	// Vinheta de tela.
	vec2 centered = (SCREEN_UV - 0.5) * vec2(1.25, 1.0);
	lit *= 1.0 - vignette_strength * smoothstep(0.35, 0.8, length(centered));

	COLOR = vec4(lit, 1.0);
}
