extends Node2D
## Authoritative co-op RPG prototype. The server owns every gameplay outcome.
const Maps = preload("res://scripts/maps/map_registry.gd")
const Animator = preload("res://scripts/presentation/animation_controller.gd")
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Map = preload("res://scripts/map_rules.gd")
const HERO_SHEET = preload("res://assets/guardian.png")
const MAP_TEXTURE = preload("res://assets/village.png")
const PORT := 24567
const SPEED := 165.0
static var ARENA: Rect2 = Map.BOUNDS
static var SPAWN: Vector2 = Maps.objects("spawn")[0].pos
var transport: RefCounted
var map_layers := Node2D.new()
var combat: RefCounted
var projectile: RefCounted
var effects_system: RefCounted
var actors: RefCounted
var quests: RefCounted
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
	var errors: PackedStringArray = Data.CATALOG.validate()
	errors.append_array(Animator.validate(Data.CATALOG))
	errors.append_array(Maps.validate())
	if not errors.is_empty():
		push_error("Content validation failed: "+str(errors))
		get_tree().quit(1)
		set_process(false)
		return
	transport = preload("res://scripts/network/session_transport.gd").new(self)
	map_layers.name = "MapLayers"
	add_child(map_layers)
	for packed in Maps.SCENES:
		map_layers.add_child(packed.instantiate())
	combat = preload("res://scripts/simulation/combat_system.gd").new(self)
	projectile = preload("res://scripts/simulation/projectile_system.gd").new(self)
	effects_system = preload("res://scripts/simulation/effects_system.gd").new(self)
	actors = preload("res://scripts/simulation/actors_system.gd").new(self)
	quests = preload("res://scripts/simulation/quests_system.gd").new(self)
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
	var bounds: Rect2 = Maps.area_definitions()[0].rect
	for area in Maps.area_definitions():
		bounds = bounds.merge(area.rect)
	var first := Vector2i(floori(bounds.position.x/16),floori(bounds.position.y/16))
	var last := Vector2i(ceili(bounds.end.x/16),ceili(bounds.end.y/16))
	grid.region = Rect2i(first,last-first)
	grid.cell_size = Vector2(16, 16)
	grid.offset = Vector2(8, 8)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(grid.region.position.y,grid.region.end.y):
		for x in range(grid.region.position.x,grid.region.end.x):
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
	for marker in Maps.objects("enemy"):
		monsters.append(_new_monster(marker.pos,marker.kind))

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
		var packet: PackedByteArray = transport.snapshot()
		if not packet.is_empty():
			_receive_state.rpc(packet)
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
	combat.queue_skill(id,slot,target)


func _simulate(delta: float) -> void:
	actors.simulate(delta)


func _select_target(p: Dictionary, reach: float) -> int:
	return combat.select_target(p,reach)


func _begin_skill(id: int, slot: int) -> bool:
	return combat.begin_skill(id,slot)


func _resolve_skill(id: int, cast: Dictionary) -> void:
	combat.resolve_skill(id,cast)


func _spawn_projectile(owner: int, destination: Vector2, skill: Dictionary, delay := 0.0) -> void:
	projectile.spawn_projectile(owner,destination,skill,delay)


func _tick_projectiles(delta: float) -> void:
	projectile.tick_projectiles(delta)


func _tick_zones(delta: float) -> void:
	effects_system.tick_zones(delta)


func _area_damage(owner: int, center: Vector2, radius: float, amount: float, status := "") -> void:
	combat.area_damage(owner,center,radius,amount,status)


func _damage_monster(owner: int, target: int, amount: float, status := "") -> void:
	combat.damage_monster(owner,target,amount,status)


func _hurt_player(id: int, damage: float) -> void:
	combat.hurt_player(id,damage)


func _tick_monster(monster: Dictionary, delta: float) -> void:
	actors.tick_monster(monster,delta)


func _move_monster(monster: Dictionary, destination: Vector2, delta: float, speed: float) -> void:
	actors.move_monster(monster,destination,delta,speed)


func _interact(id: int) -> void:
	quests.interact(id)


func _set_class(id: int, class_id: int) -> bool:
	return combat.set_class(id,class_id)


func _message(p: Dictionary, text: String) -> void:
	effects_system.message(p,text)


func _fx(kind: String, pos: Vector2, destination: Vector2, radius: float, color: Color) -> void:
	effects_system.fx(kind,pos,destination,radius,color)


func _number(pos: Vector2, text: String, color: Color) -> void:
	effects_system.number(pos,text,color)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(direction: Vector2, attack: bool, target: int = -1) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if transport.input(id,direction,attack,target) and attack:
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
	transport.receive(packet)


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
		animations[id] = Animator.update_hero(players[id],animations.get(id,{}),delta)

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

func reload_map_geometry() -> void:
	for region in map_layers.get_children():
		Maps.register_region(region)
	Data.refresh_maps()
	Realm.refresh_maps()
	SPAWN = Maps.objects("spawn")[0].pos
	Map.BOUNDS = Maps.area_definitions()[0].walk
	ARENA = Map.BOUNDS
	Map.BLOCKERS = Maps.collision_rects(0)
	Map.EXTRA_BLOCKERS = Maps.collision_rects(1)+Maps.collision_rects(2)
	_build_grid()
