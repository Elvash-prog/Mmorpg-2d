extends RefCounted
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")

static func initialize_player(p: Dictionary) -> void:
	p.inventory = Realm.STARTERS.duplicate()
	p.equipped = {"weapon":Realm.STARTERS[p.class_id], "armor":"", "boots":"", "amulet":""}
	p.opened = []
	p.velocity = Vector2.ZERO
	p.dialogue_seq = 0
	p.dialogue_chapter = 0
	for key in ["forest_beacon", "ruins_beacon", "boss_forest", "boss_ruins", "restore"]:
		p.progress[key] = 0
	recalculate(p)

static func recalculate(p: Dictionary) -> void:
	var hp: float = Data.CLASS_HP[p.class_id]
	var mana: float = Data.CLASS_MANA[p.class_id]
	p.power = 0.0
	p.armor = 0.0
	p.speed = 165.0
	p.crit = 0.0
	for item_id in p.equipped.values():
		if not Realm.ITEMS.has(item_id):
			continue
		var item: Dictionary = Realm.ITEMS[item_id]
		if item["class"] >= 0 and item["class"] != p.class_id:
			continue
		hp += item.hp
		mana += item.mana
		p.power += item.power
		p.armor += item.armor
		p.speed += item.speed
		p.crit += item.crit
	p.max_hp = hp
	p.max_mana = mana
	p.hp = minf(p.hp, hp)
	p.mana = minf(p.mana, mana)

static func equip(world: Node, id: int, slot: String, item_id: String) -> bool:
	if not world.players.has(id) or not Realm.SLOTS.has(slot):
		return false
	var p: Dictionary = world.players[id]
	if p.hp <= 0 or p.combat > 0:
		world._message(p, "Troque equipamentos fora de combate.")
		return false
	if item_id != "":
		if not Realm.ITEMS.has(item_id) or not p.inventory.has(item_id):
			return false
		var item: Dictionary = Realm.ITEMS[item_id]
		if item.slot != slot or (item["class"] >= 0 and item["class"] != p.class_id):
			world._message(p, "Esse equipamento não serve à sua classe ou a esse espaço.")
			return false
	p.equipped[slot] = item_id
	recalculate(p)
	world._message(p, "Equipamento atualizado. Os atributos já estão em vigor.")
	return true

static func give_item(world: Node, p: Dictionary, item_id: String) -> void:
	if not p.inventory.has(item_id):
		p.inventory.append(item_id)
		world._message(p, "Novo equipamento: %s. Abra PERSONAGEM [C] para equipar." % Realm.ITEMS[item_id].name)

static func on_kill(world: Node, p: Dictionary, monster: Dictionary) -> void:
	var drops := ["linen_vest", "trail_boots", ["steel_sword", "crystal_staff", "longbow"][p.class_id], "verdant_heart", "dawn_crown"]
	give_item(world, p, drops[monster.kind])

static func add_enemies(world: Node) -> void:
	for entry in [[Vector2(1550,620),0], [Vector2(1740,520),1], [Vector2(2200,550),1], [Vector2(2350,880),0], [Vector2(2650,1060),1], [Vector2(2760,700),3], [Vector2(1650,1640),2], [Vector2(2080,1700),2], [Vector2(2400,2200),2], [Vector2(2910,2240),2], [Vector2(2760,1970),4]]:
		world.monsters.append(world._new_monster(entry[0], entry[1]))

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
	for key in ["cooldown", "hit", "slow", "root", "path_timer", "windup"]:
		boss[key] = maxf(0, boss[key] - delta)
	boss.moving = false
	var nearest := -1
	var distance := 390.0
	for id in world.players:
		var p: Dictionary = world.players[id]
		var d: float = p.pos.distance_to(boss.pos)
		if p.hp > 0 and Realm.area_at(p.pos) == Realm.area_at(boss.home) and d < distance:
			nearest = id
			distance = d
	if nearest < 0 or boss.pos.distance_to(boss.home) > 460:
		world._move_monster(boss, boss.home, delta, 85)
		if boss.pos.distance_to(boss.home) < 15:
			boss.hp = minf(boss.max_hp, boss.hp + delta * 80)
			if boss.hp >= boss.max_hp:
				boss.phase = 1
				boss.pattern = 0
				for zone in world.zones:
					if zone.get("source",-1) == boss.id:
						zone.life = 0
		return
	if boss.hp <= boss.max_hp * 0.5 and boss.phase == 1:
		boss.phase = 2
		if boss.kind == 3:
			var reusable: Array[int] = []
			for candidate in world.monsters:
				if candidate.get("summoner",-1) == boss.id:
					reusable.append(candidate.id)
			var wave := 0
			for offset in [Vector2(-90,80), Vector2(90,80)]:
				var minion: Dictionary = world._new_monster(boss.home + offset, 1)
				minion.summoned = true
				minion.summoner = boss.id
				if wave < reusable.size():
					minion.id = reusable[wave]
					world.monsters[minion.id] = minion
				else:
					world.monsters.append(minion)
				wave += 1
		else:
			for offset in [Vector2(-150,80), Vector2(150,80), Vector2(0,-165)]:
				world.zones.append(_hazard(boss, "pylon", boss.home + offset, 9999, 0, 0, 25))
		world._fx("storm", boss.pos, boss.pos, 150, Color("deb2fa"))
	if boss.windup > 0 or boss.root > 0:
		return
	var target: Vector2 = world.players[nearest].pos
	if boss.cooldown > 0:
		if distance > 155:
			world._move_monster(boss, target, delta, 65 if boss.kind == 3 else 50)
		return
	boss.windup = 0.9
	boss.cooldown = 3.0 if boss.phase == 1 else 2.1
	boss.attack_pos = target
	if boss.kind == 3:
		if boss.pattern % 2 == 0:
			var direction: Vector2 = boss.pos.direction_to(target)
			var zone := _hazard(boss, "thorns", boss.pos, 1.45, 0.95, 24, 25)
			zone.to = boss.pos + direction * 360
			world.zones.append(zone)
			if boss.phase == 2:
				var side: Vector2 = direction.orthogonal() * 70
				var extra: Dictionary = zone.duplicate()
				extra.pos += side
				extra.to += side
				world.zones.append(extra)
		else:
			world.zones.append(_hazard(boss, "spores", target, 6.0, 0.9, 8, 75))
	else:
		if boss.pattern % 2 == 0:
			var zone := _hazard(boss, "ring", boss.pos, 1.8, 1.25, 32, 215)
			zone.inner = 88.0
			world.zones.append(zone)
		else:
			for offset in [Vector2.ZERO, Vector2(100,-65), Vector2(-100,65)]:
				world.zones.append(_hazard(boss, "meteor", target + offset, 1.6, 1.0, 28, 48))
	boss.pattern += 1

static func _hazard(boss: Dictionary, kind: String, pos: Vector2, life: float, arm: float, damage: float, radius: float) -> Dictionary:
	return {"hostile":true, "kind":kind, "owner":-1, "source":boss.id, "pos":pos, "to":pos, "life":life, "arm":arm, "warning":arm, "tick":0.0, "damage":damage, "radius":radius, "inner":0.0, "pulses":5 if kind == "spores" else 1}

static func tick_hazard(world: Node, zone: Dictionary, delta: float) -> void:
	if zone.life <= 0 or zone.kind == "pylon":
		return
	zone.arm -= delta
	if zone.arm > 0 or zone.tick > 0 or zone.pulses <= 0:
		return
	for id in world.players:
		var p: Dictionary = world.players[id]
		if p.hp <= 0 or Realm.area_at(p.pos) != Realm.area_at(zone.pos):
			continue
		var d: float = p.pos.distance_to(zone.pos)
		var hit: bool = d < zone.radius
		if zone.kind == "ring":
			hit = d > zone.inner and d < zone.radius
		elif zone.kind == "thorns":
			hit = p.pos.distance_to(Geometry2D.get_closest_point_to_segment(p.pos, zone.pos, zone.to)) < zone.radius
		if hit and world.Map.line_clear(zone.pos, p.pos):
			world._hurt_player(id, zone.damage)
	world._fx("fire" if zone.kind == "meteor" else "root", zone.pos, zone.pos, zone.radius, Color("eeb889") if zone.kind == "meteor" else Color("b9a8ed"))
	zone.pulses -= 1
	zone.tick = 1.0

static func boss_shield(world: Node, monster: Dictionary) -> bool:
	if monster.kind != 4:
		return false
	for zone in world.zones:
		if zone.kind == "pylon" and zone.life > 0 and zone.get("source",-1) == monster.id:
			return true
	return false
