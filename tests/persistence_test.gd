extends SceneTree
const Store = preload("res://scripts/persistence/solo_store.gd")
var world

func _initialize() -> void:
	call_deferred("_run")

func write_text(path: String,text: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file != null)
	file.store_string(text)
	file.close()

func _run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(not world.solo.enabled,"Test scenes must not read the real solo profile")
	for class_id in range(3):
		var candidate: Dictionary = world._new_player(class_id)
		candidate.pos = world.Realm.NPCS[1].pos
		candidate.picked = [0]
		candidate.opened = [0]
		var codec := Store.new()
		var record := codec.encode_player(candidate)
		assert(codec.validate_character(record))
		var loaded := codec.restore_player(world,record)
		assert(loaded.class_id==class_id and loaded.picked==[0] and loaded.opened==[0])
		assert(not world.Map.blocked(loaded.pos))
	var directory := "/tmp/aurora-save-test-%s-%s" % [OS.get_process_id(),Time.get_ticks_usec()]
	var store := Store.new(directory+"/solo.json")
	var p: Dictionary = world.players[1]
	p.gold = 777
	p.xp = 123
	p.progress.slime = 8
	p.claimed = [0]
	var encoded := store.encode_player(p)
	assert(store.validate_character(encoded))
	assert(store.save(encoded).ok)
	var restored: Dictionary = store.restore_player(world,store.load_latest().character)
	assert(restored.gold==777 and restored.xp==123 and restored.claimed==[0])
	assert(restored.equipped==p.equipped and restored.inventory==p.inventory)
	assert(restored.hp==restored.max_hp and restored.cds==[0.0,0.0,0.0,0.0,0.0])
	var invalid := encoded.duplicate(true)
	invalid.gold = -1
	assert(not store.save(invalid).ok)
	invalid = encoded.duplicate(true)
	invalid.inventory.append("item.missing")
	assert(not store.validate_character(invalid))
	var second := Store.new(store.path)
	assert(second.load_latest().ok)
	encoded.gold = 888
	assert(store.save(encoded).ok)
	assert(second.save(encoded).reason=="concurrent_change")
	# An interrupted write is ignored; corruption falls back to the previous generation.
	write_text(store.path+".tmp","partial")
	assert(Store.new(store.path).load_latest().character.gold==888)
	write_text(store.slot_paths()[1],"corrupt")
	var recovered := Store.new(store.path).load_latest()
	assert(recovered.ok and recovered.recovered and recovered.character.gold==777)
	store.load_latest()
	assert(store.save(encoded).ok)
	# Future versions and two damaged slots are preserved rather than overwritten.
	var future := JSON.parse_string(FileAccess.get_file_as_string(store.path)) as Dictionary
	future.version = 999
	write_text(store.path,JSON.stringify(future))
	assert(Store.new(store.path).load_latest().reason=="unsupported_version")
	assert(not Store.new(store.path).save(encoded).ok)
	write_text(store.path,"broken")
	write_text(store.slot_paths()[1],"broken")
	assert(not Store.new(store.path).load_latest().ok)
	assert(not Store.new(store.path).save(encoded).ok)
	assert(store.archive_and_clear().ok)
	assert(not store.load_latest().found)
	# Session saves only offline progress, reloads it, and archives before a new game.
	world.solo.start(store)
	world.players[1].gold = 321
	assert(world.solo.save_now())
	assert(world.solo.suspend())
	world.players[1].gold = 999
	assert(not world.solo.save_now())
	world.solo.resume()
	assert(world.players[1].gold==321)
	world.players[1].gold = 322
	world.return_to_solo()
	assert(world.players[1].gold==322)
	world.players[1].gold = 321
	world.hud.guide_panel.get_node("NewAdventure").pressed.emit()
	assert(world.hud.guide_panel.get_node("NewConfirmation").visible)
	world.hud.close_modals()
	assert(world.players[1].gold==321)
	assert(world.solo.new_adventure())
	assert(world.players[1].gold==0 and store.load_latest().character.gold==0)
	assert(DirAccess.get_files_at(directory+"/archives").size()>=3)
	world.solo.active = false
	world.queue_free()
	await process_frame
	print("PERSISTENCE_PASS: round trip, validation, backup recovery, interrupted writes, concurrent/version guards, solo isolation and archived new adventure")
	quit()
