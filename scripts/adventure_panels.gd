extends RefCounted
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")
const Scenes = preload("res://scripts/presentation/panel_scenes.gd")

static func build_journal(h: Control) -> void:
	Scenes.build(h,"journal")

static func build_class(h: Control) -> void:
	Scenes.build(h,"classes")

static func build_menu(h: Control) -> void:
	Scenes.build(h,"menu")

static func build_story(h: Control) -> void:
	Scenes.build(h,"story")

static func build_character(h: Control) -> void:
	Scenes.build(h,"character")

static func refresh_character(h: Control, p: Dictionary) -> void:
	h.character_stats.text = "[color=#f1d99e]%s[/color]\nVida %s/%s  ·  Energia %s/%s\n\nPoder adicional [color=#a9d7c2]+%s[/color]  ·  Defesa %s\nCrítico %s%%  ·  Velocidade %s\nXP %s  ·  Ouro %s" % [Data.CLASS_NAMES[p.class_id],int(p.hp),int(p.max_hp),int(p.mana),int(p.max_mana),int(p.power),int(p.armor),int(p.crit*100),int(p.speed),p.xp,p.gold]
	for i in range(Realm.SLOTS.size()):
		var item_id: String = p.equipped[Realm.SLOTS[i]]
		h.gear_buttons[i].text = Realm.SLOT_NAMES[i] + " · " + (Realm.ITEMS[item_id].name if Realm.ITEMS.has(item_id) else "Vazio")
	var signature := str(p.inventory) + str(p.equipped) + str(p.class_id)
	if signature != h.inventory_signature:
		h.inventory_signature = signature
		for child in h.inventory_list.get_children():
			h.inventory_list.remove_child(child)
			child.queue_free()
		for item_id in p.inventory:
			var item: Dictionary = Realm.ITEMS[item_id]
			var button: Button = h._button(h.inventory_list,item.name + ("  · EQUIPADO" if p.equipped.values().has(item_id) else ""),Rect2(0,0,450,34))
			button.custom_minimum_size = Vector2(450,34)
			button.add_theme_font_size_override("font_size",13)
			button.add_theme_color_override("font_color",Realm.RARITY_COLORS[item.rarity])
			button.pressed.connect(func(): h.selected_item = item_id)
	if not p.inventory.has(h.selected_item):
		h.selected_item = p.inventory[0] if not p.inventory.is_empty() else ""
	if Realm.ITEMS.has(h.selected_item):
		var item: Dictionary = Realm.ITEMS[h.selected_item]
		var current: Dictionary = Realm.ITEMS.get(p.equipped[item.slot],{})
		var line := ""
		for pair in [["power","Poder"],["armor","Defesa"],["hp","Vida"],["mana","Energia"],["speed","Veloc."],["crit","Crítico %"]]:
			var multiplier := 100.0 if pair[0] == "crit" else 1.0
			var change: float = (item[pair[0]] - current.get(pair[0],0))*multiplier
			if item[pair[0]] != 0 or change != 0:
				line += "%s +%s [color=%s](%+d)[/color]  " % [pair[1],int(item[pair[0]]*multiplier),"#a8d9af" if change >= 0 else "#e8a598",int(change)]
		h.item_details.text = "[color=#%s]%s · %s[/color]\n%s\n[i]%s[/i]" % [Realm.RARITY_COLORS[item.rarity].to_html(false),item.name,Realm.RARITIES[item.rarity] + (" · " + Data.CLASS_NAMES[item["class"]] if item["class"] >= 0 else " · Todas as classes"),line,item.lore]
		h.equip_button.disabled = p.combat > 0 or p.hp <= 0 or (item["class"] >= 0 and item["class"] != p.class_id)
	h.character_feedback.text = "Troca bloqueada durante combate." if p.combat > 0 else p.message
