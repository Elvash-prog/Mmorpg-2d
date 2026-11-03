extends RefCounted
const Inventory = preload("res://scripts/simulation/inventory_system.gd")
const Boss = preload("res://scripts/simulation/boss_system.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")

static func initialize_player(p: Dictionary) -> void:
	Inventory.initialize_player(p)


static func recalculate(p: Dictionary) -> void:
	Inventory.recalculate(p)


static func equip(world: Node, id: int, slot: String, item_id: String) -> bool:
	return Inventory.equip(world,id,slot,item_id)


static func give_item(world: Node, p: Dictionary, item_id: String) -> void:
	Inventory.give_item(world,p,item_id)


static func on_kill(world: Node, p: Dictionary, monster: Dictionary) -> void:
	Inventory.on_kill(world,p,monster)


static func add_enemies(world: Node) -> void:
	for marker in Realm.Maps.objects("enemy"):
		if marker.area>0:
			world.monsters.append(world._new_monster(marker.pos,marker.kind))

static func interact(world: Node, id: int) -> bool:
	var p: Dictionary = world.players[id]
	for portal in Realm.PORTALS:
		if p.pos.distance_to(portal.pos) < 58:
			p.pos = portal.to
			p.velocity = Vector2.ZERO
			p.target = -1
			p.cast = {}
			p.swing = 0.0
			p.request = -1
			p.combat = 0.0
			world.projectiles = world.projectiles.filter(func(shot):return shot.owner != id)
			world.zones = world.zones.filter(func(zone):return zone.owner != id)
			world._message(p, "Você chegou a %s. Explore e encontre o acampamento." % portal.name)
			return true
	for i in range(Realm.CHESTS.size()):
		var chest: Dictionary = Realm.CHESTS[i]
		if p.pos.distance_to(chest.pos) < 48:
			if not p.opened.has(i):
				p.opened.append(i)
				give_item(world, p, chest.item)
				p.gold += 15
				world._fx("heal", chest.pos, chest.pos, 35, Color("f6d88a"))
			else:
				world._message(p, "Você já abriu esse baú. Os tesouros são individuais.")
			return true
	for beacon in Realm.BEACONS:
		if p.pos.distance_to(beacon.pos) < 60:
			p.progress[beacon.key] = 1
			p.dialogue_chapter = 1 if beacon.area == 1 else 2
			p.dialogue_seq += 1
			world._message(p, "Memória descoberta. Consulte o diário e entregue a missão no acampamento.")
			world._fx("cast", beacon.pos, beacon.pos, 70, Color("b9e7ed"))
			return true
	for zone in world.zones:
		if zone.kind == "pylon" and zone.life > 0 and p.pos.distance_to(zone.pos) < 55:
			zone.life = 0
			world._message(p, "Pilar desativado! Quebre os três para remover o escudo do Arconte.")
			world._fx("frost", zone.pos, zone.pos, 48, Color("b8cfff"))
			return true
	if p.pos.distance_to(world.SPAWN) < 65 and p.progress.boss_forest > 0 and p.progress.boss_ruins > 0:
		if p.progress.restore == 0:
			p.progress.restore = 1
			p.dialogue_chapter = 4
			p.dialogue_seq += 1
			give_item(world, p, "dawn_sigil")
			world._message(p, "A fonte voltou a brilhar. Entregue a última missão a Lia.")
			world._fx("heal", world.SPAWN, world.SPAWN, 160, Color("ffe6ac"))
			return true
	return false

static func open_dialogue(p: Dictionary) -> void:
	p.dialogue_chapter = Realm.chapter(p)
	p.dialogue_seq += 1

static func tick_boss(world: Node, boss: Dictionary, delta: float) -> void:
	Boss.tick_boss(world,boss,delta)


static func _hazard(boss: Dictionary, kind: String, pos: Vector2, life: float, arm: float, damage: float, radius: float) -> Dictionary:
	return Boss._hazard(boss,kind,pos,life,arm,damage,radius)


static func tick_hazard(world: Node, zone: Dictionary, delta: float) -> void:
	Boss.tick_hazard(world,zone,delta)


static func boss_shield(world: Node, monster: Dictionary) -> bool:
	return Boss.boss_shield(world,monster)
