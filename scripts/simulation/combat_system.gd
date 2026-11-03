extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
var world: Node

func _init(context: Node) -> void:
	world = context

func queue_skill(id: int, slot: int, target: int) -> void:
	if world.players.has(id) and slot >= 0 and slot < 5 and target >= -1 and target < world.monsters.size():
		world.players[id].request = slot
		world.players[id].request_target = target

func select_target(p: Dictionary, reach: float) -> int:
	var selected: int = p.target
	if selected >= 0 and selected < world.monsters.size() and world.monsters[selected].hp > 0:
		return selected
	var nearest := reach + 1
	var target := -1
	for i in range(world.monsters.size()):
		var d: float = p.pos.distance_to(world.monsters[i].pos)
		if world.monsters[i].hp > 0 and d < nearest and Map.line_clear(p.pos, world.monsters[i].pos):
			nearest = d
			target = i
	return target

func begin_skill(id: int, slot: int) -> bool:
	var p: Dictionary = world.players[id]
	if slot < 0 or slot >= 5 or p.hp <= 0 or not p.cast.is_empty() or p.cds[slot] > 0:
		return false
	var skill: Dictionary = Data.SKILLS[p.class_id][slot]
	if p.mana < skill.cost:
		world.effects_system.message(p, "Energia insuficiente para %s." % skill.name)
		return false
	var target := -1
	if skill.kind in ["melee", "charge", "bolt", "fire", "arrow", "double", "storm", "rain", "trap"]:
		target = select_target(p, skill.range)
		if target < 0:
			world.effects_system.message(p, "Selecione um inimigo ao alcance (clique ou TAB).")
			return false
		if p.pos.distance_to(world.monsters[target].pos) > skill.range:
			world.effects_system.message(p, "Alvo fora do alcance de %s." % skill.name)
			return false
		if not Map.line_clear(p.pos, world.monsters[target].pos):
			world.effects_system.message(p, "O cenário bloqueia a linha de visão.")
			return false
		p.facing = p.pos.direction_to(world.monsters[target].pos)
	p.target = target
	p.mana -= skill.cost
	p.cds[slot] = skill.cd
	p.swing = 0.48
	p.last_skill = slot
	p.cast = {"slot":slot, "target":target, "time":0.15}
	return true

func resolve_skill(id: int, cast: Dictionary) -> void:
	var p: Dictionary = world.players[id]
	var skill: Dictionary = Data.SKILLS[p.class_id][cast.slot]
	var target: int = cast.target
	var center: Vector2 = world.monsters[target].pos if target >= 0 and target < world.monsters.size() else p.pos
	var color: Color = Data.CLASS_COLORS[p.class_id]
	if skill.kind == "shield":
		p.shield = float(skill.power)
		p.shield_time = 5.0
		world.effects_system.fx("shield", p.pos, p.pos, 50, color)
	elif skill.kind == "heal":
		var amount: float = minf(skill.power, p.max_hp - p.hp)
		p.hp += amount
		world.effects_system.fx("heal", p.pos, p.pos, 55, Color("86efad"))
		world.effects_system.number(p.pos, "+%s" % int(amount), Color("9af1b2"))
	elif skill.kind == "evade":
		p.pos = Map.move_actor(p.pos, -p.facing * 155)
		p.evade = 1.2
		world.effects_system.fx("evade", p.pos, p.pos, 45, color)
	elif skill.kind == "whirl" or skill.kind == "frost":
		area_damage(id, p.pos, skill.range, skill.power, "slow" if skill.kind == "frost" else "")
		world.effects_system.fx(skill.kind, p.pos, p.pos, skill.range, Color("9ee9ff") if skill.kind == "frost" else color)
	elif skill.kind in ["storm", "rain", "trap"]:
		if target >= 0 and Map.line_clear(p.pos, center) and p.pos.distance_to(center) <= skill.range + 12:
			world.zones.append({"kind":skill.kind, "pos":center, "owner":id, "life":8.0 if skill.kind == "trap" else 3.4, "tick":0.0, "pulses":1 if skill.kind == "trap" else (4 if skill.kind == "storm" else 3), "radius":42.0 if skill.kind == "trap" else 95.0, "power":skill.power})
	elif skill.kind in ["bolt", "fire", "arrow", "double"]:
		if target >= 0 and world.monsters[target].hp > 0:
			world.projectile.spawn_projectile(id, center, skill)
			if skill.kind == "double":
				world.projectile.spawn_projectile(id, center, skill, 0.16)
	elif target >= 0 and world.monsters[target].hp > 0:
		if skill.kind == "charge":
			p.pos = Map.move_actor(p.pos, p.pos.direction_to(center) * maxf(0, p.pos.distance_to(center) - 40))
		if p.pos.distance_to(center) <= 90 and Map.line_clear(p.pos, center):
			damage_monster(id, target, skill.power)
			world.effects_system.fx("slash", p.pos, center, 65, color)

func area_damage(owner: int, center: Vector2, radius: float, amount: float, status := "") -> void:
	for i in range(world.monsters.size()):
		if world.monsters[i].hp > 0 and center.distance_to(world.monsters[i].pos) <= radius and Map.line_clear(center, world.monsters[i].pos):
			damage_monster(owner, i, amount, status)

func damage_monster(owner: int, target: int, amount: float, status := "") -> void:
	if not world.players.has(owner) or world.players[owner].hp <= 0 or world.monsters[target].hp <= 0:
		return
	var monster: Dictionary = world.monsters[target]
	amount += world.players[owner].power
	if world.players[owner].crit > 0 and randf() < world.players[owner].crit:
		amount *= 1.5
	if Expansion.boss_shield(world, monster):
		amount *= 0.2
	monster.contributors[owner] = world.clock
	monster.hp = maxf(0, monster.hp - amount)
	monster.hit = 0.2
	if status == "slow":
		monster.slow = 3.0
	elif status == "root":
		monster.root = 0.3 if monster.kind >= 3 else 2.0
	world.players[owner].combat = 4.0
	world.effects_system.number(monster.pos, str(int(amount)), Color("fff0af"))
	if monster.hp <= 0:
		monster.timer = 60.0 if monster.kind >= 3 else 8.0
		monster.windup = 0.0
		for minion in world.monsters:
			if minion.get("summoner",-1) == monster.id:
				minion.hp = 0
		for zone in world.zones:
			if zone.get("source", -1) == monster.id:
				zone.life = 0
		for contributor in monster.contributors:
			if not world.players.has(contributor) or world.clock - monster.contributors[contributor] > 15:
				continue
			var p: Dictionary = world.players[contributor]
			if p.hp <= 0 or p.pos.distance_to(monster.pos) > 650:
				continue
			var def: Dictionary = Data.ENEMIES[monster.kind]
			p.xp += def.xp
			p.gold += 2
			p.kills += 1
			p.progress[def.key] += 1
			world.effects_system.message(p, "%s derrotado! +%s XP, +2 ouro." % [def.name, def.xp])
			Expansion.on_kill(world, p, monster)
		world.effects_system.fx("defeat", monster.pos, monster.pos, 45 if monster.kind >= 3 else 30, Color("e9d48e"))

func hurt_player(id: int, damage: float) -> void:
	var p: Dictionary = world.players[id]
	if p.hp <= 0:
		return
	if p.evade > 0:
		world.effects_system.number(p.pos, "ESQUIVA", Color("9ce9c0"))
		return
	damage = maxf(1, damage - p.armor * 0.6)
	var absorbed := minf(p.shield, damage)
	p.shield -= absorbed
	damage -= absorbed
	p.hp = maxf(0, p.hp - damage)
	p.combat = 4.0
	world.effects_system.number(p.pos, str(int(damage)) if damage > 0 else "BLOQUEIO", Color("ffa898"))
	if p.hp <= 0:
		p.respawn = 3.0
		p.cast = {}
		p.shield = 0.0

func set_class(id: int, class_id: int) -> bool:
	if not world.players.has(id) or class_id < 0 or class_id >= Data.CLASS_NAMES.size():
		return false
	var p: Dictionary = world.players[id]
	if p.hp <= 0 or p.pos.distance_to(world.SPAWN) > 85 or p.combat > 0:
		world.effects_system.message(p, "Troque de classe junto à fonte e fora de combate.")
		return false
	if p.class_id == class_id:
		return true
	p.class_id = class_id
	if Realm.ITEMS.get(p.equipped.weapon, {}).get("class", -1) != class_id:
		p.equipped.weapon = Realm.STARTERS[class_id]
	Expansion.recalculate(p)
	p.hp = p.max_hp
	p.mana = p.max_mana
	p.cds = [0.0,0.0,0.0,0.0,0.0]
	p.cast = {}
	p.request = -1
	p.shield = 0.0
	p.shield_time = 0.0
	p.evade = 0.0
	# Remove world.effects from the previous class to prevent class-swap damage exploits.
	world.projectiles = world.projectiles.filter(func(shot): return shot.owner != id)
	world.zones = world.zones.filter(func(zone): return zone.owner != id)
	world.effects_system.message(p, "Classe alterada: %s. As cinco habilidades estão disponíveis." % Data.CLASS_NAMES[class_id])
	return true
