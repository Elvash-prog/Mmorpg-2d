extends RefCounted
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
var world: Node

func _init(context: Node) -> void:
	world = context

func tick_zones(delta: float) -> void:
	for zone in world.zones:
		zone.life -= delta
		zone.tick -= delta
		if zone.get("hostile", false):
			Expansion.tick_hazard(world, zone, delta)
			continue
		if not world.players.has(zone.owner):
			zone.life = 0
			continue
		if zone.kind == "trap":
			for i in range(world.monsters.size()):
				if world.monsters[i].hp > 0 and zone.pos.distance_to(world.monsters[i].pos) <= zone.radius and Map.line_clear(zone.pos, world.monsters[i].pos):
					world.combat.damage_monster(zone.owner, i, zone.power, "root")
					fx("root", zone.pos, zone.pos, zone.radius, Color("b9d67b"))
					zone.life = 0
					break
		elif zone.tick <= 0 and zone.pulses > 0:
			world.combat.area_damage(zone.owner, zone.pos, zone.radius, zone.power)
			fx(zone.kind, zone.pos, zone.pos, zone.radius, Color("adbbff") if zone.kind == "storm" else Color("d8e9a4"))
			zone.tick = 0.8
			zone.pulses -= 1
	world.zones = world.zones.filter(func(zone): return zone.life > 0)

func fx(kind: String, pos: Vector2, destination: Vector2, radius: float, color: Color) -> void:
	world.effects.append({"kind":kind, "pos":pos, "to":destination, "radius":radius, "color":color, "life":0.5, "duration":0.5, "text":""})

func number(pos: Vector2, text: String, color: Color) -> void:
	world.effects.append({"kind":"number", "pos":pos, "to":pos, "radius":0, "color":color, "life":0.8, "duration":0.8, "text":text})

func message(p: Dictionary, text: String) -> void:
	if p.message != text or world.clock - p.message_time > 1:
		p.message = text
		p.message_time = world.clock
