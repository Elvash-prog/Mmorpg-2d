extends Control
const Realm = preload("res://scripts/realm_data.gd")
const Panels = preload("res://scripts/adventure_panels.gd")
const ATLAS = preload("res://assets/skill_atlas.png")
const Data = preload("res://scripts/game_data.gd")
const ACTIONS = preload("res://assets/class_actions.png")
var story_panel: Panel
var character_panel: Panel
var story_title: Label
var story_speaker: Label
var story_body: RichTextLabel
var character_stats: RichTextLabel
var character_feedback: Label
var class_feedback: Label
var class_buttons: Array[Button] = []
var last_class_style := -1
var gear_buttons: Array[Button] = []
var inventory_list: VBoxContainer
var item_details: RichTextLabel
var equip_button: Button
var selected_item := ""
var inventory_signature := ""
var last_dialogue_seq := 0
var skill_icons: Array[Sprite2D] = []
var skill_cooldowns: Array[Label] = []
var area_title: Label
var minimap_title: Label
var world: Node2D
var status_label: Label
var stats_label: Label
var address: LineEdit
var host_button: Button
var join_button: Button
var health: ProgressBar
var energy: ProgressBar
var experience: ProgressBar
var health_text: Label
var energy_text: Label
var xp_text: Label
var class_label: Label
var portrait: Sprite2D
var quest_label: Label
var event_label: Label
var target_label: Label
var target_health: ProgressBar
var network_panel: Panel
var guide_panel: Panel
var class_panel: Panel
var journal_panel: Panel
var class_details: Label
var skill_buttons: Array[Button] = []
var quest_rows: Array[Label] = []
var touch_controls: Node2D
var notice: Label
var notice_elapsed := 0.0
var previous_message := ""
var previous_dead := false
var attack_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(self, Rect2(12, 12, 270, 124))
	portrait = Sprite2D.new()
	portrait.position = Vector2(43, 50)
	portrait.region_enabled = true
	portrait.texture = world.HERO_SHEET
	portrait.region_rect = world._hero_region(0, 0)
	portrait.scale = Vector2(58, 68) / portrait.region_rect.size
	add_child(portrait)
	class_label = _label(self, "GUERREIRO", Vector2(72, 18), 17, Color("ffe4a7"))
	_label(self, "AURORA", Vector2(24, 76), 10, Color("ceb888"))
	health = _bar(Rect2(74, 46, 194, 18), Color("c24d50"))
	energy = _bar(Rect2(74, 72, 194, 14), Color("5c96c4"))
	experience = _bar(Rect2(24, 99, 244, 5), Color("bba46a"))
	health_text = _label(self, "", Vector2(132, 45), 12, Color.WHITE)
	energy_text = _label(self, "", Vector2(130, 70), 12, Color.WHITE)
	xp_text = _label(self, "", Vector2(24, 110), 12, Color("efdfb8"))
	_panel(self, Rect2(428, 12, 296, 40))
	area_title = _label(self, "✦  VALE DA AURORA  ✦", Vector2(450, 21), 16, Color("f0d9a0"))
	_panel(self, Rect2(428, 60, 296, 48), Color(0.1, 0.14, 0.13, 0.88))
	target_label = _label(self, "Clique em um inimigo ou use TAB", Vector2(440, 65), 12, Color("f3deb2"))
	target_health = _bar(Rect2(440, 91, 272, 6), Color("d98c73"))
	minimap_title = _label(self, "VALE DA AURORA", Vector2(981, 20), 12, Color("e8d5a0"))
	_label(self, "◆ Você   • Inimigos", Vector2(984, 144), 12, Color("c6d9c4"))
	_panel(self, Rect2(894, 184, 246, 144))
	_label(self, "CRÔNICA DA AURORA", Vector2(908, 193), 14, Color("f0d9a0"))
	quest_label = _label(self, "", Vector2(908, 220), 13, Color("f1ede1"))
	var quest_button := _button(self, "DIÁRIO [J]", Rect2(908, 288, 218, 28))
	quest_button.pressed.connect(toggle_journal)
	_panel(self, Rect2(12, 536, 650, 86), Color(0.07, 0.10, 0.09, 0.88))
	_label(self, "SISTEMA  ·  Vale da Aurora", Vector2(24, 543), 14, Color("edcf94"))
	status_label = _label(self, "Modo solo • progresso temporário", Vector2(24, 566), 12, Color("d3dfcd"))
	event_label = _label(self, "", Vector2(24, 590), 12, Color("b8d4c3"))
	_panel(self, Rect2(0, 634, 1152, 86))
	for item in [["MENU",12,80],["CLASSES",102,88],["DIÁRIO",200,88]]:
		var button := _button(self, item[0], Rect2(item[1], 650, item[2], 48))
		if item[0] == "MENU":
			button.pressed.connect(func(): _toggle(guide_panel))
		elif item[0] == "CLASSES":
			button.pressed.connect(func(): _toggle(class_panel))
		else:
			button.pressed.connect(toggle_journal)
	stats_label = _label(self,"",Vector2(300,646),10,Color("c9be9e"))
	var character_button := _button(self,"PERSON. [C]",Rect2(298,678,90,30))
	character_button.add_theme_font_size_override("font_size",10)
	character_button.pressed.connect(toggle_character)
	for i in range(5):
		var button := _button(self, str(i + 1), Rect2(398 + i * 91, 643, 82, 66))
		button.add_theme_font_size_override("font_size", 12)
		if i == 0:
			button.button_down.connect(func(): world.touch_attack = true)
			button.button_up.connect(func(): world.touch_attack = false)
			button.mouse_exited.connect(func(): world.touch_attack = false)
			attack_button = button
		else:
			button.pressed.connect(func(): world.use_skill(i))
		var icon := Sprite2D.new()
		icon.texture = ATLAS
		icon.region_enabled = true
		icon.position = Vector2(41,24)
		button.add_child(icon)
		skill_icons.append(icon)
		skill_cooldowns.append(_label(button,"",Vector2(22,12),18,Color("fff2bf")))
		_label(button,str(i+1),Vector2(5,3),11,Color("f3dfa6"))
		skill_buttons.append(button)
	var target_button := _button(self, "ALVO\nTAB", Rect2(858, 650, 72, 48))
	target_button.pressed.connect(world.cycle_target)
	var interact_button := _button(self, "USAR\nF", Rect2(940, 650, 76, 48))
	interact_button.pressed.connect(world.interact)
	var network := _button(self, "REDE", Rect2(1028, 650, 108, 48))
	network.pressed.connect(func(): _toggle(network_panel))
	if DisplayServer.is_touchscreen_available() or "--touch-ui" in OS.get_cmdline_user_args():
		_build_touch_controls()
	_build_network_panel()
	_build_guide_panel()
	_build_class_panel()
	_build_journal_panel()
	Panels.build_story(self)
	Panels.build_character(self)
	notice = _label(self, "", Vector2(365, 120), 17, Color("fff0b7"))

func _build_class_panel() -> void:
	Panels.build_class(self)

func _build_journal_panel() -> void:
	Panels.build_journal(self)

func _build_guide_panel() -> void:
	Panels.build_menu(self)

func toggle_character() -> void:
	_toggle(character_panel)

func open_story() -> void:
	_toggle(story_panel)
	var p: Dictionary = world.players.get(multiplayer.get_unique_id(),{})
	if not p.is_empty():
		_show_chapter(Realm.chapter(p))

func _show_chapter(chapter: int) -> void:
	var entry: Dictionary = Realm.STORY[clampi(chapter,0,Realm.STORY.size()-1)]
	story_title.text = entry.title
	story_speaker.text = entry.speaker
	story_body.text = entry.text

func _toggle(panel: Panel) -> void:
	var was_visible := panel.visible
	close_modals()
	panel.visible = not was_visible

func toggle_journal() -> void:
	_toggle(journal_panel)

func close_modals() -> void:
	for panel in [network_panel,guide_panel,class_panel,journal_panel,story_panel,character_panel]:
		if is_instance_valid(panel):
			panel.hide()
	world.touch_attack = false
	world.touch_direction = Vector2.ZERO

func modal_open() -> bool:
	for panel in [network_panel,guide_panel,class_panel,journal_panel,story_panel,character_panel]:
		if is_instance_valid(panel) and panel.visible:
			return true
	return false

func _build_touch_controls() -> void:
	touch_controls = Node2D.new()
	add_child(touch_controls)
	for item in [[Vector2(70, 385), Vector2.UP, "↑"], [Vector2(14, 443), Vector2.LEFT, "←"], [Vector2(70, 443), Vector2.DOWN, "↓"], [Vector2(126, 443), Vector2.RIGHT, "→"]]:
		_panel(touch_controls, Rect2(item[0], Vector2(54, 54)), Color(0.08, 0.14, 0.12, 0.65))
		var touch := TouchScreenButton.new()
		touch.position = item[0] + Vector2(27, 27)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(54, 54)
		touch.shape = shape
		var direction: Vector2 = item[1]
		touch.pressed.connect(func(): world.touch_direction += direction)
		touch.released.connect(func(): world.touch_direction -= direction)
		touch_controls.add_child(touch)
		_label(touch_controls, item[2], item[0] + Vector2(18, 10), 24, Color("f9e6af"))
	for i in range(5):
		skill_buttons[i].mouse_filter = Control.MOUSE_FILTER_IGNORE
		var touch := TouchScreenButton.new()
		touch.position = Vector2(439 + i * 91, 676)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(82, 66)
		touch.shape = shape
		if i == 0:
			touch.pressed.connect(func(): world.touch_attack = true)
			touch.released.connect(func(): world.touch_attack = false)
		else:
			touch.pressed.connect(func(): world.use_skill(i))
		touch_controls.add_child(touch)

func refresh() -> void:
	var p: Dictionary = world.players.get(multiplayer.get_unique_id(), {})
	if p.is_empty():
		health.value = 0
		health_text.text = "Conectando…"
		return
	health.value = p.hp / p.max_hp * 100
	energy.value = p.mana / p.max_mana * 100
	experience.value = int(p.xp) % 100
	health_text.text = "%s / %s" % [ceili(p.hp), int(p.max_hp)]
	energy_text.text = "%s / %s EN" % [int(p.mana), int(p.max_mana)]
	xp_text.text = "XP %s  ·  Ouro %s" % [p.xp, p.gold]
	class_label.text = Data.CLASS_NAMES[p.class_id].to_upper()
	portrait.texture = world.HERO_SHEET if p.class_id == 0 else ACTIONS
	portrait.region_rect = world._hero_region(0, 0) if p.class_id == 0 else Rect2(Vector2(0, p.class_id) * ACTIONS.get_size() / Vector2(4, 3), ACTIONS.get_size() / Vector2(4, 3))
	portrait.scale = Vector2(58, 68) / portrait.region_rect.size
	var available := 0
	var summary := ""
	for i in range(Data.QUESTS.size()):
		var quest: Dictionary = Data.QUESTS[i]
		var progress: int = mini(p.progress[quest.key], quest.goal)
		var locked: bool = quest.has("requires") and not p.claimed.has(quest.requires)
		var state := "ENTREGUE" if p.claimed.has(i) else ("CAPÍTULO BLOQUEADO" if locked else ("ENTREGAR" if progress >= quest.goal else "%s/%s" % [progress,quest.goal]))
		if state == "ENTREGAR":
			available += 1
		quest_rows[i].text = "%s  ·  %s\n%s\nRecompensa: %s XP + %s ouro%s" % [quest.title,state,quest.text,quest.xp,quest.gold,"  ·  Requer: " + Data.QUESTS[quest.requires].title if locked else ""]
		if i < 2:
			summary += "%s: %s\n" % [quest.title, state]
	var local_area := maxi(0,Realm.area_at(p.pos))
	var priorities := [0,1] if local_area == 0 else ([5,6] if local_area == 1 else [7,8])
	summary = ""
	for i in priorities:
		var quest: Dictionary = Data.QUESTS[i]
		var locked: bool = quest.has("requires") and not p.claimed.has(quest.requires)
		var state := "OK" if p.claimed.has(i) else ("bloq." if locked else "%s/%s" % [mini(p.progress[quest.key],quest.goal),quest.goal])
		summary += quest.title.left(21) + ": " + state + "\n"
	quest_label.text = summary + "%s/10 entregues · %s prontas" % [p.claimed.size(),available]
	stats_label.text = "%s jogador(es)\n%s abatidos" % [world.players.size(),p.kills]
	var details: String = Data.CLASS_NAMES[p.class_id] + " · %s vida / %s energia\n\n" % [int(p.max_hp), int(p.max_mana)]
	for i in range(5):
		var skill: Dictionary = Data.SKILLS[p.class_id][i]
		var remaining: float = p.cds[i]
		skill_buttons[i].text = "\n\n" + Data.SKILL_SHORT_NAMES[p.class_id][i]
		var cell := ATLAS.get_size()/Vector2(5,4)
		skill_icons[i].region_rect = Rect2(Vector2(i,p.class_id)*cell,cell)
		skill_icons[i].scale = Vector2(35,35)/cell
		skill_cooldowns[i].text = "%.1f" % remaining if remaining > 0 else ""
		skill_buttons[i].tooltip_text = "%s\n%s EN · %.1f s de recarga\n%s" % [skill.name, skill.cost, skill.cd, skill.desc]
		skill_buttons[i].modulate = Color("a8b2a2") if remaining > 0 or p.mana < skill.cost else Color.WHITE
		details += "%s. %s · %s EN · %.1fs\n%s\n\n" % [i+1,skill.name,skill.cost,skill.cd,skill.desc]
	class_details.text = details
	class_feedback.text = p.message
	if last_class_style != p.class_id:
		last_class_style = p.class_id
		for i in range(class_buttons.size()):
			class_buttons[i].add_theme_stylebox_override("normal",_style(Color("2c4148") if i == p.class_id else Color("1b2e39"),Data.CLASS_COLORS[i] if i == p.class_id else Color("697a7d")))
	Panels.refresh_character(self,p)
	var area := maxi(0,Realm.area_at(p.pos))
	area_title.text = Realm.AREAS[area].name.to_upper()
	minimap_title.text = Realm.AREAS[area].name.to_upper()
	if p.dialogue_seq != last_dialogue_seq:
		last_dialogue_seq = p.dialogue_seq
		if p.dialogue_seq > 0:
			close_modals()
			story_panel.show()
			_show_chapter(p.dialogue_chapter)
	if previous_message != p.message:
		previous_message = p.message
		event_label.text = p.message
	if p.hp <= 0:
		event_label.text = "Você caiu. Retorno à fonte em %s s…" % ceili(p.respawn)
	elif previous_dead:
		event_label.text = "Você retornou à fonte. Progresso mantido."
	previous_dead = p.hp <= 0
	var selected: int = world.desired_target if world.desired_target >= 0 else p.target
	if selected >= 0 and selected < world.monsters.size() and world.monsters[selected].hp > 0:
		var enemy: Dictionary = world.monsters[selected]
		target_label.text = "%s · %s/%s · %s px" % [Data.ENEMIES[enemy.kind].name, int(enemy.hp), int(enemy.max_hp), int(p.pos.distance_to(enemy.pos))]
		target_health.value = enemy.hp / enemy.max_hp * 100
	else:
		target_label.text = "Clique em um inimigo ou use TAB"
		target_health.value = 0
	if is_instance_valid(touch_controls):
		touch_controls.visible = not modal_open()
	queue_redraw()

func _process(delta: float) -> void:
	notice_elapsed = maxf(0, notice_elapsed - delta)
	if is_instance_valid(notice):
		notice.visible = notice_elapsed > 0

func _draw() -> void:
	draw_style_box(_style(Color(0.10, 0.14, 0.13, 0.95)), Rect2(970, 12, 170, 155))
	var map_rect := Rect2(982, 46, 146, 88)
	var local: Dictionary = world.players.get(multiplayer.get_unique_id(),{})
	var area := maxi(0,Realm.area_at(local.pos)) if not local.is_empty() else 0
	var maps: Array[Texture2D] = [world.MAP_TEXTURE,world.visuals.FOREST,world.visuals.RUINS]
	draw_texture_rect(maps[area],map_rect,false)
	for monster in world.monsters:
		if monster.hp > 0 and Realm.area_at(monster.pos) == area:
			draw_rect(Rect2(_map_position(monster.pos, map_rect) - Vector2(2, 2), Vector2(4, 4)), [Color("c4dd7c"),Color("e9b68a"),Color("a4d7ea"),Color("ef9da8"),Color("c8a4fb")][monster.kind])
	for npc in Realm.NPCS:
		if npc.area == area:
			draw_circle(_map_position(npc.pos,map_rect),2,Color("fff2af"))
	for id in world.players:
		if world.players[id].hp <= 0 or Realm.area_at(world.players[id].pos) != area:
			continue
		var pos := _map_position(world.players[id].pos, map_rect)
		var color := Color("fff5b8") if id == multiplayer.get_unique_id() else Color("8edcff")
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(4, 0), pos + Vector2(0, 4), pos + Vector2(-4, 0)]), color)

func _map_position(pos: Vector2, rect: Rect2) -> Vector2:
	var local: Dictionary = world.players.get(multiplayer.get_unique_id(),{})
	var area := maxi(0,Realm.area_at(local.pos)) if not local.is_empty() else 0
	var bounds: Rect2 = Realm.AREAS[area].rect
	var ratio: Vector2 = (pos-bounds.position)/bounds.size
	return rect.position + ratio.clamp(Vector2.ZERO, Vector2.ONE) * rect.size

func _build_network_panel() -> void:
	network_panel = _panel(self, Rect2(350, 210, 452, 245))
	network_panel.visible = false
	_label(network_panel, "PARTIDA EM REDE LOCAL", Vector2(22, 18), 19, Color("efd99e"))
	_label(network_panel, "Hospede ou informe o IP do anfitrião.", Vector2(22, 55), 15, Color("ddd8c8"))
	address = LineEdit.new()
	address.position = Vector2(22, 90)
	address.size = Vector2(405, 42)
	address.text = "127.0.0.1"
	address.placeholder_text = "IP do anfitrião"
	address.add_theme_stylebox_override("normal", _style(Color("182724"), Color("7b8468")))
	network_panel.add_child(address)
	host_button = _button(network_panel, "Hospedar", Rect2(22, 148, 195, 42))
	host_button.pressed.connect(func(): world._host(); network_panel.hide())
	join_button = _button(network_panel, "Conectar", Rect2(231, 148, 195, 42))
	join_button.pressed.connect(func(): world._join(); network_panel.hide())
	_label(network_panel, "UDP 24567  ·  Progresso temporário", Vector2(22, 210), 13, Color("b1bea9"))
	var close := _button(network_panel, "×", Rect2(402, 12, 32, 32))
	close.pressed.connect(func(): network_panel.hide())


func _style(fill: Color, border := Color("a38b58")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 10
	return style

func _panel(parent: Node, rect: Rect2, fill := Color(0.055,0.09,0.13,0.98)) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(fill))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, pos: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("18211d"))
	label.add_theme_constant_override("outline_size", 3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, rect: Rect2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style(Color("233440")))
	button.add_theme_stylebox_override("hover", _style(Color("34505a"), Color("efd18c")))
	button.add_theme_stylebox_override("pressed", _style(Color("665a39"), Color("ffe4a7")))
	button.add_theme_stylebox_override("disabled", _style(Color("202a28"), Color("6d7158")))
	button.add_theme_color_override("font_color", Color("ffe6ac"))
	button.add_theme_color_override("font_disabled_color", Color("92947f"))
	parent.add_child(button)
	return button

func _bar(rect: Rect2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.show_percentage = false
	bar.step = 0.0
	bar.add_theme_font_size_override("font_size", 1)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("18241e"), Color("90825a")))
	bar.add_theme_stylebox_override("fill", _style(color, color.lightened(0.15)))
	add_child(bar)
	bar.size = rect.size
	return bar
