extends Node
## Autoload: catálogo de todo item fabricável do jogo -- peças do Galeão
## (Vela/Casco/Proa/Canhão em Tiers I-IV, Munições, Relíquias, Leme) e
## Equipamentos do Capitão (Brincos/Colares/Anéis/Cintos/Trajes em Tiers I-IV,
## Grimórios). Leme não tinha catálogo nem receita no pedido original (ver
## nota em `_HELM`); os 5 acessórios do Capitão também não existiam até esta
## rodada -- só tinham nomes cosméticos sem dado real em `STUB_INVENTORY`.
##
## Cada item: {id, name, category (= slot do Galeão/Capitão, ou "municao",
## que não tem slot em lugar nenhum ainda), tier (0 = sem tier), icon
## (Texture2D, carregado com `preload` -- os arquivos já existem no
## projeto), stats}.
##
## `stats` do Galeão (`hull_bonus`/`cargo_bonus`/`speed_bonus`/
## `damage_mult_bonus`) são somados por `ship_base.gd.recalc_equipment_bonuses()`.
## `stats` do Capitão (`leadership_bonus`/`boarding_crit_bonus`/
## `node_speed_bonus`/`armor_pen_bonus`) são somados por
## `PlayerInventory.get_captain_bonuses()` -- um sistema PARALELO, porque um
## brinco não deveria mexer no casco do navio. `elemental_damage_bonus`
## (Munição/Grimório) é só exibido por ora -- não existe ainda um sistema de
## combate ou de troca de munição pra consumir esse número, igual ao
## `cannon_damage_mult` do navio: o valor está certo, só não alimenta nada.
##
## `RECIPES`: id -> {output, station ("forja"/"estaleiro"/"boticario"/
## "feira"), materials}. Receitas em Tier são geradas em loop a partir de
## `_TIER_MATERIALS`, não escritas 4 vezes à mão.

var ITEMS: Dictionary = {}
var RECIPES: Dictionary = {}

const TIER_NAMES: Array[String] = ["I", "II", "III", "IV"]
const ICON_DIR: String = "res://assets/ui/icons/items/"

## Materiais por categoria/tier -- índice 0 = Tier I .. 3 = Tier IV.
const _TIER_MATERIALS: Dictionary = {
	"armamento": [
		{"Liga de Ferro": 3, "Pólvora": 2, "Essência de Monstro Marinho": 1},
		{"Liga de Cobre": 3, "Pólvora": 3, "Essência de Monstro Marinho": 2},
		{"Liga de Ouro": 3, "Pólvora": 4, "Essência de Monstro Marinho": 3},
		{"Liga de Ouro": 5, "Pólvora": 6, "Essência de Monstro Marinho": 5},
	],
	"vela": [
		{"Lona": 3, "Cordame": 2, "Vento Rúnico": 1},
		{"Lona Reforçada": 3, "Cordame": 3, "Vento Rúnico": 2},
		{"Seda": 3, "Cordame": 4, "Vento Rúnico": 3},
		{"Seda": 5, "Cordame": 6, "Vento Rúnico": 5},
	],
	"casco": [
		{"Madeira de Carvalho": 4, "Placas de Ferro": 2},
		{"Madeira de Carvalho": 6, "Placas de Ferro": 4},
		{"Escamas de Kraken": 4, "Placas de Ferro": 6},
		{"Escamas de Kraken": 7, "Placas de Ferro": 9},
	],
	"proa": [
		{"Madeira Nobre": 3, "Relíquia de Osso": 1},
		{"Madeira Nobre": 5, "Relíquia de Osso": 2},
		{"Madeira Nobre": 5, "Relíquia de Ouro": 2},
		{"Madeira Nobre": 8, "Relíquia de Ouro": 3},
	],
	"brincos": [
		{"Prata": 2, "Pérola Negra": 1},
		{"Prata": 3, "Pérola Negra": 2},
		{"Ouro": 2, "Pérola Negra": 2},
		{"Ouro": 3, "Diamante Sombrio": 1},
	],
	"colar": [
		{"Prata": 2, "Osso de Leviatã": 1},
		{"Prata": 3, "Osso de Leviatã": 2},
		{"Ouro": 2, "Osso de Leviatã": 2},
		{"Ouro": 3, "Osso de Leviatã": 3},
	],
	"anel": [
		{"Prata": 2, "Bússola Fragmentada": 1},
		{"Prata": 3, "Bússola Fragmentada": 2},
		{"Ouro": 2, "Bússola Fragmentada": 2},
		{"Ouro": 3, "Bússola Fragmentada": 3},
	],
	"cinto": [
		{"Couro": 2, "Fivela de Bronze": 1},
		{"Couro": 3, "Fivela de Bronze": 2},
		{"Couro Reforçado": 2, "Fivela de Bronze": 3},
		{"Couro Reforçado": 3, "Fivela de Prata": 2},
	],
	"trajes": [
		{"Couro": 3, "Linho Encerado": 2},
		{"Couro Reforçado": 3, "Linho Encerado": 3},
		{"Couro Reforçado": 4, "Veludo Corsário": 2},
		{"Escamas de Kraken": 3, "Veludo Corsário": 4},
	],
}

## Bônus por tier (índice 0 = Tier I).
const _TIER_STATS: Dictionary = {
	"armamento": [{"damage_mult_bonus": 0.0}, {"damage_mult_bonus": 0.3, "armor_pen_bonus": 0.05}, {"damage_mult_bonus": 0.65, "armor_pen_bonus": 0.12}, {"damage_mult_bonus": 1.0, "armor_pen_bonus": 0.22}],
	"vela": [{"speed_bonus": 0.0}, {"speed_bonus": 15.0}, {"speed_bonus": 30.0}, {"speed_bonus": 50.0}],
	"casco": [{"hull_bonus": 0.0, "cargo_bonus": 0.0}, {"hull_bonus": 200.0, "cargo_bonus": 20.0}, {"hull_bonus": 450.0, "cargo_bonus": 40.0}, {"hull_bonus": 800.0, "cargo_bonus": 70.0}],
	"proa": [{"speed_bonus": 0.0}, {"speed_bonus": 5.0}, {"speed_bonus": 10.0}, {"speed_bonus": 18.0}],
	"brincos": [{"leadership_bonus": 0.0}, {"leadership_bonus": 5.0}, {"leadership_bonus": 12.0}, {"leadership_bonus": 22.0}],
	"colar": [{"boarding_crit_bonus": 0.0}, {"boarding_crit_bonus": 0.05}, {"boarding_crit_bonus": 0.12}, {"boarding_crit_bonus": 0.22}],
	"anel": [{"node_speed_bonus": 0.0}, {"node_speed_bonus": 8.0}, {"node_speed_bonus": 18.0}, {"node_speed_bonus": 32.0}],
	"cinto": [{"armor_pen_bonus": 0.0}, {"armor_pen_bonus": 0.08}, {"armor_pen_bonus": 0.18}, {"armor_pen_bonus": 0.32}],
	"trajes": [{"leadership_bonus": 0.0}, {"leadership_bonus": 4.0}, {"leadership_bonus": 10.0}, {"leadership_bonus": 18.0}],
}

const _TIER_DISPLAY_NAMES: Dictionary = {
	"armamento": "Canhão", "vela": "Vela", "casco": "Casco", "proa": "Proa",
	"brincos": "Brincos", "colar": "Colar", "anel": "Anel", "cinto": "Cinto", "trajes": "Trajes",
}

## Ícone POR TIER (4 distintos, ordem de "fantasia" crescente) pra cada
## categoria tierizada -- Canhão/Vela/Casco/Proa vêm de
## "Catálogo Gótico de Armas Navais.png" (Linha 1 = Canhões, Linhas 2/3/4 =
## Velas/Cascos/Proas, nessa ordem -- é como a própria imagem organiza, não
## uma escolha nossa); os 5 acessórios do Capitão vêm da prancha
## `Gemini_Generated_Image...zb2.jpeg` (uma rodada anterior).
##
## ROLETA ANTERIOR CORRIGIDA: até a rodada passada, Canhão/Vela/Casco/Proa
## usavam 1 ícone genérico reaproveitado de OUTRAS pranchas (pin de distrito,
## traje de capitão) por categoria inteira -- "Catálogo Gótico de Armas
## Navais.png" já existia em `~/Downloads/Tortuga/` desde antes, só nunca
## tinha sido localizado/usado. Agora cada tier tem o ícone de verdade da
## linha/coluna certa dessa prancha.
const _TIER_ICONS: Dictionary = {
	"armamento": ["armamento_t1.png", "armamento_t2.png", "armamento_t3.png", "armamento_t4.png"],
	"vela": ["vela_t1.png", "vela_t2.png", "vela_t3.png", "vela_t4.png"],
	"casco": ["casco_t1.png", "casco_t2.png", "casco_t3.png", "casco_t4.png"],
	"proa": ["proa_t1.png", "proa_t2.png", "proa_t3.png", "proa_t4.png"],
	"brincos": ["brincos_t1.png", "brincos_t2.png", "brincos_t3.png", "brincos_t4.png"],
	"colar": ["colar_t1.png", "colar_t2.png", "colar_t3.png", "colar_t4.png"],
	"anel": ["anel_t1.png", "anel_t2.png", "anel_t3.png", "anel_t4.png"],
	"cinto": ["cinto_t1.png", "cinto_t2.png", "cinto_t3.png", "cinto_t4.png"],
	"trajes": ["trajes_t1.png", "trajes_t2.png", "trajes_t3.png", "trajes_t4.png"],
}

## "Catálogo de Munições Fantásticas": sem slot em lugar nenhum ainda (nem
## do navio, nem do capitão) -- fica guardada no inventário pra quando
## existir bordada por tipo de bala. `elemental_damage_bonus` é só pra
## tooltip mostrar o dano elemental da munição, sem sistema de troca de
## bala pra consumir isso ainda.
##
## Ícone de cada tipo vem da LINHA certa de "Catálogo de Munições
## Fantásticas.png" (Pólvora/Fogo/Gelo/Veneno/Prata/Ouro/Diamante/Cursada,
## 8 linhas) -- a prancha não tem uma 9ª linha separada pra Alma, então
## reaproveita o ícone de Cursada (os dois são "sombrios", a diferença fica
## só no nome/bônus).
##
## PACOTES COMERCIAIS: cada tipo vira 4 itens (P/M/G/GG), gerados em loop --
## o pacote só multiplica a QUANTIDADE de material (fabricar um lote maior de
## uma vez), não o bônus por bala; `elemental_damage_bonus` fica igual nos 4
## tamanhos do mesmo tipo.
const _AMMO_TYPES: Dictionary = {
	"polvora": {"name": "Pólvora", "ore": "Pólvora", "stats": {}, "icon": "municao_polvora.png"},
	"fogo": {"name": "Fogo", "ore": "Minério de Fogo", "stats": {"elemental_damage_bonus": 0.12}, "icon": "municao_fogo.png"},
	"gelo": {"name": "Gelo", "ore": "Minério de Gelo", "stats": {"elemental_damage_bonus": 0.12}, "icon": "municao_gelo.png"},
	"veneno": {"name": "Veneno", "ore": "Minério de Veneno", "stats": {"elemental_damage_bonus": 0.1}, "icon": "municao_veneno.png"},
	"prata": {"name": "Prata", "ore": "Minério de Prata", "stats": {"elemental_damage_bonus": 0.15}, "icon": "municao_prata.png"},
	"ouro": {"name": "Ouro", "ore": "Minério de Ouro", "stats": {"elemental_damage_bonus": 0.15}, "icon": "municao_ouro.png"},
	"diamante": {"name": "Diamante", "ore": "Minério de Diamante", "stats": {"elemental_damage_bonus": 0.2}, "icon": "municao_diamante.png"},
	"alma": {"name": "Alma", "ore": "Minério de Alma", "stats": {"elemental_damage_bonus": 0.22}, "icon": "municao_alma.png"},
	"cursada": {"name": "Cursada", "ore": "Minério Amaldiçoado", "stats": {"elemental_damage_bonus": 0.25}, "icon": "municao_cursada.png"},
}

## Pacote P = unidade básica (mesmo custo que a munição avulsa de antes);
## M/G/GG multiplicam o material pelo tamanho do lote, pra fabricar de uma
## vez em vez de clicar "Fabricar" repetidas vezes.
const _PACKAGE_SIZES: Array[Dictionary] = [
	{"id": "p", "label": "Pacote P", "mult": 1},
	{"id": "m", "label": "Pacote M", "mult": 3},
	{"id": "g", "label": "Pacote G", "mult": 8},
	{"id": "gg", "label": "Pacote Extra G", "mult": 20},
]


func _build_ammo_catalog() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for type_id in _AMMO_TYPES:
		var data: Dictionary = _AMMO_TYPES[type_id]
		for pkg in _PACKAGE_SIZES:
			var mult: int = pkg["mult"]
			result.append({
				"id": "municao_%s_%s" % [type_id, pkg["id"]],
				"name": "Munição de %s -- %s" % [data["name"], pkg["label"]],
				"materials": {"Esfera de Ferro": 2 * mult, data["ore"]: 1 * mult},
				"stats": data["stats"],
				"icon": data["icon"],
			})
	return result

## "Arpões de Caça Marítima": categoria separada das balas de pistola/esferas
## de canhão, pros combates do Sea Hunt contra monstros de profundeza --
## ainda sem sistema de Sea Hunt de verdade, então fica guardada no
## inventário igual à Munição (`elemental_damage_bonus`/`armor_pen_bonus` só
## pra tooltip, nada consome isso ainda). Ícone reaproveitado da prancha de
## Munições (coluna de cartucho/bala, mais "farpado" que as esferas de
## canhão) -- não existe arte de arpão dedicada em nenhuma prancha recebida.
const _HARPOONS: Array[Dictionary] = [
	{"id": "arpao_t1", "name": "Arpão de Caça Tier I", "materials": {"Madeira Nobre": 2, "Esfera de Ferro": 2}, "stats": {}, "icon": "arpao.png"},
	{"id": "arpao_t2", "name": "Arpão Farpado Tier II", "materials": {"Madeira Nobre": 3, "Liga de Ferro": 2}, "stats": {"armor_pen_bonus": 0.08}, "icon": "arpao.png"},
	{"id": "arpao_t3", "name": "Arpão de Aço Tier III", "materials": {"Liga de Cobre": 3, "Dente de Leviatã": 1}, "stats": {"armor_pen_bonus": 0.16, "elemental_damage_bonus": 0.1}, "icon": "arpao.png"},
	{"id": "arpao_t4", "name": "Arpão Rúnico Tier IV", "materials": {"Liga de Ouro": 3, "Dente de Leviatã": 2, "Vento Rúnico": 1}, "stats": {"armor_pen_bonus": 0.25, "elemental_damage_bonus": 0.2}, "icon": "arpao.png"},
]

## "Relíquias Místicas em Grade Gótica": as 50 células da prancha, uma
## relíquia cada -- nomes lendários estilo D&D/BDO/Lineage 2 (gerados por
## combinação de substantivo místico + epíteto épico, não escritos 50x à
## mão). Ícone de cada uma é o recorte exato daquela célula
## (`relics/relic_NN.png`, NN = índice na prancha 10x5, linha a linha).
## Ficam na Boticário na reestruturação urbana (seção 3 de duas rodadas
## atrás) -- antes era fabricada no Estaleiro.
const _RELICS: Array[Dictionary] = [
	{"id": "relic_coracao_do_leviata_ancestral_00", "name": "Coração do Leviatã Ancestral", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 100.0}, "icon": "relics/relic_00.png"},
	{"id": "relic_olho_da_rainha_do_gelo_01", "name": "Olho da Rainha do Gelo", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"cargo_bonus": 15.0}, "icon": "relics/relic_01.png"},
	{"id": "relic_calice_do_sangue_antigo_02", "name": "Cálice do Sangue Antigo", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"speed_bonus": 10.0}, "icon": "relics/relic_02.png"},
	{"id": "relic_coroa_do_leviata_negro_03", "name": "Coroa do Leviatã Negro", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"damage_mult_bonus": 0.1}, "icon": "relics/relic_03.png"},
	{"id": "relic_lagrima_do_kraken_primordial_04", "name": "Lágrima do Kraken Primordial", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"leadership_bonus": 8.0}, "icon": "relics/relic_04.png"},
	{"id": "relic_fragmento_do_caos_runico_05", "name": "Fragmento do Caos Rúnico", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"boarding_crit_bonus": 0.05}, "icon": "relics/relic_05.png"},
	{"id": "relic_orbe_do_trovao_divino_06", "name": "Orbe do Trovão Divino", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"node_speed_bonus": 8.0}, "icon": "relics/relic_06.png"},
	{"id": "relic_relicario_da_chama_negra_07", "name": "Relicário da Chama Negra", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"armor_pen_bonus": 0.05}, "icon": "relics/relic_07.png"},
	{"id": "relic_selo_do_deus_afogado_08", "name": "Selo do Deus Afogado", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"elemental_damage_bonus": 0.1}, "icon": "relics/relic_08.png"},
	{"id": "relic_cajado_do_juizo_final_09", "name": "Cajado do Juízo Final", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"hull_bonus": 150.0}, "icon": "relics/relic_09.png"},
	{"id": "relic_veu_de_ebenruth_10", "name": "Véu de Ebenruth", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"cargo_bonus": 20.0}, "icon": "relics/relic_10.png"},
	{"id": "relic_garra_das_mares_sombrias_11", "name": "Garra das Marés Sombrias", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"speed_bonus": 14.0}, "icon": "relics/relic_11.png"},
	{"id": "relic_presa_do_tita_submerso_12", "name": "Presa do Titã Submerso", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"damage_mult_bonus": 0.15}, "icon": "relics/relic_12.png"},
	{"id": "relic_chama_da_nevoa_espectral_13", "name": "Chama da Névoa Espectral", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"leadership_bonus": 12.0}, "icon": "relics/relic_13.png"},
	{"id": "relic_cristal_do_mar_sem_fundo_14", "name": "Cristal do Mar Sem Fundo", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"boarding_crit_bonus": 0.08}, "icon": "relics/relic_14.png"},
	{"id": "relic_chifre_da_tempestade_esquecida_15", "name": "Chifre da Tempestade Esquecida", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"node_speed_bonus": 12.0}, "icon": "relics/relic_15.png"},
	{"id": "relic_cetro_da_furia_oceanica_16", "name": "Cetro da Fúria Oceânica", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"armor_pen_bonus": 0.08}, "icon": "relics/relic_16.png"},
	{"id": "relic_medalhao_da_luz_perdida_17", "name": "Medalhão da Luz Perdida", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"elemental_damage_bonus": 0.15}, "icon": "relics/relic_17.png"},
	{"id": "relic_pingente_de_ouroboros_18", "name": "Pingente de Ouroboros", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 200.0}, "icon": "relics/relic_18.png"},
	{"id": "relic_ancora_do_dragao_das_profundezas_19", "name": "Âncora do Dragão das Profundezas", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"cargo_bonus": 25.0}, "icon": "relics/relic_19.png"},
	{"id": "relic_totem_do_eclipse_eterno_20", "name": "Totem do Eclipse Eterno", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"speed_bonus": 18.0}, "icon": "relics/relic_20.png"},
	{"id": "relic_pedra_do_juizo_da_serpente_infinita_21", "name": "Pedra do Juízo da Serpente Infinita", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"damage_mult_bonus": 0.2}, "icon": "relics/relic_21.png"},
	{"id": "relic_espinha_do_abismo_eterno_22", "name": "Espinha do Abismo Eterno", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"leadership_bonus": 16.0}, "icon": "relics/relic_22.png"},
	{"id": "relic_elo_do_vazio_estelar_23", "name": "Elo do Vazio Estelar", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"boarding_crit_bonus": 0.1}, "icon": "relics/relic_23.png"},
	{"id": "relic_coracao_da_luz_perdida_24", "name": "Coração da Luz Perdida", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"node_speed_bonus": 16.0}, "icon": "relics/relic_24.png"},
	{"id": "relic_olho_de_ouroboros_25", "name": "Olho de Ouroboros", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"armor_pen_bonus": 0.1}, "icon": "relics/relic_25.png"},
	{"id": "relic_calice_do_dragao_das_profundezas_26", "name": "Cálice do Dragão das Profundezas", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"elemental_damage_bonus": 0.2}, "icon": "relics/relic_26.png"},
	{"id": "relic_coroa_do_eclipse_eterno_27", "name": "Coroa do Eclipse Eterno", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"hull_bonus": 250.0}, "icon": "relics/relic_27.png"},
	{"id": "relic_lagrima_da_serpente_infinita_28", "name": "Lágrima da Serpente Infinita", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"cargo_bonus": 35.0}, "icon": "relics/relic_28.png"},
	{"id": "relic_fragmento_do_abismo_eterno_29", "name": "Fragmento do Abismo Eterno", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"speed_bonus": 25.0}, "icon": "relics/relic_29.png"},
	{"id": "relic_orbe_do_vazio_estelar_30", "name": "Orbe do Vazio Estelar", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"damage_mult_bonus": 0.3}, "icon": "relics/relic_30.png"},
	{"id": "relic_relicario_da_maldicao_ancestral_31", "name": "Relicário da Maldição Ancestral", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"leadership_bonus": 20.0}, "icon": "relics/relic_31.png"},
	{"id": "relic_selo_do_leviata_ancestral_32", "name": "Selo do Leviatã Ancestral", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"boarding_crit_bonus": 0.15}, "icon": "relics/relic_32.png"},
	{"id": "relic_cajado_da_rainha_do_gelo_33", "name": "Cajado da Rainha do Gelo", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"node_speed_bonus": 20.0}, "icon": "relics/relic_33.png"},
	{"id": "relic_veu_do_sangue_antigo_34", "name": "Véu do Sangue Antigo", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"armor_pen_bonus": 0.15}, "icon": "relics/relic_34.png"},
	{"id": "relic_garra_do_leviata_negro_35", "name": "Garra do Leviatã Negro", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"elemental_damage_bonus": 0.25}, "icon": "relics/relic_35.png"},
	{"id": "relic_presa_do_kraken_primordial_36", "name": "Presa do Kraken Primordial", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"hull_bonus": 100.0}, "icon": "relics/relic_36.png"},
	{"id": "relic_chama_do_caos_runico_37", "name": "Chama do Caos Rúnico", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"cargo_bonus": 15.0}, "icon": "relics/relic_37.png"},
	{"id": "relic_cristal_do_trovao_divino_38", "name": "Cristal do Trovão Divino", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"speed_bonus": 10.0}, "icon": "relics/relic_38.png"},
	{"id": "relic_chifre_da_chama_negra_39", "name": "Chifre da Chama Negra", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"damage_mult_bonus": 0.1}, "icon": "relics/relic_39.png"},
	{"id": "relic_cetro_do_deus_afogado_40", "name": "Cetro do Deus Afogado", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"leadership_bonus": 8.0}, "icon": "relics/relic_40.png"},
	{"id": "relic_medalhao_do_juizo_final_41", "name": "Medalhão do Juízo Final", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"boarding_crit_bonus": 0.05}, "icon": "relics/relic_41.png"},
	{"id": "relic_pingente_de_ebenruth_42", "name": "Pingente de Ebenruth", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"node_speed_bonus": 8.0}, "icon": "relics/relic_42.png"},
	{"id": "relic_ancora_das_mares_sombrias_43", "name": "Âncora das Marés Sombrias", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"armor_pen_bonus": 0.05}, "icon": "relics/relic_43.png"},
	{"id": "relic_totem_do_tita_submerso_44", "name": "Totem do Titã Submerso", "materials": {"Fragmentos Místicos": 5, "Dente de Leviatã": 3}, "stats": {"elemental_damage_bonus": 0.1}, "icon": "relics/relic_44.png"},
	{"id": "relic_pedra_do_juizo_da_nevoa_espectral_45", "name": "Pedra do Juízo da Névoa Espectral", "materials": {"Fragmentos Místicos": 4, "Pérola Abissal": 2}, "stats": {"hull_bonus": 150.0}, "icon": "relics/relic_45.png"},
	{"id": "relic_espinha_do_mar_sem_fundo_46", "name": "Espinha do Mar Sem Fundo", "materials": {"Fragmentos Místicos": 3, "Osso de Titã": 2}, "stats": {"cargo_bonus": 20.0}, "icon": "relics/relic_46.png"},
	{"id": "relic_elo_da_tempestade_esquecida_47", "name": "Elo da Tempestade Esquecida", "materials": {"Fragmentos Místicos": 5, "Coral Amaldiçoado": 3}, "stats": {"speed_bonus": 14.0}, "icon": "relics/relic_47.png"},
	{"id": "relic_coracao_do_juizo_final_48", "name": "Coração do Juízo Final", "materials": {"Fragmentos Místicos": 4, "Essência de Ebenruth": 2}, "stats": {"damage_mult_bonus": 0.15}, "icon": "relics/relic_48.png"},
	{"id": "relic_olho_de_ebenruth_49", "name": "Olho de Ebenruth", "materials": {"Fragmentos Místicos": 3, "Dente de Leviatã": 2}, "stats": {"leadership_bonus": 12.0}, "icon": "relics/relic_49.png"},
]

## Leme: nem a seção 1 (catálogo) nem a seção 2 (receitas) do pedido
## original de crafting descrevem esse slot, embora o pedido daquela rodada
## pedisse pra equipá-lo -- inferido pra fechar os 5 slots do Galeão, tema
## de madeira nobre + latão (mesmo de Proa).
const _HELM: Array[Dictionary] = [
	{"id": "leme_carvalho", "name": "Leme de Carvalho Reforçado", "materials": {"Madeira Nobre": 3, "Peças de Latão": 2}, "stats": {}},
	{"id": "leme_latao", "name": "Leme Ornamentado de Latão", "materials": {"Madeira Nobre": 5, "Peças de Latão": 4, "Vento Rúnico": 1}, "stats": {"speed_bonus": 5.0}},
]
const _HELM_ICON: String = "leme.png"

## Grimórios/Tomes: 3 especiais não-tiered (igual às Relíquias) -- extraídos
## da mesma prancha dos acessórios do Capitão.
const _GRIMOIRES: Array[Dictionary] = [
	{"id": "grimorio_caveira", "name": "Grimório da Caveira Dourada", "materials": {"Couro": 2, "Tinta Rúnica": 2}, "stats": {"elemental_damage_bonus": 0.1}, "icon": "grimorio_caveira.png"},
	{"id": "grimorio_acorrentado", "name": "Tomo Acorrentado das Marés", "materials": {"Couro Reforçado": 2, "Tinta Rúnica": 3}, "stats": {"elemental_damage_bonus": 0.16}, "icon": "grimorio_acorrentado.png"},
	{"id": "grimorio_atlas", "name": "Atlas Perdido do Corsário", "materials": {"Couro Reforçado": 3, "Tinta Rúnica": 4}, "stats": {"node_speed_bonus": 10.0}, "icon": "grimorio_atlas.png"},
]


func _ready() -> void:
	_register_tiered_catalog()
	_register_flat_catalog(_build_ammo_catalog(), "municao", "forja", "")
	_register_flat_catalog(_HARPOONS, "arpao", "forja", "")
	_register_flat_catalog(_RELICS, "relíquia_ebenruth", "boticario", "")
	_register_flat_catalog(_HELM, "leme", "estaleiro", _HELM_ICON)
	_register_flat_catalog(_GRIMOIRES, "grimorio", "feira", "")


func _station_for(category: String) -> String:
	if category == "armamento":
		return "forja"
	if ["brincos", "colar", "anel", "cinto", "trajes"].has(category):
		return "feira"
	return "estaleiro"


func _register_tiered_catalog() -> void:
	for category in _TIER_MATERIALS:
		var station: String = _station_for(category)
		var display: String = _TIER_DISPLAY_NAMES[category]
		for tier_index in 4:
			var tier_num: int = tier_index + 1
			var item_id: String = "%s_t%d" % [category, tier_num]
			var item_name: String = "%s Tier %s" % [display, TIER_NAMES[tier_index]]
			var icon_file: String = _TIER_ICONS[category][tier_index]
			ITEMS[item_id] = {
				"id": item_id,
				"name": item_name,
				"category": category,
				"tier": tier_num,
				"icon": load(ICON_DIR + icon_file) if icon_file != "" else null,
				"stats": _TIER_STATS[category][tier_index],
			}
			RECIPES[item_id] = {
				"output": item_id,
				"station": station,
				"materials": _TIER_MATERIALS[category][tier_index],
			}


func _register_flat_catalog(entries: Array[Dictionary], category: String, station: String, default_icon_file: String) -> void:
	for entry in entries:
		var icon_file: String = entry.get("icon", default_icon_file)
		ITEMS[entry["id"]] = {
			"id": entry["id"],
			"name": entry["name"],
			"category": category,
			"tier": 0,
			"icon": load(ICON_DIR + icon_file) if icon_file != "" else null,
			"stats": entry.get("stats", {}),
		}
		RECIPES[entry["id"]] = {
			"output": entry["id"],
			"station": station,
			"materials": entry["materials"],
		}


func get_item(item_id: String) -> Dictionary:
	return ITEMS.get(item_id, {})


func get_recipe(item_id: String) -> Dictionary:
	return RECIPES.get(item_id, {})


## Receitas de uma categoria numa estação -- as abas do `CraftingModal` usam
## isso direto, uma chamada por aba.
func get_recipes_for(station: String, category: String) -> Array[String]:
	var result: Array[String] = []
	for item_id in RECIPES:
		var recipe: Dictionary = RECIPES[item_id]
		if recipe["station"] != station:
			continue
		if ITEMS[item_id]["category"] != category:
			continue
		result.append(item_id)
	result.sort()
	return result
