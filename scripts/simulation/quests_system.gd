extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
var world: Node

func _init(context: Node) -> void:
	world = context

func interact(id: int) -> void:
	if not world.players.has(id) or world.players[id].hp <= 0:
		return
	var p: Dictionary = world.players[id]
	if Expansion.interact(world, id):
		return
	for i in range(Data.HERBS.size()):
		if not p.picked.has(i) and p.pos.distance_to(Data.HERBS[i]) < 43 and Map.line_clear(p.pos, Data.HERBS[i]):
			p.picked.append(i)
			p.progress.herbs += 1
			world.effects_system.message(p, "Erva coletada: %s/3. Entregue a Lia quando concluir." % p.progress.herbs)
			world.effects_system.fx("heal", Data.HERBS[i], Data.HERBS[i], 25, Color("9fe8b0"))
			return
	var near_npc := false
	for npc in Realm.NPCS:
		if p.pos.distance_to(npc.pos) < 75:
			near_npc = true
	if not near_npc:
		world.effects_system.message(p, "Aproxime-se de Lia ou de uma erva luminosa para interagir.")
		return
	var rewards := 0
	for i in range(Data.QUESTS.size()):
		var quest: Dictionary = Data.QUESTS[i]
		if not p.claimed.has(i) and p.progress[quest.key] >= quest.goal and (not quest.has("requires") or p.claimed.has(quest.requires)):
			p.claimed.append(i)
			p.xp += quest.xp
			p.gold += quest.gold
			rewards += 1
	Expansion.open_dialogue(p)
	world.effects_system.message(p, "%s missão(ões) entregues! Ouro e XP recebidos." % rewards if rewards > 0 else "Consulte o diário (J), cumpra os objetivos e volte ao acampamento para receber ouro e XP.")
