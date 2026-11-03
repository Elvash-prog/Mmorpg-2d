extends RefCounted
const Realm = preload("res://scripts/realm_data.gd")
const Data = preload("res://scripts/game_data.gd")

static func heading(h: Control, panel: Panel, eyebrow: String, title: String, subtitle: String) -> void:
	h._label(panel,eyebrow,Vector2(28,20),11,Color("a7b9bd"))
	h._label(panel,title,Vector2(28,41),26,Color("f3dfad"))
	h._label(panel,subtitle,Vector2(28,80),13,Color("b8cbd0"))
	var close: Button = h._button(panel,"×",Rect2(panel.size.x-52,18,32,32))
	close.pressed.connect(h.close_modals)

static func scroll(parent: Node, rect: Rect2) -> ScrollContainer:
	var box := ScrollContainer.new()
	box.position = rect.position
	box.size = rect.size
	box.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(box)
	return box

static func rich(parent: Node, rect: Rect2, size := 15) -> RichTextLabel:
	var text := RichTextLabel.new()
	text.position = rect.position
	text.size = rect.size
	text.bbcode_enabled = true
	text.add_theme_font_size_override("normal_font_size",size)
	text.add_theme_color_override("default_color",Color("d6e0dc"))
	text.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(text)
	return text

static func build_journal(h: Control) -> void:
	h.journal_panel = h._panel(h,Rect2(150,105,852,500))
	h.journal_panel.hide()
	heading(h,h.journal_panel,"CRÔNICA / MISSÕES E DESCOBERTAS","A Última Aurora","Investigue o vale, encontre as memórias e restaure os caminhos entre os povos.")
	var box := scroll(h.journal_panel,Rect2(26,114,800,310))
	var list := VBoxContainer.new()
	list.custom_minimum_size.x = 775
	list.add_theme_constant_override("separation",8)
	box.add_child(list)
	for i in range(Data.QUESTS.size()):
		var card: Panel = h._panel(list,Rect2(0,0,775,104),Color("1b2b32"))
		card.custom_minimum_size = Vector2(775,104)
		var label: Label = h._label(card,"",Vector2(16,12),14,Color("dde5dc"))
		label.size = Vector2(740,88)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.quest_rows.append(label)
	var deliver: Button = h._button(h.journal_panel,"CONVERSAR / ENTREGAR [F]",Rect2(26,444,270,38))
	deliver.pressed.connect(h.world.interact)
	var story: Button = h._button(h.journal_panel,"LER A CRÔNICA",Rect2(310,444,195,38))
	story.pressed.connect(h.open_story)
	h._label(h.journal_panel,"Recompensas no NPC da região.",Vector2(530,455),12,Color("a6bebc"))

static func build_class(h: Control) -> void:
	h.class_panel = h._panel(h,Rect2(150,105,852,500))
	h.class_panel.hide()
	heading(h,h.class_panel,"IDENTIDADE / ESTILO DE COMBATE","Seu caminho na Aurora","A troca é livre junto à fonte e fora de combate. O equipamento é preservado.")
	var roles := ["Resistência e controle", "Magia e dano em área", "Precisão e mobilidade"]
	var sheets: Array[Texture2D] = [h.world.HERO_SHEET,h.world.visuals.MAGE_WALK,h.world.visuals.RANGER_WALK]
	for i in range(3):
		var button: Button = h._button(h.class_panel,"",Rect2(26+i*266,114,252,122))
		button.pressed.connect(func(): h.world.choose_class(i))
		var portrait := Sprite2D.new()
		portrait.texture = sheets[i]
		portrait.region_enabled = true
		portrait.region_rect = Rect2(Vector2.ZERO,sheets[i].get_size()/4)
		portrait.scale = Vector2(92,92)/portrait.region_rect.size
		portrait.position = Vector2(51,61)
		button.add_child(portrait)
		h._label(button,Data.CLASS_NAMES[i],Vector2(100,22),18,Data.CLASS_COLORS[i])
		h._label(button,roles[i],Vector2(100,54),10,Color("b6cbd0"))
		h._label(button,"%s vida · %s EN" % [int(Data.CLASS_HP[i]),int(Data.CLASS_MANA[i])],Vector2(100,82),11,Color("d9d6bc"))
		h.class_buttons.append(button)
	var box := scroll(h.class_panel,Rect2(28,252,794,180))
	h.class_details = h._label(box,"",Vector2.ZERO,14,Color("d7e0d9"))
	h.class_details.custom_minimum_size = Vector2(765,290)
	h.class_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.class_feedback = h._label(h.class_panel,"",Vector2(28,456),12,Color("e4cea2"))

static func build_menu(h: Control) -> void:
	h.guide_panel = h._panel(h,Rect2(240,130,672,460))
	h.guide_panel.hide()
	heading(h,h.guide_panel,"AURORA / PAUSA DO VIAJANTE","Sua jornada continua","O mundo permanece ativo enquanto você consulta os painéis.")
	for entry in [["VOLTAR À AVENTURA",0],["CRÔNICA E HISTÓRIA",1],["PERSONAGEM E EQUIPAMENTOS",2],["PARTIDA EM REDE",3]]:
		var button: Button = h._button(h.guide_panel,entry[0],Rect2(28,116+entry[1]*47,616,38))
		match entry[1]:
			0: button.pressed.connect(h.close_modals)
			1: button.pressed.connect(h.open_story)
			2: button.pressed.connect(h.toggle_character)
			3: button.pressed.connect(func(): h._toggle(h.network_panel))
	h._label(h.guide_panel,"WASD / setas · mover      TAB / clique · alvo      1–5 · habilidades\nF · interagir / viajar      C · personagem      J · diário      Esc · fechar\n\nExplore os portais, abra baús e equipe os tesouros fora de combate.\nProgresso de sessão: ainda sem salvamento permanente.",Vector2(28,322),14,Color("bbcdd0"))

static func build_story(h: Control) -> void:
	h.story_panel = h._panel(h,Rect2(160,100,832,510))
	h.story_panel.hide()
	heading(h,h.story_panel,"CRÔNICA / A ÚLTIMA AURORA","Memórias que acendem caminhos","Uma história sobre promessas, escolhas e a luz que dividimos.")
	h.story_title = h._label(h.story_panel,"",Vector2(28,117),21,Color("edcf92"))
	h.story_speaker = h._label(h.story_panel,"",Vector2(28,152),13,Color("94c5c6"))
	h.story_body = rich(h.story_panel,Rect2(28,188,776,248),17)
	var close: Button = h._button(h.story_panel,"VOLTAR À AVENTURA",Rect2(28,457,274,36))
	close.pressed.connect(h.close_modals)
	var journal: Button = h._button(h.story_panel,"ABRIR DIÁRIO",Rect2(318,457,228,36))
	journal.pressed.connect(h.toggle_journal)

static func build_character(h: Control) -> void:
	h.character_panel = h._panel(h,Rect2(140,100,872,515))
	h.character_panel.hide()
	heading(h,h.character_panel,"PERSONAGEM / EQUIPAMENTO E ATRIBUTOS","Prepare-se para o que vem adiante","Os bônus dos itens alteram o combate. Equipe e remova itens fora de combate.")
	h.character_stats = rich(h.character_panel,Rect2(28,114,314,138),14)
	for i in range(Realm.SLOTS.size()):
		var slot: String = Realm.SLOTS[i]
		var button: Button = h._button(h.character_panel,"",Rect2(28,265+i*43,314,37))
		button.add_theme_font_size_override("font_size",12)
		button.pressed.connect(func(): h.world.equip_item(slot,""))
		button.tooltip_text = "Clique para remover este equipamento."
		h.gear_buttons.append(button)
	h._label(h.character_panel,"INVENTÁRIO · selecione um item",Vector2(365,116),13,Color("d9c99f"))
	var box := scroll(h.character_panel,Rect2(365,144,478,162))
	h.inventory_list = VBoxContainer.new()
	h.inventory_list.custom_minimum_size.x = 450
	h.inventory_list.add_theme_constant_override("separation",5)
	box.add_child(h.inventory_list)
	h.item_details = rich(h.character_panel,Rect2(365,317,478,113),13)
	h.equip_button = h._button(h.character_panel,"EQUIPAR ITEM SELECIONADO",Rect2(365,440,478,35))
	h.equip_button.pressed.connect(func():
		if Realm.ITEMS.has(h.selected_item):
			h.world.equip_item(Realm.ITEMS[h.selected_item].slot,h.selected_item))
	h.character_feedback = h._label(h.character_panel,"",Vector2(28,490),11,Color("d6c6a2"))

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
