extends Node2D
## Small server-authoritative arena. All artwork is drawn locally.

const PORT := 24567
const SPEED := 165.0
const ARENA := Rect2(48, 152, 1056, 410)
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
	var attack := Input.is_physical_key_pressed(KEY_SPACE) or touch_attack
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
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := Label.new()
	title.text = "A U R O R A   /   FRONTEIRA VIVA"
	title.position = Vector2(40, 20)
	title.add_theme_font_size_override("font_size", 26)
	title.modulate = Color("f3d998")
	root.add_child(title)
	stats_label = Label.new()
	stats_label.position = Vector2(40, 59)
	root.add_child(stats_label)
	status_label = Label.new()
	status_label.text = "Modo solo • explore e experimente o combate"
	status_label.position = Vector2(40, 94)
	root.add_child(status_label)
	address = LineEdit.new()
	address.position = Vector2(661, 30)
	address.size = Vector2(185, 42)
	address.text = "127.0.0.1"
	address.placeholder_text = "IP do anfitrião"
	root.add_child(address)
	host_button = _button(root, "Hospedar", Vector2(858, 30), Vector2(118, 42))
	host_button.pressed.connect(_host)
	join_button = _button(root, "Conectar", Vector2(986, 30), Vector2(118, 42))
	join_button.pressed.connect(_join)
	var hint := Label.new()
	hint.text = "WASD / setas: mover   •   Espaço: atacar   •   Fonte: recuperar vida\nMissão: derrote 5 limos. Aproxime-se e segure o ataque."
	hint.position = Vector2(370, 604)
	root.add_child(hint)
	_touch_button(root, "↑", Vector2(104, 582), Vector2.UP)
	_touch_button(root, "←", Vector2(40, 644), Vector2.LEFT)
	_touch_button(root, "↓", Vector2(104, 644), Vector2.DOWN)
	_touch_button(root, "→", Vector2(168, 644), Vector2.RIGHT)
	var attack := TouchScreenButton.new()
	attack.position = Vector2(1042, 648)
	attack.shape = _touch_shape(Vector2(108, 108))
	attack.pressed.connect(func(): touch_attack = true)
	attack.released.connect(func(): touch_attack = false)
	root.add_child(attack)
	var label := Label.new()
	label.text = "ATACAR"
	label.position = Vector2(1010, 636)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(label)

func _button(parent: Control, text: String, pos: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	parent.add_child(button)
	return button

func _touch_shape(dimensions: Vector2) -> RectangleShape2D:
	var shape := RectangleShape2D.new()
	shape.size = dimensions
	return shape

func _touch_button(parent: Control, text: String, pos: Vector2, direction: Vector2) -> void:
	var touch := TouchScreenButton.new()
	touch.position = pos + Vector2(28, 28)
	touch.shape = _touch_shape(Vector2(56, 56))
	touch.pressed.connect(func(): touch_direction += direction)
	touch.released.connect(func(): touch_direction -= direction)
	parent.add_child(touch)
	var label := Label.new()
	label.text = text
	label.position = pos + Vector2(21, 12)
	label.add_theme_font_size_override("font_size", 24)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _update_labels() -> void:
	var id := multiplayer.get_unique_id()
	if players.has(id):
		var p: Dictionary = players[id]
		var quest := "CONCLUÍDA!" if p.kills >= 5 else "%s / 5 limos" % p.kills
		stats_label.text = "GUARDIÃO   •   Vida %s/100   •   XP %s   •   Missão: %s" % [ceili(p.hp), p.xp, quest]
		if p.hp <= 0:
			stats_label.text += "   •   Retornando à fonte…"

func _draw() -> void:
	draw_rect(ARENA.grow(5), Color("50624e"))
	draw_rect(ARENA, Color("263e35"))
	for y in range(160, 558, 24):
		for x in range(56, 1100, 24):
			var n := (x * 13 + y * 7) % 17
			if n < 6:
				draw_line(Vector2(x, y), Vector2(x + 3, y - 4), Color("365347"), 2)
	draw_rect(Rect2(48, 320, 1056, 45), Color("75694d"))
	draw_rect(Rect2(275, 152, 45, 410), Color("75694d"))
	for pos in [Vector2(130, 215), Vector2(170, 470), Vector2(1000, 200), Vector2(1000, 490), Vector2(440, 480), Vector2(465, 205)]:
		draw_rect(Rect2(pos + Vector2(-5, 0), Vector2(10, 24)), Color("694b36"))
		draw_circle(pos, 28, Color("182e2b"))
		draw_circle(pos + Vector2(-5, -8), 22, Color("477455"))
	draw_circle(SPAWN, 56, Color(0.3, 0.8, 0.8, 0.12))
	draw_circle(SPAWN, 22, Color("9caba1"))
	draw_circle(SPAWN, 16, Color("5ab7c2"))
	draw_circle(SPAWN + Vector2(-3, -3), 7, Color("b4f1dc"))
	for monster in monsters:
		if monster.hp <= 0:
			continue
		var pos: Vector2 = monster.pos
		draw_ellipse_shadow(pos)
		draw_circle(pos, 17, Color("85b75b"))
		draw_circle(pos + Vector2(-4, -5), 9, Color("b0d17b"))
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
	for pos in [Vector2(40, 644), Vector2(104, 582), Vector2(104, 644), Vector2(168, 644)]:
		draw_style_box(_pad_style(), Rect2(pos, Vector2(56, 56)))
	draw_style_box(_pad_style(), Rect2(988, 594, 108, 108))

func _pad_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("263e46")
	style.border_color = Color("60767b")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

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
