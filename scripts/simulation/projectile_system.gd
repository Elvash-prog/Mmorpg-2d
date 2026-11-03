extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
var world: Node

func _init(context: Node) -> void:
	world = context

func spawn_projectile(owner: int, destination: Vector2, skill: Dictionary, delay := 0.0) -> void:
	var origin: Vector2 = world.players[owner].pos
	var speed := 550.0 if skill.kind in ["arrow", "double"] else 390.0
	world.projectile_serial += 1
	world.projectiles.append({"id":world.projectile_serial, "pos":origin, "origin":origin, "velocity":origin.direction_to(destination) * speed, "life":skill.range / speed + 0.06, "delay":delay, "owner":owner, "power":skill.power, "kind":skill.kind})
	world.effects_system.fx("cast", origin, destination, 30, Data.CLASS_COLORS[world.players[owner].class_id])

func tick_projectiles(delta: float) -> void:
	for shot in world.projectiles:
		if not world.players.has(shot.owner):
			shot.life = 0
			continue
		if shot.delay > 0:
			shot.delay -= delta
			continue
		var travel: float = minf(delta, shot.life)
		shot.life -= delta
		var previous: Vector2 = shot.pos
		var next: Vector2 = previous + shot.velocity * travel
		# Check the swept segment, not only the end of a fast projectile.
		var steps := maxi(1, ceili(previous.distance_to(next) / 5.0))
		for step in range(1, steps + 1):
			shot.pos = previous.lerp(next, float(step) / steps)
			if Map.blocked(shot.pos, 1):
				shot.life = 0
				break
			var hit := -1
			for i in range(world.monsters.size()):
				if world.monsters[i].hp > 0 and shot.pos.distance_to(world.monsters[i].pos) < 20:
					hit = i
					break
			if hit >= 0:
				if shot.kind == "fire":
					world.combat.area_damage(shot.owner, shot.pos, 80, shot.power)
					world.effects_system.fx("fire", shot.pos, shot.pos, 80, Color("ffad61"))
				else:
					world.combat.damage_monster(shot.owner, hit, shot.power)
				shot.life = 0
				break
	world.projectiles = world.projectiles.filter(func(shot): return shot.life > 0)
