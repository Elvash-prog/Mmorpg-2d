extends RefCounted
## World, narrative and item definitions. Coordinates are global server coordinates.
const AREAS := [
	{"name":"Vale da Aurora", "subtitle":"Um último abrigo sob a luz da fonte", "rect":Rect2(0,0,1152,636), "walk":Rect2(16,112,1120,490), "map":"res://assets/village.png", "color":Color("e8cf94")},
	{"name":"Bosque dos Ecos", "subtitle":"As raízes se lembram do que os homens esqueceram", "rect":Rect2(1152,0,2304,1272), "walk":Rect2(1184,64,2240,1152), "map":"res://assets/forest.png", "color":Color("98d8ae")},
	{"name":"Cidadela do Ocaso", "subtitle":"Onde o primeiro juramento foi quebrado", "rect":Rect2(1152,1272,2304,1272), "walk":Rect2(1184,1336,2240,1152), "map":"res://assets/ruins.png", "color":Color("b6b5ee")}
]
const PORTALS := [
	{"pos":Vector2(1000,315), "to":Vector2(1300,360), "name":"Bosque dos Ecos", "area":0},
	{"pos":Vector2(1250,320), "to":Vector2(960,315), "name":"Vale da Aurora", "area":1},
	{"pos":Vector2(3290,1120), "to":Vector2(1300,1450), "name":"Cidadela do Ocaso", "area":1},
	{"pos":Vector2(1250,1410), "to":Vector2(3230,1090), "name":"Bosque dos Ecos", "area":2}
]
const NPCS := [
	{"pos":Vector2(365,385), "name":"Lia", "role":"Guardadora da fonte", "area":0},
	{"pos":Vector2(1440,400), "name":"Rovan", "role":"Vigia dos caminhos", "area":1},
	{"pos":Vector2(1450,1510), "name":"Memória de Íria", "role":"Eco do primeiro juramento", "area":2}
]
const BEACONS := [
	{"pos":Vector2(2200,940), "key":"forest_beacon", "name":"Memória das raízes", "area":1},
	{"pos":Vector2(2050,1990), "key":"ruins_beacon", "name":"Memória da cidadela", "area":2}
]
const CHESTS := [
	{"pos":Vector2(590,325), "item":"travel_coat", "area":0},
	{"pos":Vector2(1680,780), "item":"trail_boots", "area":1},
	{"pos":Vector2(3030,1000), "item":"amber_charm", "area":1},
	{"pos":Vector2(1870,1760), "item":"runic_coat", "area":2}
]
const ITEMS := {
	"training_sword":{"name":"Espada de aprendiz", "slot":"weapon", "class":0, "rarity":0, "power":0, "armor":0, "hp":0, "mana":0, "speed":0, "crit":0.0, "lore":"Toda jornada começa com uma lâmina simples."},
	"training_staff":{"name":"Cajado de aprendiz", "slot":"weapon", "class":1, "rarity":0, "power":0, "armor":0, "hp":0, "mana":0, "speed":0, "crit":0.0, "lore":"Uma pedra azul, uma promessa de luz."},
	"training_bow":{"name":"Arco de aprendiz", "slot":"weapon", "class":2, "rarity":0, "power":0, "armor":0, "hp":0, "mana":0, "speed":0, "crit":0.0, "lore":"A corda ainda guarda o cheiro da floresta."},
	"travel_coat":{"name":"Casaco do viajante", "slot":"armor", "class":-1, "rarity":0, "power":0, "armor":2, "hp":12, "mana":0, "speed":0, "crit":0.0, "lore":"Deixado por Lia para quem se atreve a partir."},
	"linen_vest":{"name":"Colete de fibras vivas", "slot":"armor", "class":-1, "rarity":1, "power":0, "armor":3, "hp":18, "mana":0, "speed":0, "crit":0.0, "lore":"Fibras recuperadas entre os cristais de um limo."},
	"trail_boots":{"name":"Botas do batedor", "slot":"boots", "class":-1, "rarity":1, "power":0, "armor":1, "hp":0, "mana":0, "speed":14, "crit":0.0, "lore":"A trilha é mais curta para pés que a conhecem."},
	"steel_sword":{"name":"Lâmina do juramento", "slot":"weapon", "class":0, "rarity":2, "power":7, "armor":1, "hp":0, "mana":0, "speed":0, "crit":0.05, "lore":"Forjada antes de o juramento ser esquecido."},
	"crystal_staff":{"name":"Cajado da ressonância", "slot":"weapon", "class":1, "rarity":2, "power":7, "armor":0, "hp":0, "mana":16, "speed":0, "crit":0.05, "lore":"O cristal responde à mesma nota da fonte."},
	"longbow":{"name":"Arco da vigília", "slot":"weapon", "class":2, "rarity":2, "power":7, "armor":0, "hp":0, "mana":0, "speed":4, "crit":0.08, "lore":"Seu antigo dono jamais abandonou a muralha."},
	"amber_charm":{"name":"Âmbar dos ecos", "slot":"amulet", "class":-1, "rarity":2, "power":4, "armor":0, "hp":10, "mana":18, "speed":0, "crit":0.0, "lore":"Dentro dele, uma folha cai para sempre."},
	"runic_coat":{"name":"Manto das ruínas", "slot":"armor", "class":-1, "rarity":2, "power":2, "armor":7, "hp":30, "mana":10, "speed":0, "crit":0.0, "lore":"As runas resistiram ao tempo. O tecido, também."},
	"verdant_heart":{"name":"Coração do bosque", "slot":"amulet", "class":-1, "rarity":3, "power":6, "armor":2, "hp":35, "mana":20, "speed":0, "crit":0.03, "lore":"A Matriarca não era a origem da corrupção. Era sua primeira vítima."},
	"dawn_crown":{"name":"Armadura da aurora", "slot":"armor", "class":-1, "rarity":3, "power":4, "armor":12, "hp":60, "mana":12, "speed":0, "crit":0.0, "lore":"O Arconte guardou a armadura. Você guardará o juramento."},
	"dawn_sigil":{"name":"Selo da última aurora", "slot":"amulet", "class":-1, "rarity":4, "power":10, "armor":3, "hp":30, "mana":30, "speed":5, "crit":0.06, "lore":"Não promete que a noite acabará. Promete que alguém continuará a acender a luz."}
}
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
