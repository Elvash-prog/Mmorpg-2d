extends RefCounted
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")

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
