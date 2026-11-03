extends Node2D
## Small server-authoritative arena. All artwork is drawn locally.

const PORT := 24567
const SPEED := 165.0
const ARENA := Rect2(16, 112, 1120, 490)
const SPAWN := Vector2(300, 340)
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
		draw_rect(Rect2(pos + Vector2(-10, -5), Vector2(20, 23)), Color("5c91b3") if local else Color("b18cbb"))
		draw_rect(Rect2(pos + Vector2(-7, -21), Vector2(14, 15)), Color("e5bb8b"))
		draw_rect(Rect2(pos + Vector2(-9, -23), Vector2(18, 6)), Color("384454"))
		draw_line(pos + Vector2(15, 12), pos + Vector2(20, -13), Color("d5e5e5"), 4)
		_health_bar(pos + Vector2(-20, -36), float(p.hp) / 100, Color("79c7ba"))
		var caption := "Guardião" if local else "Viajante %s" % str(id).right(3)
		_world_text(caption, pos + Vector2(-32, -44), Color("fff0ad"))

func _draw_village() -> void:
	draw_rect(Rect2(0, 0, 1152, 636), Color("89ad4b"))
	for y in range(8, 632, 16):
		for x in range(8, 1152, 16):
			var n := (x * 17 + y * 31) % 23
			if n < 10:
				draw_rect(Rect2(x, y, 7, 3), Color("9cbb55") if n < 5 else Color("7b9e43"))
	# A stone promenade crosses the village.
	for y in range(112, 604, 30):
		for x in range(250, 370, 30):
			_stone(Vector2(x, y), Vector2(28, 28))
	for y in range(310, 370, 30):
		for x in range(130, 1130, 30):
			_stone(Vector2(x, y), Vector2(28, 28))
	# Water and banks are original procedural scenery.
	draw_rect(Rect2(40, 140, 90, 410), Color("c8bc81"))
	draw_rect(Rect2(48, 148, 74, 394), Color("3ca6b0"))
	for y in range(154, 540, 20):
		draw_rect(Rect2(52 + y % 27, y, 23, 3), Color("8ae1d1"))
	for x in range(36, 136, 16):
		draw_rect(Rect2(x, 310, 14, 60), Color("8d6742"))
		draw_line(Vector2(x, 312), Vector2(x + 12, 312), Color("cfac6a"), 3)
	_draw_house(Vector2(395, 180))
	for pos in [Vector2(176, 215), Vector2(170, 488), Vector2(1020, 204), Vector2(1040, 510), Vector2(465, 520), Vector2(900, 530)]:
		_draw_tree(pos)
	for pos in [Vector2(205, 420), Vector2(530, 170), Vector2(950, 410), Vector2(780, 560)]:
		draw_rect(Rect2(pos, Vector2(14, 9)), Color("9b987b"))
		draw_rect(Rect2(pos + Vector2(2, -4), Vector2(9, 5)), Color("ddd5aa"))
	for pos in [Vector2(220, 260), Vector2(420, 430), Vector2(955, 225), Vector2(560, 495), Vector2(810, 160)]:
		for i in range(4):
			var f: Vector2 = pos + Vector2(i * 7, (i % 2) * 8)
			draw_rect(Rect2(f, Vector2(3, 8)), Color("536c35"))
			draw_rect(Rect2(f + Vector2(-2, -2), Vector2(7, 4)), Color("f4dfa0") if i % 2 == 0 else Color("d68a9a"))
	draw_circle(SPAWN + Vector2(0, 10), 36, Color("6c7a66"))
	draw_circle(SPAWN, 31, Color("d6cc9d"))
	draw_circle(SPAWN, 24, Color("419caa"))
	draw_circle(SPAWN + Vector2(-4, -4), 17, Color("80d9cf"))
	draw_rect(Rect2(SPAWN + Vector2(-6, -20), Vector2(12, 24)), Color("e7dfb6"))
	_world_text("Fonte da Aurora", SPAWN + Vector2(-55, -70), Color("fff3bd"))
	_world_text("Bosque dos limos", Vector2(720, 120), Color("f3edbc"))

func _stone(pos: Vector2, dimensions: Vector2) -> void:
	draw_rect(Rect2(pos, dimensions), Color("9d9b80"))
	draw_rect(Rect2(pos, dimensions - Vector2(2, 3)), Color("d0c8a4"))
	draw_line(pos + Vector2(2, 2), pos + Vector2(dimensions.x - 3, 2), Color("e6dfbf"), 2)

func _draw_tree(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-23, 5), Vector2(52, 16)), Color(0.16, 0.24, 0.13, 0.25))
	draw_rect(Rect2(pos + Vector2(-7, -12), Vector2(14, 33)), Color("725134"))
	draw_rect(Rect2(pos + Vector2(-4, -12), Vector2(4, 30)), Color("aa8150"))
	for piece in [Rect2(-33, -45, 60, 25), Rect2(-24, -62, 47, 22), Rect2(-39, -35, 75, 18)]:
		draw_rect(Rect2(piece.position + pos + Vector2(3, 5), piece.size), Color("4a6935"))
		draw_rect(Rect2(piece.position + pos, piece.size), Color("b4bd52"))
		draw_rect(Rect2(piece.position + pos, Vector2(piece.size.x - 8, 7)), Color("d3d878"))

func _draw_house(pos: Vector2) -> void:
	draw_rect(Rect2(pos + Vector2(-5, 18), Vector2(138, 78)), Color("7e7953"))
	draw_rect(Rect2(pos, Vector2(125, 85)), Color("dac48a"))
	for y in range(0, 80, 16):
		draw_line(pos + Vector2(0, y), pos + Vector2(125, y), Color("b39b6a"), 2)
	draw_rect(Rect2(pos + Vector2(42, 34), Vector2(35, 51)), Color("554b3b"))
	draw_rect(Rect2(pos + Vector2(47, 39), Vector2(24, 46)), Color("303e37"))
	for x in [12, 90]:
		draw_rect(Rect2(pos + Vector2(x, 27), Vector2(22, 24)), Color("675741"))
		draw_rect(Rect2(pos + Vector2(x + 3, 30), Vector2(16, 16)), Color("6cbbc0"))
	for row in range(5):
		draw_rect(Rect2(pos + Vector2(-10 + row * 8, -row * 10), Vector2(145 - row * 16, 12)), Color("a9634a") if row % 2 == 0 else Color("c78355"))
	_world_text("Casa dos viajantes", pos + Vector2(-4, -58), Color("fff0b1"))

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
