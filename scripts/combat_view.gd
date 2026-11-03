extends Node2D
const Data = preload("res://scripts/game_data.gd")
const ACTIONS = preload("res://assets/class_actions.png")
const ENEMIES = preload("res://assets/enemies.png")
var world: Node2D

func _draw() -> void:
	if not is_instance_valid(world):
		return
	draw_texture_rect(world.MAP_TEXTURE, Rect2(0, 0, 1152, 636), false)
	_draw_landmarks()
	for zone in world.zones:
		var color := Color("aab5ff") if zone.kind == "storm" else Color("b8dc89")
		draw_circle(zone.pos, zone.radius, Color(color, 0.12))
		draw_arc(zone.pos, zone.radius, 0, TAU, 32, Color(color, 0.65), 2)
		if zone.kind == "trap":
			for i in range(6):
				var angle := i * TAU / 6
				draw_line(zone.pos, zone.pos + Vector2.from_angle(angle) * 20, color, 2)
	for monster in world.monsters:
		if monster.hp > 0 and monster.windup > 0:
			var def: Dictionary = Data.ENEMIES[monster.kind]
			var ratio: float = 1 - monster.windup / def.windup
			draw_circle(monster.attack_pos, def.radius, Color(0.95, 0.25, 0.15, 0.2))
			draw_arc(monster.attack_pos, def.radius, -PI / 2, -PI / 2 + TAU * ratio, 32, Color("ffbd87"), 3)
	var actors: Array[Dictionary] = []
	for i in range(world.monsters.size()):
		if world.monsters[i].hp > 0:
			actors.append({"id":i, "player":false, "y":world.monsters[i].pos.y})
	for id in world.players:
		if world.players[id].hp > 0:
			actors.append({"id":id, "player":true, "y":world.players[id].pos.y})
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
		if shot.kind in ["arrow", "double"]:
			draw_line(shot.pos - direction * 18, shot.pos, Color("e6ce99"), 3)
			var side := direction.orthogonal() * 5
			draw_colored_polygon(PackedVector2Array([shot.pos + direction * 5, shot.pos - direction * 4 + side, shot.pos - direction * 4 - side]), Color("eaf1dd"))
		else:
			var color := Color("ffad62") if shot.kind == "fire" else Color("c5a4ff")
			draw_line(shot.pos - direction * 25, shot.pos, Color(color, 0.5), 5)
			draw_circle(shot.pos, 7, Color(color, 0.3))
			draw_circle(shot.pos, 4, color)
	for fx in world.effects:
		_draw_effect(fx)
	if "--debug-collisions" in OS.get_cmdline_user_args():
		for rect in world.Map.BLOCKERS:
			draw_rect(rect, Color(1, 0.15, 0.15, 0.3))

func _draw_landmarks() -> void:
	var pos: Vector2 = world.SPAWN
	draw_circle(pos + Vector2(0, 7), 29, Color("5b685b"))
	draw_circle(pos, 27, Color("c9cba5"))
	draw_circle(pos, 21, Color("368f9c"))
	draw_circle(pos + Vector2(-2, -3), 16, Color("6ed4ca"))
	draw_rect(Rect2(pos + Vector2(-5, -19), Vector2(10, 23)), Color("dce0bb"))
	_text("Fonte · troque de classe aqui", pos + Vector2(-80, -86), Color("fff2bb"), 12)
	pos = Data.NPC_POS
	_shadow(pos)
	draw_colored_polygon(PackedVector2Array([pos + Vector2(-13, 10), pos + Vector2(-8, -19), pos + Vector2(8, -19), pos + Vector2(13, 10)]), Color("ca9b66"))
	draw_circle(pos + Vector2(0, -25), 8, Color("eec79c"))
	draw_rect(Rect2(pos + Vector2(-9, -34), Vector2(18, 6)), Color("eee0ae"))
	draw_line(pos + Vector2(17, -29), pos + Vector2(17, 12), Color("83694a"), 3)
	draw_circle(pos + Vector2(17, -30), 4, Color("bbefcd"))
	_text("Lia · missões [F]", pos + Vector2(-47, -47), Color("ffe7a5"), 13)
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
	var pos: Vector2 = enemy.pos
	var def: Dictionary = Data.ENEMIES[enemy.kind]
	_shadow(pos)
	var selected: bool = world.desired_target == id
	var local: Dictionary = world.players.get(multiplayer.get_unique_id(), {})
	if not local.is_empty() and local.target == id and world.desired_target < 0:
		selected = true
	if selected:
		draw_arc(pos, 25 if enemy.kind < 2 else 34, 0, TAU, 32, Color("ffcf73"), 3)
	var frame := 1 if enemy.moving else 0
	if enemy.windup > 0:
		frame = 2 if enemy.windup > 0.2 else 3
	var cell := ENEMIES.get_size() / Vector2(4, 3)
	var dimensions := Vector2(64, 64) if enemy.kind == 0 else (Vector2(78, 78) if enemy.kind == 1 else Vector2(96, 96))
	var bob := sin(Time.get_ticks_msec() * 0.014) * 2 if enemy.moving else 0.0
	var tint := Color(1.4, 1.15, 1.15) if enemy.hit > 0 else Color.WHITE
	draw_texture_rect_region(ENEMIES, Rect2(pos + Vector2(-dimensions.x / 2, -dimensions.y + 14 + bob), dimensions), Rect2(Vector2(frame, enemy.kind) * cell, cell), tint)
	if enemy.root > 0 or enemy.slow > 0:
		draw_arc(pos, 22, 0, TAU, 6, Color("b4ebfb") if enemy.slow > 0 else Color("8bd19e"), 3)
	var top: Vector2 = pos + Vector2(-25, -dimensions.y + 5)
	_bar(top, 50, enemy.hp / enemy.max_hp, Color("dc9f80"))
	if selected or enemy.kind == 2:
		_text(def.name, top + Vector2(-14, -5), Color("ffe3ab"), 11)

func _draw_player(id: int) -> void:
	var p: Dictionary = world.players[id]
	var pos: Vector2 = p.pos
	var local: bool = id == multiplayer.get_unique_id()
	_shadow(pos)
	if local:
		draw_arc(pos, 24, 0, TAU, 24, Data.CLASS_COLORS[p.class_id], 2)
	if p.shield > 0:
		draw_arc(pos - Vector2(0, 12), 34, 0, TAU, 32, Color(0.7, 0.85, 1.0, 0.75), 3)
	if p.evade > 0:
		draw_circle(pos, 26, Color(0.5, 1, 0.7, 0.2))
	var animation: Dictionary = world.animations.get(id, {"row":0, "frame":0, "elapsed":0.0})
	var sheet: Texture2D = world.HERO_SHEET
	var region: Rect2 = world._hero_region(animation.row, animation.frame)
	var bob := 0.0
	if p.class_id != 0 or p.swing > 0:
		sheet = ACTIONS
		var cell := ACTIONS.get_size() / Vector2(4, 3)
		var frame := clampi(int((0.48 - p.swing) / 0.12), 0, 3) if p.swing > 0 else 0
		region = Rect2(Vector2(frame, p.class_id) * cell, cell)
		if p.swing <= 0 and animation.elapsed > 0:
			bob = sin(Time.get_ticks_msec() * 0.018) * 2
		if p.facing.x < 0:
			draw_set_transform(pos, 0, Vector2(-1, 1))
			draw_texture_rect_region(sheet, Rect2(Vector2(-38, -60 + bob), Vector2(76, 76)), region)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_texture_rect_region(sheet, Rect2(pos + Vector2(-38, -60 + bob), Vector2(76, 76)), region)
	else:
		draw_texture_rect_region(sheet, Rect2(pos + Vector2(-38, -60), Vector2(76, 76)), region)
	_bar(pos + Vector2(-20, -61), 40, p.hp / p.max_hp, Color("79c7ba"))
	_text(Data.CLASS_NAMES[p.class_id] if local else "Viajante · " + Data.CLASS_NAMES[p.class_id], pos + Vector2(-32, -68), Color("fff0ad"), 12)

func _draw_effect(fx: Dictionary) -> void:
	var progress: float = clampf(1 - fx.life / fx.duration, 0, 1)
	var color: Color = fx.color
	color.a = minf(1, fx.life * 4)
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
