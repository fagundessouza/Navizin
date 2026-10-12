shader_type canvas_item;

// "Nevoeiro da morte": em vez de um fade liso, a cor escura entra em manchas
// (lida pelo mesmo ruído usado na névoa do oceano), como bruma se acumulando
// na tela antes de cortar a cena.

uniform sampler2D noise_tex;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.015, 0.02, 0.03, 1.0);

void fragment() {
	vec2 uv = UV * 2.5 + vec2(TIME * 0.015, TIME * 0.01);
	float n = texture(noise_tex, uv).r;
	float alpha = smoothstep(0.0, 1.0, progress * 1.35 - n * 0.35);
	COLOR = vec4(fog_color.rgb, clamp(alpha, 0.0, 1.0));
}
