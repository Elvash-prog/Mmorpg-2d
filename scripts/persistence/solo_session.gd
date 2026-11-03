extends RefCounted
const Store = preload("res://scripts/persistence/solo_store.gd")
var world: Node
var store: RefCounted
var enabled := false
var active := false
var read_only := false
var elapsed := 0.0
var last_signature := ""
var status := "Salvamento solo desativado nesta sessão."
var last_saved := 0

func _init(context: Node) -> void:
	world = context
	store = Store.new()

func start(custom_store: RefCounted = null) -> void:
	if custom_store != null:
		store = custom_store
	enabled = true
	resume()

func resume() -> void:
	if not enabled:
		return
	active = true
	elapsed = 0
	var loaded: Dictionary = store.load_latest()
	read_only = loaded.found and not loaded.ok
	if loaded.ok:
		world.players[1] = store.restore_player(world,loaded.character)
		last_signature = JSON.stringify(store.encode_player(world.players[1]))
		status = "Progresso recuperado da cópia de segurança." if loaded.get("recovered",false) else "Aventura carregada. Salvamento automático ativo."
	elif read_only:
		status = "Não foi possível carregar este perfil. Arquivos preservados; use Nova aventura para arquivá-los."
	else:
		last_signature = ""
		status = "Nova aventura. Salvamento automático a cada 5 segundos."
	world.status_label.text = status

func is_solo() -> bool:
	return active and world.multiplayer.multiplayer_peer is OfflineMultiplayerPeer and world.players.has(1)

func tick(delta: float) -> void:
	if not is_solo() or read_only:
		return
	elapsed += delta
	if elapsed>=5:
		elapsed = 0
		save_now(false)

func save_now(force := true) -> bool:
	if not is_solo() or read_only:
		return false
	var character: Dictionary = store.encode_player(world.players[1])
	var signature := JSON.stringify(character)
	if not force and signature == last_signature:
		return true
	var result: Dictionary = store.save(character)
	if not result.ok:
		status = "Não foi possível salvar. O progresso anterior foi preservado."
		world.status_label.text = status
		if result.reason in ["concurrent_change","unsupported_version","invalid_data"]:
			read_only = true
		world._message(world.players[1],status)
		return false
	last_signature = signature
	last_saved = int(Time.get_unix_time_from_system())
	status = "Aventura salva neste dispositivo."
	world.status_label.text = status
	if force:
		world._message(world.players[1],status)
	return true

func suspend() -> bool:
	if is_solo() and not read_only and not save_now():
		return false
	active = false
	status = "Partida em rede: o perfil solo permanece separado."
	return true

func new_adventure() -> bool:
	if not is_solo():
		return false
	if not read_only and not save_now():
		return false
	var archived: Dictionary = store.archive_and_clear()
	if not archived.ok:
		status = "Não foi possível arquivar o progresso. A aventura atual foi mantida."
		world._message(world.players[1],status)
		return false
	var previous: Dictionary = world.players[1].duplicate(true)
	world._reset_world()
	read_only = false
	last_signature = ""
	if not save_now():
		world.players[1] = previous
		read_only = true
		status = "Falha ao iniciar a nova aventura. O progresso anterior está arquivado e foi mantido na sessão."
		return false
	world.hud.close_modals()
	world._message(world.players[1],"Nova aventura iniciada. A anterior foi arquivada neste dispositivo.")
	return true
