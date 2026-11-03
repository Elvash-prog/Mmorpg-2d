extends RefCounted
## Stable resources back the original public facade used by the prototype.
const CATALOG = preload("res://content/game_catalog.tres")
const Maps = preload("res://scripts/maps/map_registry.gd")
static var AREAS: Array = Maps.area_definitions()
static var PORTALS: Array = Maps.objects("portal")
static var NPCS: Array = Maps.objects("npc")
static var BEACONS: Array = Maps.objects("beacon")
static var CHESTS: Array = Maps.objects("chest")
static var ITEMS: Dictionary = CATALOG.item_table()
const STARTERS := ["training_sword", "training_staff", "training_bow"]
const SLOTS := ["weapon", "armor", "boots", "amulet"]
const SLOT_NAMES := ["Arma", "Armadura", "Botas", "Amuleto"]
const RARITIES := ["Comum", "Incomum", "Raro", "Épico", "Relíquia"]
const RARITY_COLORS := [Color("ccd5cf"),Color("9bd59a"),Color("94bfe8"),Color("c1a1eb"),Color("f0ce80")]
const STORY := [
	{"title":"I · A fonte que se apaga", "speaker":"Lia, guardadora da fonte", "text":"Durante cem invernos, a Fonte da Aurora manteve o vale vivo. Agora sua luz enfraquece, e os animais carregam cristais que não deveriam existir.\n\nMeu irmão Cael partiu para o Bosque dos Ecos e não voltou. Levou um mapa com o símbolo dos antigos Guardiões. Não lhe peço uma guerra. Peço que descubra o que aconteceu.\n\nPrepare-se no vale e procure o baú dos viajantes. Visite o marco azul a sudeste: ele guarda a marca que Cael seguia. Depois, siga o caminho leste. Rovan ainda mantém um acampamento na floresta."},
	{"title":"II · O que as raízes lembram", "speaker":"Rovan, vigia dos caminhos", "text":"Cael encontrou uma pedra que cantava. Depois disso, as raízes começaram a crescer contra o vento. A Matriarca enlouqueceu defendendo a clareira.\n\nEla não era nossa inimiga. Alguma coisa a prende à dor de uma memória antiga. Toque o santuário das raízes e ouça por si. Quando estiver pronto, leve equipamento melhor e enfrente-a na clareira leste.\n\nDesvie das linhas de espinhos. Quando a terra escurecer, abandone as poças de esporos. Abaixo da metade da vida, ela chama os lobos."},
	{"title":"III · A primeira mentira", "speaker":"Memória de Íria", "text":"Fomos chamados Guardiões. Juramos alimentar a fonte com a luz da cidadela, mas o Arconte escolheu guardar a luz para si. O bosque recebeu o que sobrou: silêncio e cinzas.\n\nCael chegou até esta memória. Está vivo, além destas muralhas, procurando os exilados. Pediu que eu lhe entregasse uma mensagem: não salve apenas a fonte. Restaure o caminho entre os povos.\n\nO Arconte ainda protege um juramento vazio. Nas ondas circulares, corra para o centro ou para além do anel. Quando os três pilares se acenderem, aproxime-se deles e use F para quebrar o escudo."},
	{"title":"IV · Um juramento que pertence a todos", "speaker":"Lia, guardadora da fonte", "text":"Você trouxe de volta as duas ressonâncias. O bosque e a cidadela não eram inimigos: foram separados por uma escolha.\n\nCael não desapareceu. Continua a procurar aqueles que ficaram do outro lado. Agora há um caminho pelo qual ele poderá voltar.\n\nAproxime-se da fonte e use F para reunir as ressonâncias. A luz não será tão forte quanto nas histórias. Será suficiente para começarmos outra vez."},
	{"title":"Epílogo · A próxima manhã", "speaker":"A crônica da Aurora", "text":"A fonte voltou a respirar. Pela primeira vez em muitos invernos, Rovan ouviu pássaros na estrada da cidadela. Lia manteve uma lanterna acesa na janela para Cael.\n\nO vale ainda tem feridas, mas agora seus caminhos se encontram. Você não venceu a noite para sempre. Deu às pessoas uma próxima manhã.\n\nFim deste primeiro arco. A jornada dos exilados continua além das muralhas."}
]

static func area_at(pos: Vector2) -> int:
	for i in range(AREAS.size()):
		if AREAS[i].rect.has_point(pos):
			return i
	return -1

static func chapter(p: Dictionary) -> int:
	if p.get("progress", {}).get("restore",0) > 0:
		return 4
	if p.get("progress", {}).get("boss_ruins",0) > 0:
		return 3
	return 2 if area_at(p.pos) == 2 else (1 if area_at(p.pos) == 1 else 0)

static func refresh_maps() -> void:
	AREAS = Maps.area_definitions()
	PORTALS = Maps.objects("portal")
	NPCS = Maps.objects("npc")
	BEACONS = Maps.objects("beacon")
	CHESTS = Maps.objects("chest")
