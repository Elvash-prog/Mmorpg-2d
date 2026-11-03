@tool
extends Resource
@export var schema_version := 1
@export var entries: Array[Resource] = []

func find(id: StringName) -> Resource:
	for entry in entries:
		if entry.id == id:
			return entry
	return null

func records(category: String) -> Array[Resource]:
	var result: Array[Resource] = []
	for entry in entries:
		if entry.category == category:
			result.append(entry)
	result.sort_custom(func(a,b):return _rank(a.data.get("index",0))<_rank(b.data.get("index",0)))
	return result

func class_values(field: String) -> Array:
	var result: Array = []
	for entry in records("class"):
		result.append(entry.data.get(field))
	return result

func skill_matrix(short_names := false) -> Array:
	var result: Array = []
	for actor_class in records("class"):
		var skills: Array = records("skill").filter(func(entry):return entry.data.class_id == actor_class.id)
		skills.sort_custom(func(a,b):return _rank(a.data.get("slot",-1)) < _rank(b.data.get("slot",-1)))
		var row: Array = []
		for entry in skills:
			row.append(entry.data.short_name if short_names else entry.data.duplicate(true))
		result.append(row)
	return result

func item_table() -> Dictionary:
	var result := {}
	for entry in records("item"):
		var data: Dictionary = entry.data.duplicate(true)
		var reference: Variant = data.get("class_id",&"")
		var actor_class: Resource = find(reference) if typeof(reference) in [TYPE_STRING,TYPE_STRING_NAME] and reference != &"" else null
		data["class"] = actor_class.data.index if actor_class != null else -1
		result[String(entry.id).trim_prefix("item.")] = data
	return result

func rows(category: String) -> Array:
	var result: Array = []
	var source := records(category)
	for entry in source:
		var data: Dictionary = entry.data.duplicate(true)
		data["id"] = entry.id
		if category == "quest" and data.has("requires"):
			var dependency: Resource = find(data.requires) if typeof(data.requires) in [TYPE_STRING,TYPE_STRING_NAME] else null
			data.requires = dependency.data.index if dependency != null else -1
		result.append(data)
	return result

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if schema_version != 1:
		errors.append("Unsupported catalog schema version")
	var ids := {}
	var allowed := ["class","skill","item","quest","enemy"]
	for entry in entries:
		if entry == null or not allowed.has(entry.category):
			errors.append("Null or unsupported content category")
			continue
		var id := String(entry.id)
		if id.is_empty() or not id.begins_with(entry.category+".") or ids.has(id):
			errors.append("Missing, duplicate or invalid content ID: "+id)
		ids[id] = true
		var required: Array = {"class":["name","index","hp","mana","color"],"skill":["name","kind","class_id","slot","power","range","cost","cd","desc"],"item":["name","slot","class_id","power","armor","hp","mana","speed","crit"],"quest":["title","index","key","goal","xp","gold","text"],"enemy":["name","index","key","hp","speed","damage","reach","windup","radius","xp"]}[entry.category]
		for key in required:
			if not entry.data.has(key):
				errors.append(id+": missing "+key)
		for key in ["hp","mana","power","armor","speed","crit","range","cost","cd","goal","xp","gold","damage","reach","windup","radius"]:
			if entry.data.has(key):
				var value: Variant = entry.data[key]
				if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0:
					errors.append(id+": invalid numeric value "+key)
		if entry.category in ["class","enemy"] and _positive_number(entry.data.get("hp",0)) == false:
			errors.append(id+": health must be positive")
		if entry.category == "class" and (_positive_number(entry.data.get("mana",0)) == false or not entry.data.get("color") is Color):
			errors.append(id+": positive energy and a color are required")
		if entry.category == "skill" and _positive_number(entry.data.get("cd",0)) == false:
			errors.append(id+": cooldown must be positive")
		if entry.category == "quest" and _positive_number(entry.data.get("goal",0)) == false:
			errors.append(id+": objective count must be positive")
		if entry.category == "item":
			if not ["weapon","armor","boots","amulet"].has(entry.data.get("slot","")) or entry.data.get("crit",0)>1:
				errors.append(id+": invalid item slot or critical chance")
		if entry.category in ["skill","item"]:
			var class_id: Variant = entry.data.get("class_id",&"")
			if not typeof(class_id) in [TYPE_STRING,TYPE_STRING_NAME]:
				errors.append(id+": invalid class reference type")
				continue
			if entry.category == "skill" or class_id != &"":
				var actor_class: Resource = find(class_id)
				if actor_class == null or actor_class.category != "class":
					errors.append(id+": missing class reference")
		if entry.category == "quest" and entry.data.has("requires"):
			var dependency: Resource = find(entry.data.requires) if typeof(entry.data.requires) in [TYPE_STRING,TYPE_STRING_NAME] else null
			if dependency == null or dependency.category != "quest" or dependency.data.get("index",0)>=entry.data.get("index",0):
				errors.append(id+": missing or cyclic/out-of-order quest prerequisite")
	for category in ["class","enemy","quest"]:
		var ordered := records(category)
		for i in range(ordered.size()):
			if ordered[i].data.get("index",-1)!=i:
				errors.append(category+": indices must be contiguous and unique")
	for actor_class in records("class"):
		var slots: Array = []
		for entry in records("skill"):
			if entry.data.get("class_id",&"") == actor_class.id:
				var slot: int = _rank(entry.data.get("slot",-1))
				if slot<0 or slot>4 or slots.has(slot):
					errors.append(String(actor_class.id)+": invalid or duplicate skill slot")
				slots.append(slot)
		if slots.size()!=5:
			errors.append(String(actor_class.id)+": requires five skills")
	return errors

static func _rank(value: Variant) -> int:
	return value if value is int else -1

static func _positive_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>0
