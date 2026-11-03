extends RefCounted
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")

static func initialize_player(p: Dictionary) -> void:
	p.inventory = Realm.STARTERS.duplicate()
	p.equipped = {"weapon":Realm.STARTERS[p.class_id], "armor":"", "boots":"", "amulet":""}
	p.opened = []
	p.velocity = Vector2.ZERO
	p.dialogue_seq = 0
	p.dialogue_chapter = 0
	for key in ["forest_beacon", "ruins_beacon", "boss_forest", "boss_ruins", "restore"]:
		p.progress[key] = 0
	recalculate(p)

static func recalculate(p: Dictionary) -> void:
	var hp: float = Data.CLASS_HP[p.class_id]
	var mana: float = Data.CLASS_MANA[p.class_id]
	p.power = 0.0
	p.armor = 0.0
	p.speed = 165.0
	p.crit = 0.0
	for item_id in p.equipped.values():
		if not Realm.ITEMS.has(item_id):
			continue
		var item: Dictionary = Realm.ITEMS[item_id]
		if item["class"] >= 0 and item["class"] != p.class_id:
			continue
		hp += item.hp
		mana += item.mana
		p.power += item.power
		p.armor += item.armor
		p.speed += item.speed
		p.crit += item.crit
	p.max_hp = hp
	p.max_mana = mana
	p.hp = minf(p.hp, hp)
	p.mana = minf(p.mana, mana)

static func equip(world: Node, id: int, slot: String, item_id: String) -> bool:
	if not world.players.has(id) or not Realm.SLOTS.has(slot):
		return false
	var p: Dictionary = world.players[id]
	if p.hp <= 0 or p.combat > 0:
		world._message(p, "Troque equipamentos fora de combate.")
		return false
	if item_id != "":
		if not Realm.ITEMS.has(item_id) or not p.inventory.has(item_id):
			return false
		var item: Dictionary = Realm.ITEMS[item_id]
		if item.slot != slot or (item["class"] >= 0 and item["class"] != p.class_id):
			world._message(p, "Esse equipamento não serve à sua classe ou a esse espaço.")
			return false
	p.equipped[slot] = item_id
	recalculate(p)
	world._message(p, "Equipamento atualizado. Os atributos já estão em vigor.")
	return true

static func give_item(world: Node, p: Dictionary, item_id: String) -> void:
	if not p.inventory.has(item_id):
		p.inventory.append(item_id)
		world._message(p, "Novo equipamento: %s. Abra PERSONAGEM [C] para equipar." % Realm.ITEMS[item_id].name)

static func on_kill(world: Node, p: Dictionary, monster: Dictionary) -> void:
	var drops := ["linen_vest", "trail_boots", ["steel_sword", "crystal_staff", "longbow"][p.class_id], "verdant_heart", "dawn_crown"]
	give_item(world, p, drops[monster.kind])
