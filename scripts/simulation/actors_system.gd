extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
var world: Node

func _init(context: Node) -> void:
	world = context

func simulate(delta: float) -> void:
	world.clock += delta
	for fx in world.effects:
		fx.life -= delta
	world.effects = world.effects.filter(func(fx): return fx.life > 0)
	for id in world.players:
		var p: Dictionary = world.players[id]
		for i in range(5):
			p.cds[i] = maxf(0, p.cds[i] - delta)
		for timer in ["swing", "shield_time", "evade", "combat"]:
			p[timer] = maxf(0, p[timer] - delta)
		if p.shield_time <= 0:
			p.shield = 0.0
		if p.hp <= 0:
			p.respawn -= delta
			p.request = -1
			p.cast = {}
			if p.respawn <= 0:
				p.hp = p.max_hp
				p.mana = p.max_mana
				p.pos = world.SPAWN
				p.velocity = Vector2.ZERO
				p.shield = 0.0
				world.effects_system.message(p, "Você retornou à fonte. Seu progresso foi mantido.")
			continue
		var cmd: Dictionary = world.commands.get(id, {"direction":Vector2.ZERO, "attack":false})
		var direction: Vector2 = cmd.direction
		if world.clock - cmd.get("received", world.clock) > 0.35:
			direction = Vector2.ZERO
			cmd = {"direction":Vector2.ZERO, "attack":false}
		p.velocity = p.velocity.move_toward(direction.limit_length() * p.speed, delta * (950 if direction.length() > 0 else 1300))
		p.pos = Map.move_actor(p.pos, p.velocity * delta)
		if direction.length() > 0.1:
			p.facing = direction.normalized()
		if cmd.has("target"):
			p.target = cmd.target
		p.mana = minf(p.max_mana, p.mana + delta * 4)
		if p.pos.distance_to(world.SPAWN) < 64:
			p.hp = minf(p.max_hp, p.hp + delta * 16)
			p.mana = minf(p.max_mana, p.mana + delta * 15)
		if p.pos.distance_to(Data.LANDMARK) < 48:
			if p.progress.visit == 0:
				world.effects_system.message(p, "Marco descoberto! Retorne a Lia para receber a recompensa.")
			p.progress.visit = 1
		if not p.cast.is_empty():
			p.cast.time -= delta
			if p.cast.time <= 0:
				var cast: Dictionary = p.cast
				p.cast = {}
				world.combat.resolve_skill(id, cast)
		else:
			var slot: int = p.request
			if slot >= 0:
				p.target = p.request_target
			if slot < 0 and cmd.attack:
				slot = 0
			if slot >= 0:
				world.combat.begin_skill(id, slot)
			p.request = -1
	world.projectile.tick_projectiles(delta)
	world.effects_system.tick_zones(delta)
	for monster in world.monsters:
		tick_monster(monster, delta)

func tick_monster(monster: Dictionary, delta: float) -> void:
	if monster.get("summoned",false):
		var summoner: Dictionary = world.monsters[monster.summoner]
		if summoner.hp <= 0 or summoner.phase != 2:
			monster.hp = 0
			return
		if monster.hp <= 0:
			return
	if monster.hp <= 0:
		monster.timer -= delta
		if monster.timer <= 0:
			monster.hp = monster.max_hp
			monster.pos = monster.home
			monster.path = []
			monster.phase = 1
			monster.pattern = 0
			monster.contributors = {}
			monster.velocity = Vector2.ZERO
			monster.slow = 0.0
			monster.root = 0.0
		return
	if monster.kind >= 3:
		Expansion.tick_boss(world, monster, delta)
		return
	var def: Dictionary = Data.ENEMIES[monster.kind]
	for timer in ["cooldown", "hit", "slow", "root", "path_timer"]:
		monster[timer] = maxf(0, monster[timer] - delta)
	monster.moving = false
	if monster.windup > 0:
		monster.windup -= delta
		if monster.windup <= 0:
			world.effects_system.fx("enemy_hit", monster.attack_pos, monster.attack_pos, def.radius, Color("f49e7b"))
			for id in world.players:
				if world.players[id].pos.distance_to(monster.attack_pos) < def.radius and world.players[id].pos.distance_to(world.SPAWN) > 85 and Map.line_clear(monster.pos, world.players[id].pos):
					world.combat.hurt_player(id, def.damage)
			monster.cooldown = 1.1 if monster.kind < 2 else 2.0
		return
	if monster.root > 0:
		return
	var target := -1
	var distance := 225.0
	for id in world.players:
		var p: Dictionary = world.players[id]
		var d: float = p.pos.distance_to(monster.pos)
		if p.hp > 0 and d < distance and p.pos.distance_to(world.SPAWN) > 85 and p.pos.distance_to(monster.home) < 330:
			target = id
			distance = d
	if target >= 0:
		if distance <= def.reach and monster.cooldown <= 0 and Map.line_clear(monster.pos, world.players[target].pos):
			monster.windup = def.windup
			monster.attack_pos = world.players[target].pos
		elif distance > def.reach * 0.9:
			move_monster(monster, world.players[target].pos, delta, def.speed)
		else:
			monster.velocity = monster.velocity.move_toward(Vector2.ZERO, delta * 450)
	else:
		monster.patrol_timer -= delta
		if monster.pos.distance_to(monster.home) > 240:
			monster.patrol_pos = monster.home
		elif monster.patrol_timer <= 0:
			monster.patrol_timer = 3.0 + fmod(monster.id * 1.7, 3.0)
			var angle: float = world.clock * 0.3 + monster.id * 2.4
			var candidate: Vector2 = monster.home + Vector2.from_angle(angle) * 55
			monster.patrol_pos = candidate if not Map.blocked(candidate) else monster.home
		if monster.patrol_timer < 2.5 or monster.pos.distance_to(monster.home) > 240:
			move_monster(monster, monster.patrol_pos, delta, def.speed * 0.4)

func move_monster(monster: Dictionary, destination: Vector2, delta: float, speed: float) -> void:
	if monster.pos.distance_to(destination) < 6:
		monster.velocity = monster.velocity.move_toward(Vector2.ZERO,delta*450)
		return
	var aim := destination
	if not Map.line_clear(monster.pos, destination, 11):
		if monster.path_timer <= 0:
			var start := Vector2i(Vector2(monster.pos) / 16)
			var end := Vector2i(destination / 16)
			monster.path = []
			if world.grid.is_in_boundsv(start) and world.grid.is_in_boundsv(end) and not world.grid.is_point_solid(start) and not world.grid.is_point_solid(end):
				var path: PackedVector2Array = world.grid.get_point_path(start, end)
				for point in path:
					monster.path.append(point)
			monster.path_timer = 0.5
		while not monster.path.is_empty() and monster.pos.distance_to(monster.path[0]) < 10:
			monster.path.pop_front()
		if monster.path.is_empty():
			return
		aim = monster.path[0]
	var before: Vector2 = monster.pos
	var desired: Vector2 = before.direction_to(aim) * speed * (0.45 if monster.slow > 0 else 1.0)
	var separation := Vector2.ZERO
	for other in world.monsters:
		var gap: float = before.distance_to(other.pos)
		if other.id != monster.id and other.hp > 0 and gap > 0.1 and gap < 32:
			separation += other.pos.direction_to(before) * (32-gap)*2
	desired = (desired+separation).limit_length(speed)
	monster.velocity = monster.velocity.move_toward(desired, delta * 300)
	monster.pos = Map.move_actor(monster.pos, monster.velocity.limit_length(minf(speed, before.distance_to(aim) / maxf(delta,0.001))) * delta)
	var movement: Vector2 = monster.pos - before
	if movement.length() > 0.05:
		monster.facing = movement.normalized()
		monster.stride += movement.length()
	monster.moving = before.distance_to(monster.pos) > 0.1
