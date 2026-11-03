extends RefCounted
## Content shared by the authoritative simulation and UI.
const CLASS_NAMES := ["Guerreiro", "Maga", "Patrulheira"]
const CLASS_COLORS := [Color("eac779"), Color("bd9aef"), Color("8ed4a0")]
const SKILL_SHORT_NAMES := [["Corte", "Giro", "Investida", "Muralha", "Fôlego"], ["Faísca", "Fogo", "Gelo", "Barreira", "Tempestade"], ["Flecha", "Duplo", "Chuva", "Armadilha", "Esquiva"]]
const CLASS_HP := [140.0, 90.0, 110.0]
const CLASS_MANA := [80.0, 120.0, 90.0]
const SKILLS := [
	[
		{"name":"Corte", "kind":"melee", "power":24, "range":82.0, "cost":0, "cd":0.65, "desc":"Golpe no alvo próximo."},
		{"name":"Redemoinho", "kind":"whirl", "power":30, "range":105.0, "cost":18, "cd":4.0, "desc":"Atinge todos os inimigos ao redor."},
		{"name":"Investida", "kind":"charge", "power":32, "range":195.0, "cost":20, "cd":6.0, "desc":"Avança até o alvo; obstáculos bloqueiam o avanço."},
		{"name":"Muralha", "kind":"shield", "power":50, "range":0.0, "cost":20, "cd":9.0, "desc":"Absorve 50 de dano por até 5 s."},
		{"name":"Fôlego", "kind":"heal", "power":48, "range":0.0, "cost":25, "cd":12.0, "desc":"Recupera 48 de vida."}
	],
	[
		{"name":"Faísca", "kind":"bolt", "power":20, "range":310.0, "cost":0, "cd":0.8, "desc":"Projétil arcano; pode ser bloqueado pelo cenário."},
		{"name":"Bola de fogo", "kind":"fire", "power":38, "range":310.0, "cost":22, "cd":4.0, "desc":"Explode no impacto em uma área de 80 px."},
		{"name":"Nova de gelo", "kind":"frost", "power":22, "range":140.0, "cost":24, "cd":6.0, "desc":"Dano ao redor e lentidão de 3 s."},
		{"name":"Barreira", "kind":"shield", "power":42, "range":0.0, "cost":20, "cd":10.0, "desc":"Escudo arcano de 42 pontos por até 5 s."},
		{"name":"Tempestade", "kind":"storm", "power":16, "range":300.0, "cost":36, "cd":11.0, "desc":"Quatro pulsos de dano no local do alvo."}
	],
	[
		{"name":"Flecha", "kind":"arrow", "power":22, "range":350.0, "cost":0, "cd":0.75, "desc":"Flecha rápida contra um alvo."},
		{"name":"Tiro duplo", "kind":"double", "power":17, "range":350.0, "cost":15, "cd":3.0, "desc":"Dispara duas flechas com pequeno intervalo."},
		{"name":"Chuva", "kind":"rain", "power":18, "range":320.0, "cost":28, "cd":8.0, "desc":"Três ondas de flechas em uma área."},
		{"name":"Armadilha", "kind":"trap", "power":26, "range":220.0, "cost":18, "cd":7.0, "desc":"Arma uma zona por 8 s; prende um inimigo por 2 s."},
		{"name":"Passo evasivo", "kind":"evade", "power":0, "range":0.0, "cost":12, "cd":6.0, "desc":"Recua sem atravessar obstáculos e esquiva por 1,2 s."}
	]
]
const ENEMIES := [
	{"name":"Limo verde", "hp":65.0, "speed":58.0, "damage":9.0, "reach":35.0, "windup":0.4, "radius":36.0, "xp":25, "key":"slime"},
	{"name":"Lobo cinzento", "hp":95.0, "speed":90.0, "damage":14.0, "reach":43.0, "windup":0.5, "radius":44.0, "xp":40, "key":"wolf"},
	{"name":"Sentinela de pedra", "hp":210.0, "speed":40.0, "damage":26.0, "reach":65.0, "windup":0.9, "radius":68.0, "xp":85, "key":"golem"},
	{"name":"Matriarca dos Espinhos", "hp":950.0, "speed":65.0, "damage":20.0, "reach":110.0, "windup":1.1, "radius":90.0, "xp":240, "key":"boss_forest"},
	{"name":"Arconte do Ocaso", "hp":1350.0, "speed":50.0, "damage":28.0, "reach":120.0, "windup":1.3, "radius":210.0, "xp":350, "key":"boss_ruins"}
]
const QUESTS := [
	{"title":"Primeiros passos", "key":"slime", "goal":3, "xp":70, "gold":30, "text":"Derrote 3 limos verdes."},
	{"title":"Uivos no vale", "key":"wolf", "goal":2, "xp":100, "gold":50, "text":"Derrote 2 lobos cinzentos."},
	{"title":"Pedra desperta", "key":"golem", "goal":1, "xp":150, "gold":75, "text":"Derrote uma sentinela de pedra."},
	{"title":"Ervas do curandeiro", "key":"herbs", "goal":3, "xp":75, "gold":40, "text":"Colete as 3 ervas luminosas usando F."},
	{"title":"Explorador do vale", "key":"visit", "goal":1, "xp":50, "gold":25, "text":"Visite o marco azul a sudeste."},
	{"title":"A memória das raízes", "key":"forest_beacon", "goal":1, "xp":100, "gold":50, "text":"Toque o santuário no Bosque dos Ecos. Descubra o que feriu a Matriarca.", "requires":4},
	{"title":"Um coração sob os espinhos", "key":"boss_forest", "goal":1, "xp":200, "gold":100, "text":"Liberte a Matriarca na clareira. Evite espinhos e esporos.", "requires":5},
	{"title":"O primeiro juramento", "key":"ruins_beacon", "goal":1, "xp":140, "gold":70, "text":"Ouça a memória de Íria na Cidadela do Ocaso.", "requires":6},
	{"title":"A luz aprisionada", "key":"boss_ruins", "goal":1, "xp":300, "gold":160, "text":"Vença o Arconte. Quebre os pilares para remover seu escudo.", "requires":7},
	{"title":"A próxima manhã", "key":"restore", "goal":1, "xp":300, "gold":200, "text":"Volte à fonte e reúna as duas ressonâncias com F. Entregue a missão a Lia.", "requires":8}
]
const NPC_POS := Vector2(365, 385)
const LANDMARK := Vector2(880, 490)
const HERBS := [Vector2(600, 510), Vector2(740, 155), Vector2(940, 360)]
