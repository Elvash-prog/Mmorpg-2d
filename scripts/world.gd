extends Node2D
## Small server-authoritative arena with AI-generated art and local animation.

const HERO_SHEET = preload("res://assets/guardian.png")
const MAP_TEXTURE = preload("res://assets/village.png")
const PORT := 24567
const SPEED := 165.0
const ARENA := Rect2(16, 112, 1120, 490)
const SPAWN := Vector2(300, 318)
var animations: Dictionary = {}
var players: Dictionary = {}
var monsters: Array[Dictionary] = []
var commands: Dictionary = {}
var touch_direction := Vector2.ZERO
var touch_attack := false
var send_elapsed := 0.0
var attack_flash := 0.0
var connection_elapsed := 0.0
var status_label: Label
var stats_label: Label
var address: LineEdit
var host_button: Button
var join_button: Button
var hud: Control
var smoke_client := false
var smoke_host := false
var smoke_elapsed := 0.0
var smoke_attack_received := false

func _ready() -> void:
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

func _reset_world() -> void:
	animations.clear()
	players.clear()
	commands.clear()
	players[1] = _new_player()
	monsters.clear()
	for i in range(5):
		var pos := Vector2(620 + (i % 3) * 130, 240 + (i / 3) * 190)
		monsters.append({"pos": pos, "home": pos, "hp": 40, "timer": 0.0, "cooldown": 0.0})

func _new_player() -> Dictionary:
	return {"pos": SPAWN, "hp": 100, "xp": 0, "kills": 0, "cooldown": 0.0, "respawn": 0.0, "swing": 0.0}

func _process(delta: float) -> void:
	var direction := _keyboard_direction() + touch_direction
	var attack := Input.is_physical_key_pressed(KEY_SPACE) or Input.is_physical_key_pressed(KEY_1) or touch_attack
	if address.has_focus():
		direction = touch_direction
		attack = touch_attack
	if smoke_client:
		direction = Vector2.RIGHT
		attack = true
	if _is_authority():
		commands[1] = {"direction": direction.limit_length(), "attack": attack}
		_simulate(delta)
	else:
		connection_elapsed += delta
		if multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			_submit_input.rpc_id(1, direction.limit_length(), attack)
		elif connection_elapsed > 8.0:
			_connection_failed()
	send_elapsed += delta
	if _is_authority() and multiplayer.has_multiplayer_peer() and send_elapsed >= 0.05:
		send_elapsed = 0.0
		_receive_state.rpc(players, monsters)
	attack_flash = maxf(0.0, attack_flash - delta)
	_update_animation(delta)
	_update_labels()
	queue_redraw()
	_smoke_check(delta)

func _keyboard_direction() -> Vector2:
	return Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))

func _is_authority() -> bool:
	return not multiplayer.has_multiplayer_peer() or multiplayer.is_server()

func _simulate(delta: float) -> void:
	for id in players:
		var p: Dictionary = players[id]
		p.cooldown = maxf(0.0, p.cooldown - delta)
		p.swing = maxf(0.0, p.swing - delta)
		if p.hp <= 0:
			p.respawn -= delta
			if p.respawn <= 0:
				p.hp = 100
				p.pos = SPAWN
			continue
		var cmd: Dictionary = commands.get(id, {"direction": Vector2.ZERO, "attack": false})
		p.pos += cmd.direction * SPEED * delta
		p.pos = Vector2(clampf(p.pos.x, ARENA.position.x + 16, ARENA.end.x - 16), clampf(p.pos.y, ARENA.position.y + 16, ARENA.end.y - 16))
		if cmd.attack and p.cooldown <= 0:
			p.cooldown = 0.45
			p.swing = 0.18
			for monster in monsters:
				if monster.hp > 0 and p.pos.distance_to(monster.pos) < 76:
					monster.hp = maxi(0, monster.hp - 20)
					if monster.hp == 0:
						monster.timer = 5.0
						p.xp += 25
						p.kills += 1
		# The village fountain restores health.
		if p.pos.distance_to(SPAWN) < 65:
			p.hp = minf(100.0, p.hp + delta * 12)
	for monster in monsters:
		if monster.hp <= 0:
			monster.timer -= delta
			if monster.timer <= 0:
				monster.hp = 40
				monster.pos = monster.home
			continue
		monster.cooldown = maxf(0.0, monster.cooldown - delta)
		var target := -1
		var distance := 210.0
		for id in players:
			var p: Dictionary = players[id]
			var d: float = monster.pos.distance_to(p.pos)
			if p.hp > 0 and d < distance and p.pos.distance_to(SPAWN) > 85:
				target = id
				distance = d
		if target != -1:
			var p: Dictionary = players[target]
			if distance > 29:
				monster.pos = monster.pos.move_toward(p.pos, delta * 65)
			elif monster.cooldown <= 0:
				p.hp = maxf(0.0, p.hp - 8)
				monster.cooldown = 0.8
				if p.hp <= 0:
					p.respawn = 3.0
		else:
			monster.pos = monster.pos.move_toward(monster.home, delta * 40)

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(direction: Vector2, attack: bool) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if players.has(id) and is_finite(direction.x) and is_finite(direction.y):
		commands[id] = {"direction": direction.limit_length(), "attack": attack}
		if attack:
			smoke_attack_received = true

@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_state(server_players: Dictionary, server_monsters: Array) -> void:
	players = server_players
	monsters.assign(server_monsters)

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

func _draw() -> void:
	_draw_village()

	for monster in monsters:
		if monster.hp <= 0:
			continue
		var pos: Vector2 = monster.pos
		draw_ellipse_shadow(pos)
		draw_circle(pos, 17, Color("74b540"))
		draw_circle(pos + Vector2(-4, -5), 9, Color("c7ec76"))
		draw_rect(Rect2(pos + Vector2(-7, -2), Vector2(3, 4)), Color("22342b"))
		draw_rect(Rect2(pos + Vector2(4, -2), Vector2(3, 4)), Color("22342b"))
		_health_bar(pos + Vector2(-20, -29), float(monster.hp) / 40, Color("b7d77e"))
	for id in players:
		var p: Dictionary = players[id]
		if p.hp <= 0:
			continue
		var pos: Vector2 = p.pos
		draw_ellipse_shadow(pos)
		var local: bool = id == multiplayer.get_unique_id()
		if local:
			draw_arc(pos, 24, 0, TAU, 24, Color("e7cd89"), 2)
		if p.swing > 0:
			draw_arc(pos, 70, -PI * 0.8, PI * 0.8, 24, Color("f9e5ac"), 4)
		var animation: Dictionary = animations.get(id, {"row": 0, "frame": 0})
		var region := _hero_region(animation.row, animation.frame)
		var tint := Color.WHITE if local else Color(0.85, 0.85, 1.0)
		draw_texture_rect_region(HERO_SHEET, Rect2(pos + Vector2(-38, -60), Vector2(76, 76)), region, tint)
		_health_bar(pos + Vector2(-20, -60), float(p.hp) / 100, Color("79c7ba"))
		var caption := "Guardião" if local else "Viajante %s" % str(id).right(3)
		_world_text(caption, pos + Vector2(-32, -68), Color("fff0ad"))

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
			animations[id] = {"pos": pos, "row": 0, "frame": 0, "elapsed": 0.0}
		var animation: Dictionary = animations[id]
		var movement: Vector2 = pos - animation.pos
		# Interpolate animation between network snapshots without altering game state.
		if movement.length() > 0.1 and movement.length() < 100:
			if absf(movement.x) > absf(movement.y):
				animation.row = 1 if movement.x < 0 else 2
			else:
				animation.row = 3 if movement.y < 0 else 0
			animation.elapsed = 0.12
		else:
			animation.elapsed = maxf(0, animation.elapsed - delta)
		animation.frame = (int(Time.get_ticks_msec() / 125) % 4) if animation.elapsed > 0 and players[id].hp > 0 else 0
		animation.pos = pos


func _draw_village() -> void:
	draw_texture_rect(MAP_TEXTURE, Rect2(0, 0, 1152, 636), false)
	# The healing fountain is drawn over the empty plaza in the generated map.
	draw_circle(SPAWN + Vector2(0, 7), 29, Color("5b685b"))
	draw_circle(SPAWN, 27, Color("c9cba5"))
	draw_circle(SPAWN, 21, Color("368f9c"))
	draw_circle(SPAWN + Vector2(-2, -3), 16, Color("6ed4ca"))
	draw_rect(Rect2(SPAWN + Vector2(-5, -19), Vector2(10, 23)), Color("dce0bb"))
	_world_text("Fonte da Aurora", SPAWN + Vector2(-55, -94), Color("fff3bd"))
	_world_text("Bosque dos limos", Vector2(720, 120), Color("f3edbc"))

func _world_text(text: String, pos: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("293a2c"))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)

func draw_ellipse_shadow(pos: Vector2) -> void:
	draw_set_transform(pos + Vector2(0, 16), 0, Vector2(1, 0.35))
	draw_circle(Vector2.ZERO, 19, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO)

func _health_bar(pos: Vector2, ratio: float, color: Color) -> void:
	draw_rect(Rect2(pos, Vector2(40, 5)), Color("17232e"))
	draw_rect(Rect2(pos, Vector2(40 * ratio, 5)), color)

func _smoke_check(delta: float) -> void:
	if not smoke_client and not smoke_host:
		return
	smoke_elapsed += delta
	if smoke_client and smoke_elapsed > 2 and players.has(multiplayer.get_unique_id()):
		var p: Dictionary = players[multiplayer.get_unique_id()]
		if p.pos.x > SPAWN.x + 80 and monsters.size() == 5:
			print("NETWORK_CLIENT_PASS: authoritative movement and monster snapshots received")
			get_tree().quit(0)
	if smoke_host and smoke_attack_received:
		print("NETWORK_HOST_PASS: remote attack input accepted")
		smoke_host = false
	if smoke_client and smoke_elapsed > 12:
		push_error("NETWORK_CLIENT_FAIL: no authoritative movement")
		get_tree().quit(1)
