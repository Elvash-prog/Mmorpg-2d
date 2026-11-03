extends Node2D
## Authoritative co-op RPG prototype. The server owns every gameplay outcome.
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
const HERO_SHEET = preload("res://assets/guardian.png")
const MAP_TEXTURE = preload("res://assets/village.png")
const PORT := 24567
const SPEED := 165.0
const ARENA := Map.BOUNDS
const SPAWN := Vector2(300, 318)
var players: Dictionary = {}
var monsters: Array[Dictionary] = []
var commands: Dictionary = {}
var animations: Dictionary = {}
var projectiles: Array[Dictionary] = []
var zones: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var camera := Camera2D.new()
var render_players: Dictionary = {}
var render_enemies: Dictionary = {}
var render_projectiles: Dictionary = {}
var projectile_serial := 0
var camera_initialized := false
var grid := AStarGrid2D.new()
var clock := 0.0
var send_elapsed := 0.0
var connection_elapsed := 0.0
var touch_direction := Vector2.ZERO
var touch_attack := false
var desired_target := -1
var status_label: Label
var stats_label: Label
var address: LineEdit
var host_button: Button
var join_button: Button
var hud: Control
var visuals: Node2D
var smoke_client := false
var smoke_host := false
var smoke_elapsed := 0.0
var smoke_attack_received := false
var smoke_special_received := false
var smoke_special_sent := false
var smoke_equip_received := false
var smoke_portal_received := false
var smoke_portal_sent := false
var smoke_special_confirmed := false

func _ready() -> void:
	_build_grid()
	add_child(camera)
	camera.position = Vector2(576,360)
	visuals = preload("res://scripts/combat_view.gd").new()
	visuals.world = self
	add_child(visuals)
	_build_ui()
	multiplayer.peer_connected.connect(_peer_connected)
	multiplayer.peer_disconnected.connect(_peer_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_disconnected)
	_reset_world()
	var args := OS.get_cmdline_user_args()
	if "--smoke-client" in args:
		smoke_client = true
		_join()
	elif "--server" in args:
		smoke_host = "--smoke-host" in args
		_host()
	_update_labels()

func _build_grid() -> void:
	grid.region = Rect2i(0, 0, 216, 159)
	grid.cell_size = Vector2(16, 16)
	grid.offset = Vector2(8, 8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(159):
		for x in range(216):
			grid.set_point_solid(Vector2i(x, y), Map.blocked(Vector2(x * 16 + 8, y * 16 + 8)))

func _reset_world() -> void:
	animations.clear()
	render_players.clear()
	render_enemies.clear()
	render_projectiles.clear()
	camera_initialized = false
	players.clear()
	commands.clear()
	projectiles.clear()
	zones.clear()
	effects.clear()
	desired_target = -1
	players[1] = _new_player()
	monsters.clear()
	var homes := [Vector2(620, 235), Vector2(760, 245), Vector2(640, 415), Vector2(820, 365), Vector2(925, 435), Vector2(850, 535)]
	for i in range(homes.size()):
		var kind := 0 if i < 3 else (1 if i < 5 else 2)
		monsters.append(_new_monster(homes[i], kind))
	Expansion.add_enemies(self)

func _new_monster(pos: Vector2, kind: int) -> Dictionary:
	var def: Dictionary = Data.ENEMIES[kind]
	return {"id":monsters.size(), "pos":pos, "home":pos, "kind":kind, "hp":def.hp, "max_hp":def.hp, "timer":0.0, "cooldown":0.0, "windup":0.0, "attack_pos":pos, "slow":0.0, "root":0.0, "hit":0.0, "moving":false, "path":[], "path_timer":0.0,
		"velocity":Vector2.ZERO, "facing":Vector2.RIGHT, "stride":0.0, "patrol_timer":0.0, "patrol_pos":pos, "phase":1, "pattern":0, "contributors":{}}

func _new_player(class_id := 0) -> Dictionary:
	var p := {"pos":SPAWN, "hp":Data.CLASS_HP[class_id], "max_hp":Data.CLASS_HP[class_id], "mana":Data.CLASS_MANA[class_id], "max_mana":Data.CLASS_MANA[class_id], "class_id":class_id,
		"xp":0, "gold":0, "kills":0, "cds":[0.0,0.0,0.0,0.0,0.0], "respawn":0.0, "swing":0.0, "last_skill":0, "cast":{}, "request":-1, "request_target":-1, "target":-1, "facing":Vector2.RIGHT,
		"shield":0.0, "shield_time":0.0, "evade":0.0, "combat":0.0, "progress":{"slime":0,"wolf":0,"golem":0,"herbs":0,"visit":0}, "picked":[], "claimed":[],
		"message":"A fonte está enfraquecendo. Fale com Lia [F] e prepare-se para partir.", "message_time":0.0}
	Expansion.initialize_player(p)
	return p

func _process(delta: float) -> void:
	var direction := _keyboard_direction() + touch_direction
	var attack := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_1) or touch_attack
	if address.has_focus() or hud.modal_open():
		direction = Vector2.ZERO
		attack = false
	if smoke_client:
		direction = Vector2.ZERO if smoke_portal_sent else Vector2.RIGHT
		attack = not smoke_special_sent
	if _is_authority():
		commands[1] = {"direction":direction.limit_length(), "attack":attack, "target":desired_target, "received":clock}
		_simulate(delta)
	else:
		connection_elapsed += delta
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_submit_input.rpc_id(1, direction.limit_length(), attack, desired_target)
		elif connection_elapsed > 8.0:
			_connection_failed()
	send_elapsed += delta
	if multiplayer.has_multiplayer_peer() and multiplayer.is_server() and send_elapsed >= 0.05:
		send_elapsed = 0.0
		_receive_state.rpc(var_to_bytes([players, monsters, projectiles, zones, effects]).compress(FileAccess.COMPRESSION_DEFLATE))
	_update_presentation(delta)
	_update_animation(delta)
	_update_labels()
	visuals.queue_redraw()
	_smoke_check(delta)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or address.has_focus():
		return
	if event.physical_keycode == KEY_ESCAPE:
		hud.close_modals()
	elif not hud.modal_open():
		if event.physical_keycode >= KEY_2 and event.physical_keycode <= KEY_5:
			use_skill(event.physical_keycode - KEY_1)
		elif event.physical_keycode == KEY_TAB:
			cycle_target()
		elif event.physical_keycode == KEY_F:
			interact()
		elif event.physical_keycode == KEY_J:
			hud.toggle_journal()
		elif event.physical_keycode == KEY_C:
			hud.toggle_character()

func _unhandled_input(event: InputEvent) -> void:
	if hud.modal_open():
		return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		point = get_global_mouse_position()
	elif event is InputEventScreenTouch and event.pressed:
		point = get_canvas_transform().affine_inverse() * event.position
	else:
		return
	var closest := 40.0
	desired_target = -1
	for i in range(monsters.size()):
		var d: float = point.distance_to(enemy_display_pos(i) - Vector2(0, 12))
		if monsters[i].hp > 0 and d < closest:
			closest = d
			desired_target = i

func _keyboard_direction() -> Vector2:
	return Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _is_authority() -> bool:
	return multiplayer.is_server()

func cycle_target() -> void:
	var valid: Array[int] = []
	var p: Dictionary = players.get(multiplayer.get_unique_id(), {})
	if p.is_empty():
		return
	for i in range(monsters.size()):
		if monsters[i].hp > 0 and p.pos.distance_to(monsters[i].pos) < 400:
			valid.append(i)
	if valid.is_empty():
		desired_target = -1
	else:
		desired_target = valid[(valid.find(desired_target) + 1) % valid.size()]

func use_skill(slot: int) -> void:
	if hud.modal_open():
		return
	if _is_authority():
		_queue_skill(1, slot, desired_target)
	else:
		_request_skill.rpc_id(1, slot, desired_target)

func interact() -> void:
	if _is_authority():
		_interact(1)
	else:
		_request_interaction.rpc_id(1)

func choose_class(class_id: int) -> void:
	if _is_authority():
		_set_class(1, class_id)
	else:
		_request_class.rpc_id(1, class_id)

func _queue_skill(id: int, slot: int, target: int) -> void:
	if players.has(id) and slot >= 0 and slot < 5 and target >= -1 and target < monsters.size():
		players[id].request = slot
		players[id].request_target = target

func _simulate(delta: float) -> void:
	clock += delta
	for fx in effects:
		fx.life -= delta
	effects = effects.filter(func(fx): return fx.life > 0)
	for id in players:
		var p: Dictionary = players[id]
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
				p.pos = SPAWN
				p.velocity = Vector2.ZERO
				p.shield = 0.0
				_message(p, "Você retornou à fonte. Seu progresso foi mantido.")
			continue
		var cmd: Dictionary = commands.get(id, {"direction":Vector2.ZERO, "attack":false})
		var direction: Vector2 = cmd.direction
		if clock - cmd.get("received", clock) > 0.35:
			direction = Vector2.ZERO
			cmd = {"direction":Vector2.ZERO, "attack":false}
		p.velocity = p.velocity.move_toward(direction.limit_length() * p.speed, delta * (950 if direction.length() > 0 else 1300))
		p.pos = Map.move_actor(p.pos, p.velocity * delta)
		if direction.length() > 0.1:
			p.facing = direction.normalized()
		if cmd.has("target"):
			p.target = cmd.target
		p.mana = minf(p.max_mana, p.mana + delta * 4)
		if p.pos.distance_to(SPAWN) < 64:
			p.hp = minf(p.max_hp, p.hp + delta * 16)
			p.mana = minf(p.max_mana, p.mana + delta * 15)
		if p.pos.distance_to(Data.LANDMARK) < 48:
			if p.progress.visit == 0:
				_message(p, "Marco descoberto! Retorne a Lia para receber a recompensa.")
			p.progress.visit = 1
		if not p.cast.is_empty():
			p.cast.time -= delta
			if p.cast.time <= 0:
				var cast: Dictionary = p.cast
				p.cast = {}
				_resolve_skill(id, cast)
		else:
			var slot: int = p.request
			if slot >= 0:
				p.target = p.request_target
			if slot < 0 and cmd.attack:
				slot = 0
			if slot >= 0:
				_begin_skill(id, slot)
			p.request = -1
	_tick_projectiles(delta)
	_tick_zones(delta)
	for monster in monsters:
		_tick_monster(monster, delta)

func _select_target(p: Dictionary, reach: float) -> int:
	var selected: int = p.target
	if selected >= 0 and selected < monsters.size() and monsters[selected].hp > 0:
		return selected
	var nearest := reach + 1
	var target := -1
	for i in range(monsters.size()):
		var d: float = p.pos.distance_to(monsters[i].pos)
		if monsters[i].hp > 0 and d < nearest and Map.line_clear(p.pos, monsters[i].pos):
			nearest = d
			target = i
	return target

func _begin_skill(id: int, slot: int) -> bool:
	var p: Dictionary = players[id]
	if slot < 0 or slot >= 5 or p.hp <= 0 or not p.cast.is_empty() or p.cds[slot] > 0:
		return false
	var skill: Dictionary = Data.SKILLS[p.class_id][slot]
	if p.mana < skill.cost:
		_message(p, "Energia insuficiente para %s." % skill.name)
		return false
	var target := -1
	if skill.kind in ["melee", "charge", "bolt", "fire", "arrow", "double", "storm", "rain", "trap"]:
		target = _select_target(p, skill.range)
		if target < 0:
			_message(p, "Selecione um inimigo ao alcance (clique ou TAB).")
			return false
		if p.pos.distance_to(monsters[target].pos) > skill.range:
			_message(p, "Alvo fora do alcance de %s." % skill.name)
			return false
		if not Map.line_clear(p.pos, monsters[target].pos):
			_message(p, "O cenário bloqueia a linha de visão.")
			return false
		p.facing = p.pos.direction_to(monsters[target].pos)
	p.target = target
	p.mana -= skill.cost
	p.cds[slot] = skill.cd
	p.swing = 0.48
	p.last_skill = slot
	p.cast = {"slot":slot, "target":target, "time":0.15}
	return true

func _resolve_skill(id: int, cast: Dictionary) -> void:
	var p: Dictionary = players[id]
	var skill: Dictionary = Data.SKILLS[p.class_id][cast.slot]
	var target: int = cast.target
	var center: Vector2 = monsters[target].pos if target >= 0 and target < monsters.size() else p.pos
	var color: Color = Data.CLASS_COLORS[p.class_id]
	if skill.kind == "shield":
		p.shield = float(skill.power)
		p.shield_time = 5.0
		_fx("shield", p.pos, p.pos, 50, color)
	elif skill.kind == "heal":
		var amount: float = minf(skill.power, p.max_hp - p.hp)
		p.hp += amount
		_fx("heal", p.pos, p.pos, 55, Color("86efad"))
		_number(p.pos, "+%s" % int(amount), Color("9af1b2"))
	elif skill.kind == "evade":
		p.pos = Map.move_actor(p.pos, -p.facing * 155)
		p.evade = 1.2
		_fx("evade", p.pos, p.pos, 45, color)
	elif skill.kind == "whirl" or skill.kind == "frost":
		_area_damage(id, p.pos, skill.range, skill.power, "slow" if skill.kind == "frost" else "")
		_fx(skill.kind, p.pos, p.pos, skill.range, Color("9ee9ff") if skill.kind == "frost" else color)
	elif skill.kind in ["storm", "rain", "trap"]:
		if target >= 0 and Map.line_clear(p.pos, center) and p.pos.distance_to(center) <= skill.range + 12:
			zones.append({"kind":skill.kind, "pos":center, "owner":id, "life":8.0 if skill.kind == "trap" else 3.4, "tick":0.0, "pulses":1 if skill.kind == "trap" else (4 if skill.kind == "storm" else 3), "radius":42.0 if skill.kind == "trap" else 95.0, "power":skill.power})
	elif skill.kind in ["bolt", "fire", "arrow", "double"]:
		if target >= 0 and monsters[target].hp > 0:
			_spawn_projectile(id, center, skill)
			if skill.kind == "double":
				_spawn_projectile(id, center, skill, 0.16)
	elif target >= 0 and monsters[target].hp > 0:
		if skill.kind == "charge":
			p.pos = Map.move_actor(p.pos, p.pos.direction_to(center) * maxf(0, p.pos.distance_to(center) - 40))
		if p.pos.distance_to(center) <= 90 and Map.line_clear(p.pos, center):
			_damage_monster(id, target, skill.power)
			_fx("slash", p.pos, center, 65, color)

func _spawn_projectile(owner: int, destination: Vector2, skill: Dictionary, delay := 0.0) -> void:
	var origin: Vector2 = players[owner].pos
	var speed := 550.0 if skill.kind in ["arrow", "double"] else 390.0
	projectile_serial += 1
	projectiles.append({"id":projectile_serial, "pos":origin, "origin":origin, "velocity":origin.direction_to(destination) * speed, "life":skill.range / speed + 0.06, "delay":delay, "owner":owner, "power":skill.power, "kind":skill.kind})
	_fx("cast", origin, destination, 30, Data.CLASS_COLORS[players[owner].class_id])

func _tick_projectiles(delta: float) -> void:
	for shot in projectiles:
		if not players.has(shot.owner):
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
			for i in range(monsters.size()):
				if monsters[i].hp > 0 and shot.pos.distance_to(monsters[i].pos) < 20:
					hit = i
					break
			if hit >= 0:
				if shot.kind == "fire":
					_area_damage(shot.owner, shot.pos, 80, shot.power)
					_fx("fire", shot.pos, shot.pos, 80, Color("ffad61"))
				else:
					_damage_monster(shot.owner, hit, shot.power)
				shot.life = 0
				break
	projectiles = projectiles.filter(func(shot): return shot.life > 0)

func _tick_zones(delta: float) -> void:
	for zone in zones:
		zone.life -= delta
		zone.tick -= delta
		if zone.get("hostile", false):
			Expansion.tick_hazard(self, zone, delta)
			continue
		if not players.has(zone.owner):
			zone.life = 0
			continue
		if zone.kind == "trap":
			for i in range(monsters.size()):
				if monsters[i].hp > 0 and zone.pos.distance_to(monsters[i].pos) <= zone.radius and Map.line_clear(zone.pos, monsters[i].pos):
					_damage_monster(zone.owner, i, zone.power, "root")
					_fx("root", zone.pos, zone.pos, zone.radius, Color("b9d67b"))
					zone.life = 0
					break
		elif zone.tick <= 0 and zone.pulses > 0:
			_area_damage(zone.owner, zone.pos, zone.radius, zone.power)
			_fx(zone.kind, zone.pos, zone.pos, zone.radius, Color("adbbff") if zone.kind == "storm" else Color("d8e9a4"))
			zone.tick = 0.8
			zone.pulses -= 1
	zones = zones.filter(func(zone): return zone.life > 0)

func _area_damage(owner: int, center: Vector2, radius: float, amount: float, status := "") -> void:
	for i in range(monsters.size()):
		if monsters[i].hp > 0 and center.distance_to(monsters[i].pos) <= radius and Map.line_clear(center, monsters[i].pos):
			_damage_monster(owner, i, amount, status)

func _damage_monster(owner: int, target: int, amount: float, status := "") -> void:
	if not players.has(owner) or players[owner].hp <= 0 or monsters[target].hp <= 0:
		return
	var monster: Dictionary = monsters[target]
	amount += players[owner].power
	if players[owner].crit > 0 and randf() < players[owner].crit:
		amount *= 1.5
	if Expansion.boss_shield(self, monster):
		amount *= 0.2
	monster.contributors[owner] = clock
	monster.hp = maxf(0, monster.hp - amount)
	monster.hit = 0.2
	if status == "slow":
		monster.slow = 3.0
	elif status == "root":
		monster.root = 0.3 if monster.kind >= 3 else 2.0
	players[owner].combat = 4.0
	_number(monster.pos, str(int(amount)), Color("fff0af"))
	if monster.hp <= 0:
		monster.timer = 60.0 if monster.kind >= 3 else 8.0
		monster.windup = 0.0
		for minion in monsters:
			if minion.get("summoner",-1) == monster.id:
				minion.hp = 0
		for zone in zones:
			if zone.get("source", -1) == monster.id:
				zone.life = 0
		for contributor in monster.contributors:
			if not players.has(contributor) or clock - monster.contributors[contributor] > 15:
				continue
			var p: Dictionary = players[contributor]
			if p.hp <= 0 or p.pos.distance_to(monster.pos) > 650:
				continue
			var def: Dictionary = Data.ENEMIES[monster.kind]
			p.xp += def.xp
			p.gold += 2
			p.kills += 1
			p.progress[def.key] += 1
			_message(p, "%s derrotado! +%s XP, +2 ouro." % [def.name, def.xp])
			Expansion.on_kill(self, p, monster)
		_fx("defeat", monster.pos, monster.pos, 45 if monster.kind >= 3 else 30, Color("e9d48e"))

func _hurt_player(id: int, damage: float) -> void:
	var p: Dictionary = players[id]
	if p.hp <= 0:
		return
	if p.evade > 0:
		_number(p.pos, "ESQUIVA", Color("9ce9c0"))
		return
	damage = maxf(1, damage - p.armor * 0.6)
	var absorbed := minf(p.shield, damage)
	p.shield -= absorbed
	damage -= absorbed
	p.hp = maxf(0, p.hp - damage)
	p.combat = 4.0
	_number(p.pos, str(int(damage)) if damage > 0 else "BLOQUEIO", Color("ffa898"))
	if p.hp <= 0:
		p.respawn = 3.0
		p.cast = {}
		p.shield = 0.0

func _tick_monster(monster: Dictionary, delta: float) -> void:
	if monster.get("summoned",false):
		var summoner: Dictionary = monsters[monster.summoner]
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
		Expansion.tick_boss(self, monster, delta)
		return
	var def: Dictionary = Data.ENEMIES[monster.kind]
	for timer in ["cooldown", "hit", "slow", "root", "path_timer"]:
		monster[timer] = maxf(0, monster[timer] - delta)
	monster.moving = false
	if monster.windup > 0:
		monster.windup -= delta
		if monster.windup <= 0:
			_fx("enemy_hit", monster.attack_pos, monster.attack_pos, def.radius, Color("f49e7b"))
			for id in players:
				if players[id].pos.distance_to(monster.attack_pos) < def.radius and players[id].pos.distance_to(SPAWN) > 85 and Map.line_clear(monster.pos, players[id].pos):
					_hurt_player(id, def.damage)
			monster.cooldown = 1.1 if monster.kind < 2 else 2.0
		return
	if monster.root > 0:
		return
	var target := -1
	var distance := 225.0
	for id in players:
		var p: Dictionary = players[id]
		var d: float = p.pos.distance_to(monster.pos)
		if p.hp > 0 and d < distance and p.pos.distance_to(SPAWN) > 85 and p.pos.distance_to(monster.home) < 330:
			target = id
			distance = d
	if target >= 0:
		if distance <= def.reach and monster.cooldown <= 0 and Map.line_clear(monster.pos, players[target].pos):
			monster.windup = def.windup
			monster.attack_pos = players[target].pos
		elif distance > def.reach * 0.9:
			_move_monster(monster, players[target].pos, delta, def.speed)
		else:
			monster.velocity = monster.velocity.move_toward(Vector2.ZERO, delta * 450)
	else:
		monster.patrol_timer -= delta
		if monster.pos.distance_to(monster.home) > 240:
			monster.patrol_pos = monster.home
		elif monster.patrol_timer <= 0:
			monster.patrol_timer = 3.0 + fmod(monster.id * 1.7, 3.0)
			var angle: float = clock * 0.3 + monster.id * 2.4
			var candidate: Vector2 = monster.home + Vector2.from_angle(angle) * 55
			monster.patrol_pos = candidate if not Map.blocked(candidate) else monster.home
		if monster.patrol_timer < 2.5 or monster.pos.distance_to(monster.home) > 240:
			_move_monster(monster, monster.patrol_pos, delta, def.speed * 0.4)

func _move_monster(monster: Dictionary, destination: Vector2, delta: float, speed: float) -> void:
	if monster.pos.distance_to(destination) < 6:
		monster.velocity = monster.velocity.move_toward(Vector2.ZERO,delta*450)
		return
	var aim := destination
	if not Map.line_clear(monster.pos, destination, 11):
		if monster.path_timer <= 0:
			var start := Vector2i(Vector2(monster.pos) / 16)
			var end := Vector2i(destination / 16)
			monster.path = []
			if grid.is_in_boundsv(start) and grid.is_in_boundsv(end) and not grid.is_point_solid(start) and not grid.is_point_solid(end):
				var path := grid.get_point_path(start, end)
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
	for other in monsters:
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

func _interact(id: int) -> void:
	if not players.has(id) or players[id].hp <= 0:
		return
	var p: Dictionary = players[id]
	if Expansion.interact(self, id):
		return
	for i in range(Data.HERBS.size()):
		if not p.picked.has(i) and p.pos.distance_to(Data.HERBS[i]) < 43 and Map.line_clear(p.pos, Data.HERBS[i]):
			p.picked.append(i)
			p.progress.herbs += 1
			_message(p, "Erva coletada: %s/3. Entregue a Lia quando concluir." % p.progress.herbs)
			_fx("heal", Data.HERBS[i], Data.HERBS[i], 25, Color("9fe8b0"))
			return
	var near_npc := false
	for npc in Realm.NPCS:
		if p.pos.distance_to(npc.pos) < 75:
			near_npc = true
	if not near_npc:
		_message(p, "Aproxime-se de Lia ou de uma erva luminosa para interagir.")
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
	_message(p, "%s missão(ões) entregues! Ouro e XP recebidos." % rewards if rewards > 0 else "Consulte o diário (J), cumpra os objetivos e volte ao acampamento para receber ouro e XP.")

func _set_class(id: int, class_id: int) -> bool:
	if not players.has(id) or class_id < 0 or class_id >= Data.CLASS_NAMES.size():
		return false
	var p: Dictionary = players[id]
	if p.hp <= 0 or p.pos.distance_to(SPAWN) > 85 or p.combat > 0:
		_message(p, "Troque de classe junto à fonte e fora de combate.")
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
	# Remove effects from the previous class to prevent class-swap damage exploits.
	projectiles = projectiles.filter(func(shot): return shot.owner != id)
	zones = zones.filter(func(zone): return zone.owner != id)
	_message(p, "Classe alterada: %s. As cinco habilidades estão disponíveis." % Data.CLASS_NAMES[class_id])
	return true

func _message(p: Dictionary, text: String) -> void:
	if p.message != text or clock - p.message_time > 1:
		p.message = text
		p.message_time = clock

func _fx(kind: String, pos: Vector2, destination: Vector2, radius: float, color: Color) -> void:
	effects.append({"kind":kind, "pos":pos, "to":destination, "radius":radius, "color":color, "life":0.5, "duration":0.5, "text":""})

func _number(pos: Vector2, text: String, color: Color) -> void:
	effects.append({"kind":"number", "pos":pos, "to":pos, "radius":0, "color":color, "life":0.8, "duration":0.8, "text":text})

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(direction: Vector2, attack: bool, target: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and is_finite(direction.x) and is_finite(direction.y) and target >= -1 and target < monsters.size():
		commands[id] = {"direction":direction.limit_length(), "attack":attack, "target":target, "received":clock}
		if attack:
			smoke_attack_received = true

@rpc("any_peer", "call_remote", "reliable")
func _request_skill(slot: int, target: int) -> void:
	if multiplayer.is_server():
		_queue_skill(multiplayer.get_remote_sender_id(), slot, target)
		if slot == 1:
			smoke_special_received = true

@rpc("any_peer", "call_remote", "reliable")
func _request_interaction() -> void:
	if multiplayer.is_server():
		_interact(multiplayer.get_remote_sender_id())
		var id := multiplayer.get_remote_sender_id()
		if players.has(id) and Realm.area_at(players[id].pos) == 1:
			smoke_portal_received = true

@rpc("any_peer", "call_remote", "reliable")
func _request_class(class_id: int) -> void:
	if multiplayer.is_server():
		_set_class(multiplayer.get_remote_sender_id(), class_id)

@rpc("authority", "call_remote", "reliable", 1)
func _receive_state(packet: PackedByteArray) -> void:
	# Reliable dedicated channel avoids fragmented unreliable snapshots; compression
	# keeps the small co-op prototype's traffic bounded. Objects are never decoded.
	var raw := packet.decompress_dynamic(1048576, FileAccess.COMPRESSION_DEFLATE)
	if raw.is_empty():
		return
	var state: Variant = bytes_to_var(raw)
	if not state is Array or state.size() != 5:
		return
	players = state[0]
	monsters.assign(state[1])
	projectiles.assign(state[2])
	zones.assign(state[3])
	effects.assign(state[4])


func _host() -> void:
	_close_connection()
	_reset_world()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(PORT, 8)
	if error != OK:
		status_label.text = "Não foi possível hospedar (erro %s)." % error
		return
	multiplayer.multiplayer_peer = peer
	status_label.text = "Hospedando • UDP %s • até 8 convidados" % PORT
	print("SERVER_READY: UDP %s" % PORT)

func _join() -> void:
	_close_connection()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(address.text.strip_edges(), PORT)
	if error != OK:
		status_label.text = "Endereço inválido (erro %s)." % error
		return
	players.clear()
	monsters.clear()
	connection_elapsed = 0.0
	multiplayer.multiplayer_peer = peer
	status_label.text = "Conectando…"

func _close_connection() -> void:
	if multiplayer.has_multiplayer_peer():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _connected() -> void:
	if smoke_client:
		choose_class(1)
		equip_item("weapon","training_staff")
	status_label.text = "Conectado • jogador %s" % multiplayer.get_unique_id()

func _peer_connected(id: int) -> void:
	if multiplayer.is_server():
		players[id] = _new_player()

func _peer_disconnected(id: int) -> void:
	players.erase(id)
	commands.erase(id)

func _connection_failed() -> void:
	_close_connection()
	_reset_world()
	status_label.text = "Conexão falhou. Modo solo restaurado. Confira IP e UDP 24567."

func _server_disconnected() -> void:
	_connection_failed()
	status_label.text = "Servidor desconectado. Você voltou ao modo solo."

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = preload("res://scripts/hud.gd").new()
	hud.world = self
	layer.add_child(hud)
	status_label = hud.status_label
	stats_label = hud.stats_label
	address = hud.address
	host_button = hud.host_button
	join_button = hud.join_button

func _update_labels() -> void:
	hud.refresh()


func _hero_region(row: int, frame: int) -> Rect2:
	var cell := Vector2(HERO_SHEET.get_size()) / 4.0
	return Rect2(Vector2(frame, row) * cell, cell)

func _update_animation(delta: float) -> void:
	for id in animations.keys():
		if not players.has(id):
			animations.erase(id)
	for id in players:
		var pos: Vector2 = players[id].pos
		if not animations.has(id):
			animations[id] = {"pos": pos, "row": 0, "frame": 0, "elapsed": 0.0, "distance":0.0}
		var animation: Dictionary = animations[id]
		var movement: Vector2 = pos - animation.pos
		# Interpolate animation between network snapshots without altering game state.
		if movement.length() > 0.1 and movement.length() < 100:
			if absf(movement.x) > absf(movement.y):
				animation.row = 1 if movement.x < 0 else 2
			else:
				animation.row = 3 if movement.y < 0 else 0
			animation.elapsed = 0.12
			animation.distance += movement.length()
		else:
			animation.elapsed = maxf(0, animation.elapsed - delta)
		animation.frame = (int(animation.distance / 12) % 4) if animation.elapsed > 0 and players[id].hp > 0 else 0
		animation.pos = pos


func _smoke_check(delta: float) -> void:
	if not smoke_client and not smoke_host:
		return
	smoke_elapsed += delta
	if smoke_client and players.has(multiplayer.get_unique_id()):
		var mine: Dictionary = players[multiplayer.get_unique_id()]
		if mine.cds[1] > 0:
			smoke_special_confirmed = true
		if not smoke_special_sent and mine.class_id == 1 and mine.pos.x > 390:
			use_skill(1)
			smoke_special_sent = true
		if not smoke_portal_sent and mine.pos.distance_to(Realm.PORTALS[0].pos) < 38:
			interact()
			smoke_portal_sent = true
	if smoke_client and smoke_elapsed > 2 and players.has(multiplayer.get_unique_id()):
		var p: Dictionary = players[multiplayer.get_unique_id()]
		if p.pos.x > SPAWN.x + 80 and monsters.size() >= 17 and p.cds.size() == 5 and p.progress.has("golem") and p.class_id == 1 and Realm.area_at(p.pos) == 1 and p.equipped.weapon == "training_staff" and smoke_special_confirmed:
			print("NETWORK_CLIENT_PASS: movement, class skill, equipment, regional portal travel, boss states and ten quests synchronized")
			get_tree().quit(0)
	if smoke_host and smoke_attack_received and smoke_special_received and smoke_equip_received and smoke_portal_received:
		print("NETWORK_HOST_PASS: remote combat input accepted")
		smoke_host = false
	if smoke_client and smoke_elapsed > 12:
		push_error("NETWORK_CLIENT_FAIL: no authoritative state")
		get_tree().quit(1)

func equip_item(slot: String, item_id: String) -> void:
	if _is_authority():
		Expansion.equip(self, 1, slot, item_id)
	else:
		_request_equip.rpc_id(1, slot, item_id)

@rpc("any_peer", "call_remote", "reliable")
func _request_equip(slot: String, item_id: String) -> void:
	if multiplayer.is_server():
		if Expansion.equip(self,multiplayer.get_remote_sender_id(),slot,item_id):
			smoke_equip_received = true

func player_display_pos(id: int) -> Vector2:
	return render_players.get(id, players[id].pos)

func enemy_display_pos(id: int) -> Vector2:
	return render_enemies.get(id, monsters[id].pos)

func _update_presentation(delta: float) -> void:
	for id in render_players.keys():
		if not players.has(id):
			render_players.erase(id)
	for id in players:
		var target: Vector2 = players[id].pos
		var before: Vector2 = render_players.get(id, target)
		render_players[id] = target if before.distance_to(target) > 200 else before.lerp(target, 1 - exp(-18 * delta))
	for i in range(monsters.size()):
		var target: Vector2 = monsters[i].pos
		var before: Vector2 = render_enemies.get(i, target)
		render_enemies[i] = target if before.distance_to(target) > 200 else before.lerp(target, 1 - exp(-15 * delta))
	var shot_ids: Array = []
	for shot in projectiles:
		shot_ids.append(shot.id)
		var target: Vector2 = shot.pos
		var before: Vector2 = render_projectiles.get(shot.id,target)
		render_projectiles[shot.id] = before.lerp(target,1-exp(-22*delta))
	for id in render_projectiles.keys():
		if not shot_ids.has(id):
			render_projectiles.erase(id)
	var local_id := multiplayer.get_unique_id()
	if players.has(local_id):
		var area := Realm.area_at(players[local_id].pos)
		if area < 0:
			return
		var bounds: Rect2 = Realm.AREAS[area].rect
		var target: Vector2 = player_display_pos(local_id)
		target.x = clampf(target.x, bounds.position.x + 576, bounds.end.x - 576)
		target.y = clampf(target.y, bounds.position.y + 360, bounds.end.y - 360) if bounds.size.y >= 720 else 360
		camera.position = target if not camera_initialized or camera.position.distance_to(target) > 800 else camera.position.lerp(target, 1 - exp(-10 * delta))
		camera_initialized = true
		camera.force_update_scroll()
