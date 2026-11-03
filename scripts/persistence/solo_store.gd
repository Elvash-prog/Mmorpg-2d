extends RefCounted
## Local JSON journal with two committed generations; no Godot objects are decoded.
const FORMAT := "aurora.solo"
const VERSION := 1
const MAX_BYTES := 262144
const MAX_VALUE := 2000000000
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Maps = preload("res://scripts/maps/map_registry.gd")
var path: String
var expected_sequence := -1

func _init(primary_path := "user://saves/solo.json") -> void:
	path = primary_path

func slot_paths() -> Array[String]:
	return [path,path.get_basename()+".backup.json"]

func encode_player(p: Dictionary) -> Dictionary:
	var class_entry: Resource = Data.CATALOG.records("class")[p.class_id]
	var area := maxi(0,Realm.area_at(p.pos))
	var items: Array = []
	for item in p.inventory:
		items.append("item."+item)
	var gear := {}
	for slot in Realm.SLOTS:
		gear[slot] = "item."+p.equipped[slot] if p.equipped[slot] != "" else ""
	var progress := {}
	for quest in Data.QUESTS:
		progress[String(quest.id)] = int(p.progress[quest.key])
	var claimed: Array = []
	for index in p.claimed:
		claimed.append(String(Data.QUESTS[index].id))
	var picked: Array = []
	var herbs := Maps.objects("herb")
	for index in p.picked:
		picked.append(String(herbs[index].id))
	var opened: Array = []
	for index in p.opened:
		opened.append(String(Realm.CHESTS[index].id))
	return {"class_id":String(class_entry.id),"area_id":String(Realm.AREAS[area].id),"xp":p.xp,"gold":p.gold,"kills":p.kills,"inventory":items,"equipped":gear,"progress":progress,"claimed":claimed,"picked":picked,"opened":opened}

func validate_character(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key in ["class_id","area_id","xp","gold","kills","inventory","equipped","progress","claimed","picked","opened"]:
		if not value.has(key):
			return false
	if not value.class_id is String or not value.area_id is String:
		return false
	var actor_class: Resource = Data.CATALOG.find(StringName(value.class_id))
	if actor_class == null or actor_class.category != "class":
		return false
	if not Realm.AREAS.any(func(a):return String(a.id)==value.area_id):
		return false
	for key in ["xp","gold","kills"]:
		if not _integer(value[key],MAX_VALUE):
			return false
	if not value.inventory is Array or value.inventory.size()>Realm.ITEMS.size() or not value.equipped is Dictionary or not value.progress is Dictionary:
		return false
	var seen := {}
	for id in value.inventory:
		if not id is String or not id.begins_with("item.") or not Realm.ITEMS.has(id.trim_prefix("item.")) or seen.has(id):
			return false
		seen[id] = true
	for slot in Realm.SLOTS:
		var item_id: Variant = value.equipped.get(slot)
		if not item_id is String:
			return false
		if item_id == "":
			continue
		if not value.inventory.has(item_id):
			return false
		var item: Dictionary = Realm.ITEMS[item_id.trim_prefix("item.")]
		if item.slot != slot or (item["class"]>=0 and item["class"]!=actor_class.data.index):
			return false
	if value.progress.size()!=Data.QUESTS.size():
		return false
	for quest in Data.QUESTS:
		if not _integer(value.progress.get(String(quest.id)),MAX_VALUE):
			return false
	var quest_ids: Array = Data.QUESTS.map(func(q):return String(q.id))
	if not _id_list(value.claimed,quest_ids):
		return false
	for id in value.claimed:
		var quest: Dictionary = Data.QUESTS[quest_ids.find(id)]
		if value.progress[id]<quest.goal or (quest.has("requires") and not value.claimed.has(quest_ids[quest.requires])):
			return false
	if not _id_list(value.picked,Maps.objects("herb").map(func(o):return String(o.id))):
		return false
	return _id_list(value.opened,Realm.CHESTS.map(func(o):return String(o.id)))

func restore_player(world: Node,character: Dictionary) -> Dictionary:
	var actor_class: Resource = Data.CATALOG.find(StringName(character.class_id))
	var p: Dictionary = world._new_player(actor_class.data.index)
	p.xp = int(character.xp)
	p.gold = int(character.gold)
	p.kills = int(character.kills)
	p.inventory = character.inventory.map(func(id):return String(id).trim_prefix("item."))
	for slot in Realm.SLOTS:
		p.equipped[slot] = String(character.equipped[slot]).trim_prefix("item.")
	for quest in Data.QUESTS:
		p.progress[quest.key] = int(character.progress[String(quest.id)])
	var quest_ids: Array = Data.QUESTS.map(func(q):return String(q.id))
	p.claimed = character.claimed.map(func(id):return quest_ids.find(id))
	var herb_ids: Array = Maps.objects("herb").map(func(o):return String(o.id))
	p.picked = character.picked.map(func(id):return herb_ids.find(id))
	var chest_ids: Array = Realm.CHESTS.map(func(o):return String(o.id))
	p.opened = character.opened.map(func(id):return chest_ids.find(id))
	world.Expansion.recalculate(p)
	p.hp = p.max_hp
	p.mana = p.max_mana
	# World encounters reset on load; continue from a safe regional camp.
	var area: int = Realm.AREAS.find(Realm.AREAS.filter(func(a):return String(a.id)==character.area_id)[0])
	p.pos = world.SPAWN if area==0 else Realm.NPCS.filter(func(n):return n.area==area)[0].pos+Vector2(40,30)
	if world.Map.blocked(p.pos):
		p.pos = world.SPAWN
	p.message = "Aventura carregada. Você voltou ao acampamento com seu progresso."
	return p

func load_latest() -> Dictionary:
	var result := _scan()
	expected_sequence = result.get("sequence",0)
	return result

func _scan() -> Dictionary:
	var best := {"ok":false,"found":false,"reason":"missing","sequence":0,"corrupt":false}
	for slot in slot_paths():
		if not FileAccess.file_exists(slot):
			continue
		best.found = true
		var candidate := _read(slot)
		if candidate.get("unsupported",false):
			return {"ok":false,"found":true,"reason":"unsupported_version","sequence":0}
		if candidate.ok and candidate.sequence>best.sequence:
			var corrupt: bool = best.corrupt
			best = candidate
			best.found = true
			best.corrupt = corrupt
		elif not candidate.ok:
			best.corrupt = true
	if best.ok:
		best.recovered = best.corrupt
	elif best.found:
		best.reason = "invalid_data"
	return best

func _read(slot: String) -> Dictionary:
	var file := FileAccess.open(slot,FileAccess.READ)
	if file == null or file.get_length()>MAX_BYTES:
		return {"ok":false}
	var parser := JSON.new()
	if parser.parse(file.get_as_text())!=OK or not parser.data is Dictionary:
		return {"ok":false}
	var document: Dictionary = parser.data
	if document.get("format")!=FORMAT or not _integer(document.get("version"),100000):
		return {"ok":false}
	if document.version>VERSION:
		return {"ok":false,"unsupported":true}
	if document.version!=VERSION or not _integer(document.get("sequence"),MAX_VALUE) or document.sequence<1 or not document.get("payload") is String or not document.get("checksum") is String:
		return {"ok":false}
	if document.payload.sha256_text()!=document.checksum:
		return {"ok":false}
	if parser.parse(document.payload)!=OK or not validate_character(parser.data):
		return {"ok":false}
	return {"ok":true,"sequence":int(document.sequence),"character":parser.data,"slot":slot}

func save(character: Dictionary) -> Dictionary:
	if not validate_character(character):
		return {"ok":false,"reason":"invalid_character"}
	var latest := _scan()
	if latest.found and not latest.ok:
		return {"ok":false,"reason":latest.reason}
	if expected_sequence>=0 and latest.sequence!=expected_sequence:
		return {"ok":false,"reason":"concurrent_change"}
	var target: String = slot_paths()[1] if latest.get("slot","")==path else path
	var parent := ProjectSettings.globalize_path(target.get_base_dir())
	if DirAccess.make_dir_recursive_absolute(parent)!=OK:
		return {"ok":false,"reason":"directory_failed"}
	var sequence: int = latest.sequence+1
	var payload := JSON.stringify(character)
	var text := JSON.stringify({"format":FORMAT,"version":VERSION,"sequence":sequence,"saved_at":int(Time.get_unix_time_from_system()),"payload":payload,"checksum":payload.sha256_text()})
	if text.to_utf8_buffer().size()>MAX_BYTES:
		return {"ok":false,"reason":"too_large"}
	var temporary := target+".tmp"
	var file := FileAccess.open(temporary,FileAccess.WRITE)
	if file == null:
		return {"ok":false,"reason":"write_failed"}
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or not _read(temporary).ok:
		return {"ok":false,"reason":"verification_failed"}
	# Remove only the inactive generation; the latest valid slot stays intact.
	if FileAccess.file_exists(target) and DirAccess.remove_absolute(ProjectSettings.globalize_path(target))!=OK:
		return {"ok":false,"reason":"replace_failed"}
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),ProjectSettings.globalize_path(target))!=OK:
		return {"ok":false,"reason":"rename_failed"}
	expected_sequence = sequence
	return {"ok":true,"sequence":sequence}

func archive_and_clear() -> Dictionary:
	var directory := ProjectSettings.globalize_path(path.get_base_dir().path_join("archives"))
	if DirAccess.make_dir_recursive_absolute(directory)!=OK:
		return {"ok":false,"reason":"archive_failed"}
	var stamp := str(int(Time.get_unix_time_from_system()))+"-"+str(Time.get_ticks_usec())
	var copies: Array[Dictionary] = []
	for slot in slot_paths()+[path+".tmp",slot_paths()[1]+".tmp"]:
		if not FileAccess.file_exists(slot):
			continue
		var original := ProjectSettings.globalize_path(slot)
		var destination := directory.path_join(stamp+"-"+slot.get_file())
		if DirAccess.copy_absolute(original,destination)!=OK or FileAccess.get_sha256(original)!=FileAccess.get_sha256(destination):
			return {"ok":false,"reason":"archive_failed"}
		copies.append({"original":original,"archive":destination})
	var removed: Array[Dictionary] = []
	for copy in copies:
		if DirAccess.remove_absolute(copy.original)!=OK:
			for previous in removed:
				DirAccess.copy_absolute(previous.archive,previous.original)
			return {"ok":false,"reason":"archive_cleanup_failed"}
		removed.append(copy)
	expected_sequence = 0
	return {"ok":true,"archived":copies.size()}

static func _integer(value: Variant,maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=0 and float(value)<=maximum and floor(float(value))==float(value)

static func _id_list(value: Variant,allowed: Array) -> bool:
	if not value is Array or value.size()>allowed.size():
		return false
	var seen := {}
	for id in value:
		if not id is String or not allowed.has(id) or seen.has(id):
			return false
		seen[id] = true
	return true
