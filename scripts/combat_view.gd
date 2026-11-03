extends Node2D
const Animator = preload("res://scripts/presentation/animation_controller.gd")
const Realm = preload("res://scripts/realm_data.gd")
const FOREST = preload("res://assets/forest.png")
const RUINS = preload("res://assets/ruins.png")
const MAGE_WALK = preload("res://assets/mage_walk.png")
const RANGER_WALK = preload("res://assets/ranger_walk.png")
const BOSSES = preload("res://assets/bosses.png")
const SKILL_ATLAS = preload("res://assets/skill_atlas.png")
const Data = preload("res://scripts/game_data.gd")
const ACTIONS = preload("res://assets/class_actions.png")
const ENEMIES = preload("res://assets/enemies.png")
var world: Node2D

func _draw() -> void:
	if not is_instance_valid(world):
		return
	var local_area := _local_area()
	_draw_landmarks()
	_draw_interactables()
	for zone in world.zones:
		if zone.get("hostile", false):
			_draw_hazard(zone)
			continue
		var color := Color("aab5ff") if zone.kind == "storm" else Color("b8dc89")
		draw_circle(zone.pos, zone.radius, Color(color, 0.12))
		draw_arc(zone.pos, zone.radius, 0, TAU, 32, Color(color, 0.65), 2)
		if zone.kind == "trap":
			for i in range(6):
				var angle := i * TAU / 6
				draw_line(zone.pos, zone.pos + Vector2.from_angle(angle) * 20, color, 2)
	for monster in world.monsters:
		if monster.hp > 0 and monster.windup > 0 and monster.kind < 3:
			var def: Dictionary = Data.ENEMIES[monster.kind]
			var ratio: float = 1 - monster.windup / def.windup
			draw_circle(monster.attack_pos, def.radius, Color(0.95, 0.25, 0.15, 0.2))
			draw_arc(monster.attack_pos, def.radius, -PI / 2, -PI / 2 + TAU * ratio, 32, Color("ffbd87"), 3)
	var actors: Array[Dictionary] = []
	for i in range(world.monsters.size()):
		if world.monsters[i].hp > 0:
			actors.append({"id":i, "player":false, "y":world.enemy_display_pos(i).y})
	for id in world.players:
		if world.players[id].hp > 0:
			actors.append({"id":id, "player":true, "y":world.player_display_pos(id).y})
	actors.sort_custom(func(a, b): return a.y < b.y)
	for actor in actors:
		if actor.player:
			_draw_player(actor.id)
		else:
			_draw_enemy(actor.id)
	for shot in world.projectiles:
		if shot.delay > 0:
			continue
		var direction: Vector2 = shot.velocity.normalized()
		var shot_pos: Vector2 = world.render_projectiles.get(shot.id,shot.pos)
		if shot.kind in ["arrow", "double"]:
			draw_line(shot_pos - direction * 18, shot_pos, Color("e6ce99"), 3)
			var side := direction.orthogonal() * 5
			draw_colored_polygon(PackedVector2Array([shot_pos + direction * 5, shot_pos - direction * 4 + side, shot_pos - direction * 4 - side]), Color("eaf1dd"))
		else:
			var color := Color("ffad62") if shot.kind == "fire" else Color("c5a4ff")
			draw_line(shot_pos - direction * 25, shot_pos, Color(color, 0.5), 5)
			draw_circle(shot_pos, 7, Color(color, 0.3))
			draw_circle(shot_pos, 4, color)
		var cell := SKILL_ATLAS.get_size()/Vector2(5,4)
		var row := 2 if shot.kind in ["arrow","double"] else 1
		var column := 1 if shot.kind == "fire" else 0
		draw_set_transform(shot_pos,direction.angle()+PI/4)
		draw_texture_rect_region(SKILL_ATLAS,Rect2(-18,-18,36,36),Rect2(Vector2(column,row)*cell,cell))
		draw_set_transform(Vector2.ZERO)
	for fx in world.effects:
		_draw_effect(fx)
	if "--debug-collisions" in OS.get_cmdline_user_args():
		for polygon in world.Map.Registry.collision_polygons():
			draw_colored_polygon(polygon,Color(1,0.15,0.15,0.3))

func _draw_landmarks() -> void:
	var pos: Vector2 = world.SPAWN
	draw_circle(pos + Vector2(0, 7), 29, Color("5b685b"))
	draw_circle(pos, 27, Color("c9cba5"))
	draw_circle(pos, 21, Color("368f9c"))
	draw_circle(pos + Vector2(-2, -3), 16, Color("6ed4ca"))
	draw_rect(Rect2(pos + Vector2(-5, -19), Vector2(10, 23)), Color("dce0bb"))
	_text("Fonte · troque de classe aqui", pos + Vector2(-80, -86), Color("fff2bb"), 12)
	for npc in Realm.NPCS:
		if npc.area != _local_area():
			continue
		pos = npc.pos
		_shadow(pos)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(-13, 10), pos + Vector2(-8, -19), pos + Vector2(8, -19), pos + Vector2(13, 10)]), Color("ca9b66") if npc.area == 0 else (Color("80b393") if npc.area == 1 else Color("9fa5d6")))
		draw_circle(pos + Vector2(0, -25), 8, Color("eec79c"))
		draw_rect(Rect2(pos + Vector2(-9, -34), Vector2(18, 6)), Color("eee0ae"))
		draw_line(pos + Vector2(17, -29), pos + Vector2(17, 12), Color("83694a"), 3)
		draw_circle(pos + Vector2(17, -30), 4, Color("bbefcd"))
		_text(npc.name + " · [F]", pos + Vector2(-45, -47), Color("ffe7a5"), 13)
		_text("!", pos + Vector2(-5, -65), Color("ffe589"), 22)
	var p: Dictionary = world.players.get(multiplayer.get_unique_id(), {})
	for i in range(Data.HERBS.size()):
		if not p.is_empty() and p.picked.has(i):
			continue
		pos = Data.HERBS[i]
		draw_circle(pos, 17, Color(0.4, 0.95, 0.65, 0.12 + 0.05 * sin(Time.get_ticks_msec() * 0.004)))
		for side in [-1, 1]:
			draw_line(pos, pos + Vector2(side * 5, -14), Color("3d7750"), 3)
			draw_circle(pos + Vector2(side * 6, -11), 5, Color("a6f5b6"))
		_text("Erva [F]", pos + Vector2(-24, -24), Color("d3ffd4"), 11)
	pos = Data.LANDMARK
	draw_circle(pos, 27, Color(0.3, 0.7, 1, 0.13))
	draw_rect(Rect2(pos + Vector2(-12, -37), Vector2(24, 47)), Color("697c8e"))
	draw_rect(Rect2(pos + Vector2(-8, -32), Vector2(16, 36)), Color("91b4be"))
	draw_arc(pos + Vector2(0, -16), 7, 0, TAU, 4, Color("c4f9ff"), 2)
	_text("Marco do vale", pos + Vector2(-40, -48), Color("b6ecff"), 12)

func _draw_enemy(id: int) -> void:
	var enemy: Dictionary = world.monsters[id]
	var pos: Vector2 = world.enemy_display_pos(id)
	var def: Dictionary = Data.ENEMIES[enemy.kind]
	_shadow(pos)
	var selected: bool = world.desired_target == id
	var local: Dictionary = world.players.get(multiplayer.get_unique_id(), {})
	if not local.is_empty() and local.target == id and world.desired_target < 0:
		selected = true
	if selected:
		draw_arc(pos, 25 if enemy.kind < 2 else 34, 0, TAU, 32, Color("ffcf73"), 3)
	var pose := Animator.enemy_pose(enemy)
	var dimensions: Vector2 = pose.size
	var tint := Color(1.4,1.15,1.15) if enemy.hit>0 else Color.WHITE
	draw_set_transform(pos,0,Vector2(-1 if pose.flip else 1,1))
	draw_texture_rect_region(pose.texture,Rect2(-dimensions*pose.anchor,dimensions),pose.region,tint)
	draw_set_transform(Vector2.ZERO)
	if enemy.root > 0 or enemy.slow > 0:
		draw_arc(pos, 22, 0, TAU, 6, Color("b4ebfb") if enemy.slow > 0 else Color("8bd19e"), 3)
	var top: Vector2 = pos + Vector2(-25, -dimensions.y + 5)
	_bar(top, 50, enemy.hp / enemy.max_hp, Color("dc9f80"))
	if selected or enemy.kind >= 2:
		_text(def.name + (" · Fase %s" % enemy.phase if enemy.kind >= 3 else ""), top + Vector2(-35,-5), Color("ffe3ab"),11)
	if world.Expansion.boss_shield(world, enemy):
		_text("ESCUDO · QUEBRE OS PILARES [F]", top + Vector2(-65, -24), Color("c5b7ff"),12)

func _draw_player(id: int) -> void:
	var p: Dictionary = world.players[id]
	var pos: Vector2 = world.player_display_pos(id)
	var local: bool = id == multiplayer.get_unique_id()
	_shadow(pos)
	if local:
		draw_arc(pos, 24, 0, TAU, 24, Data.CLASS_COLORS[p.class_id], 2)
	if p.shield > 0:
		draw_arc(pos - Vector2(0, 12), 34, 0, TAU, 32, Color(0.7, 0.85, 1.0, 0.75), 3)
	if p.evade > 0:
		draw_circle(pos, 26, Color(0.5, 1, 0.7, 0.2))
	var animation: Dictionary = world.animations.get(id,{})
	if animation.is_empty():
		animation = Animator.update_hero(p,{},0)
	var pose: Dictionary = animation.pose
	draw_set_transform(pos,0,Vector2(-1 if pose.flip else 1,1))
	draw_texture_rect_region(pose.texture,Rect2(-pose.size*pose.anchor,pose.size),pose.region)
	draw_set_transform(Vector2.ZERO)
	_bar(pos + Vector2(-20, -61), 40, p.hp / p.max_hp, Color("79c7ba"))
	_text(Data.CLASS_NAMES[p.class_id] if local else "Viajante · " + Data.CLASS_NAMES[p.class_id], pos + Vector2(-32, -68), Color("fff0ad"), 12)

func _draw_effect(fx: Dictionary) -> void:
	var progress: float = clampf(1 - fx.life / fx.duration, 0, 1)
	var color: Color = fx.color
	color.a = clampf(fx.life*4,0,1)
	if fx.kind != "number":
		var column := -1
		if fx.kind in ["slash","whirl"]:
			column = 0
		elif fx.kind in ["fire","enemy_hit"]:
			column = 1
		elif fx.kind == "frost":
			column = 2
		elif fx.kind in ["storm","cast"]:
			column = 3
		elif fx.kind in ["heal","shield"]:
			column = 4
		if column >= 0:
			var cell := SKILL_ATLAS.get_size() / Vector2(5,4)
			var size: float = clampf(fx.radius * (0.8 + progress),40,200)
			draw_texture_rect_region(SKILL_ATLAS,Rect2(fx.pos - Vector2(size,size) / 2 - Vector2(0,18),Vector2(size,size)),Rect2(Vector2(column,3) * cell,cell),Color(1,1,1,color.a * 0.85))
	if fx.kind == "number":
		_text(fx.text, fx.pos + Vector2(-8, -38 - progress * 28), color, 19)
	elif fx.kind == "slash":
		var angle: float = fx.pos.angle_to_point(fx.to)
		draw_arc(fx.pos, 20 + progress * fx.radius, angle - 0.7, angle + 0.7, 20, color, 5 * (1 - progress) + 1)
	elif fx.kind in ["storm", "rain"]:
		for i in range(7):
			var pos: Vector2 = fx.pos + Vector2.from_angle(i * 2.4) * (15 + i * 10)
			var start := pos + Vector2(9, -80 * (1 - progress))
			draw_line(start, pos, color, 3)
			if fx.kind == "storm":
				draw_line(start, start + Vector2(-13, 25), Color.WHITE, 2)
		draw_arc(fx.pos, fx.radius * progress, 0, TAU, 32, color, 2)
	elif fx.kind in ["whirl", "frost", "fire", "enemy_hit", "defeat", "heal", "root", "shield", "evade", "cast"]:
		draw_arc(fx.pos, maxf(4, fx.radius * progress), 0, TAU, 32, color, 3)
		for i in range(8):
			var spark: Vector2 = fx.pos + Vector2.from_angle(i * TAU / 8 + progress) * fx.radius * progress
			draw_rect(Rect2(spark, Vector2(3, 3)), color)
		if fx.kind == "heal":
			draw_line(fx.pos + Vector2(-8, -16), fx.pos + Vector2(8, -16), color, 4)
			draw_line(fx.pos + Vector2(0, -24), fx.pos + Vector2(0, -8), color, 4)

func _text(text: String, pos: Vector2, color: Color, size := 14) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color("29352d"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _shadow(pos: Vector2) -> void:
	draw_set_transform(pos + Vector2(0, 10), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 20, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

func _bar(pos: Vector2, width: float, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(width, 4)), Color("17232e"))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0, 1), 4)), color)

func _local_area() -> int:
	var p: Dictionary = world.players.get(multiplayer.get_unique_id(),{})
	return maxi(0,Realm.area_at(p.pos)) if not p.is_empty() else 0

func _draw_hazard(zone: Dictionary) -> void:
	if zone.life <= 0:
		return
	var armed: bool = zone.arm <= 0
	var color := Color(0.95,0.37,0.28,0.26 if armed else 0.12)
	if zone.kind == "pylon":
		var pos: Vector2 = zone.pos
		draw_circle(pos,32,Color(0.6,0.45,1,0.15))
		draw_rect(Rect2(pos + Vector2(-10,-46),Vector2(20,56)),Color("7376ac"))
		draw_rect(Rect2(pos + Vector2(-4,-40),Vector2(8,40)),Color("c5a8ff"))
		_text("Pilar [F]",pos + Vector2(-25,-54),Color("e5ceff"),12)
	elif zone.kind == "ring":
		draw_arc(zone.pos,(zone.radius + zone.inner)/2,0,TAU,64,color,zone.radius-zone.inner)
		draw_arc(zone.pos,zone.inner,0,TAU,64,Color("a0eac6"),2)
		draw_arc(zone.pos,zone.radius,0,TAU,64,Color("e9ac85"),2)
		_text("CENTRO SEGURO",zone.pos + Vector2(-48,-5),Color("b1efcc"),12)
	elif zone.kind == "thorns":
		draw_line(zone.pos,zone.to,color,zone.radius * 2)
		draw_line(zone.pos,zone.to,Color("d9a295"),2)
		if armed:
			for i in range(12):
				var point: Vector2 = zone.pos.lerp(zone.to,i/11.0)
				draw_line(point,point + Vector2(5,-22),Color("c5b3d7"),4)
	else:
		draw_circle(zone.pos,zone.radius,color if zone.kind == "meteor" else Color(0.5,0.3,0.7,0.22))
		draw_arc(zone.pos,zone.radius,0,TAU,40,Color("eebfa4"),2)
		if zone.kind == "spores" and armed:
			for i in range(10):
				var point: Vector2 = zone.pos + Vector2.from_angle(i * 2.4 + Time.get_ticks_msec() * 0.0008) * zone.radius * 0.7
				draw_circle(point,4,Color(0.6,0.9,0.55,0.6))

func _draw_interactables() -> void:
	var p: Dictionary = world.players.get(multiplayer.get_unique_id(),{})
	for portal in Realm.PORTALS:
		if portal.area != _local_area():
			continue
		var pos: Vector2 = portal.pos
		draw_circle(pos,30,Color(0.4,0.8,1,0.12))
		draw_arc(pos,24,Time.get_ticks_msec()*0.0008,Time.get_ticks_msec()*0.0008+TAU*0.85,24,Color("a3e7e7"),3)
		_text(portal.name + " [F]",pos + Vector2(-60,-38),Color("d7f4dc"),13)
	for i in range(Realm.CHESTS.size()):
		var chest: Dictionary = Realm.CHESTS[i]
		if chest.area != _local_area():
			continue
		var pos: Vector2 = chest.pos
		var opened: bool = not p.is_empty() and p.opened.has(i)
		draw_rect(Rect2(pos + Vector2(-14,-15),Vector2(28,23)),Color("795a39"))
		draw_rect(Rect2(pos + Vector2(-14,-17 if not opened else -27),Vector2(28,8)),Color("b99b55"))
		draw_rect(Rect2(pos + Vector2(-3,-9),Vector2(6,8)),Color("e9dca0"))
		_text("Baú aberto" if opened else "Tesouro [F]",pos + Vector2(-32,-34),Color("f4db9c"),11)
	for beacon in Realm.BEACONS:
		if beacon.area != _local_area():
			continue
		var pos: Vector2 = beacon.pos
		draw_circle(pos,32,Color(0.45,0.85,0.95,0.13))
		draw_rect(Rect2(pos + Vector2(-14,-42),Vector2(28,52)),Color("8b9eac"))
		draw_colored_polygon(PackedVector2Array([pos+Vector2(0,-37),pos+Vector2(8,-24),pos+Vector2(0,-10),pos+Vector2(-8,-24)]),Color("bceefa"))
		_text(beacon.name + " [F]",pos + Vector2(-65,-55),Color("d0edfa"),12)
