extends Control
## Fixed design coordinates, scaled with the game's preserved aspect ratio.

var world: Node2D
var status_label: Label
var stats_label: Label
var address: LineEdit
var host_button: Button
var join_button: Button
var health: ProgressBar
var experience: ProgressBar
var health_text: Label
var xp_text: Label
var quest_label: Label
var event_label: Label
var network_panel: Panel
var guide_panel: Panel
var cooldown: Label
var previous_kills := 0
var previous_dead := false
var notice_elapsed := 0.0
var notice: Label
var attack_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel(self, Rect2(12, 12, 258, 92))
	var portrait := Sprite2D.new()
	portrait.texture = world.HERO_SHEET
	portrait.region_enabled = true
	portrait.region_rect = world._hero_region(0, 0)
	portrait.position = Vector2(43, 50)
	portrait.scale = Vector2(58, 68) / world._hero_region(0, 0).size
	add_child(portrait)
	_label(self, "GUARDIÃO", Vector2(72, 19), 17, Color("ffe4a7"))
	_label(self, "AURORA", Vector2(24, 73), 10, Color("ceb888"))
	health = _bar(Rect2(74, 48, 182, 18), Color("c24d50"))
	experience = _bar(Rect2(74, 74, 182, 12), Color("5799b1"))
	health_text = _label(self, "100 / 100", Vector2(125, 46), 13, Color.WHITE)
	xp_text = _label(self, "XP 0", Vector2(137, 72), 11, Color.WHITE)
	_panel(self, Rect2(428, 12, 296, 40))
	_label(self, "✦  VALE DA AURORA  ✦", Vector2(467, 21), 17, Color("f0d9a0"))
	_label(self, "VALE DA AURORA", Vector2(994, 20), 13, Color("e8d5a0"))
	_label(self, "◆ Você   • Limos", Vector2(992, 144), 12, Color("c6d9c4"))
	_panel(self, Rect2(876, 184, 264, 88))
	_label(self, "MISSÃO  /  PRIMEIROS PASSOS", Vector2(890, 193), 13, Color("f0d9a0"))
	quest_label = _label(self, "Derrote os limos: 0 / 5", Vector2(890, 218), 15, Color("f1ede1"))
	_label(self, "A fonte restaura sua vida.", Vector2(890, 245), 12, Color("b7c8b7"))
	# A compact local system feed, not a network chat.
	_panel(self, Rect2(12, 536, 560, 86), Color(0.07, 0.10, 0.09, 0.82))
	_label(self, "SISTEMA  ·  Bem-vindo ao Vale da Aurora.", Vector2(24, 543), 14, Color("edcf94"))
	status_label = _label(self, "Modo solo • explore e experimente o combate", Vector2(24, 566), 13, Color("d3dfcd"))
	event_label = _label(self, "Dica: aproxime-se de um limo e use o ataque.", Vector2(24, 590), 13, Color("b8d4c3"))
	_panel(self, Rect2(0, 634, 1152, 86))
	var menu := _button(self, "☰  MENU", Rect2(16, 651, 115, 48))
	menu.pressed.connect(func(): guide_panel.visible = not guide_panel.visible)
	var network := _button(self, "REDE", Rect2(1021, 651, 115, 48))
	network.pressed.connect(func(): network_panel.visible = not network_panel.visible)
	stats_label = _label(self, "", Vector2(148, 678), 12, Color("c9be9e"))
	_label(self, "HABILIDADES", Vector2(453, 616), 11, Color("fff4c5"))
	attack_button = _button(self, "1\n⚔", Rect2(452, 647, 59, 61))
	attack_button.tooltip_text = "Golpe de espada · Espaço ou 1 · segure para atacar"
	attack_button.button_down.connect(func(): world.touch_attack = true)
	attack_button.button_up.connect(func(): world.touch_attack = false)
	attack_button.mouse_exited.connect(func(): world.touch_attack = false)
	cooldown = _label(self, "", Vector2(463, 684), 12, Color("ffe8ae"))
	for i in range(4):
		var locked := _button(self, "%s\n—" % (i + 2), Rect2(522 + i * 70, 647, 59, 61))
		locked.disabled = true
		locked.tooltip_text = "Habilidade ainda não implementada"
	_label(self, "ESPAÇO / 1  ·  ATACAR", Vector2(805, 676), 12, Color("c9be9e"))
	# Directional controls only cover the map on touch devices.
	if DisplayServer.is_touchscreen_available() or "--touch-ui" in OS.get_cmdline_user_args():
		_build_touch_controls()
	_build_network_panel()
	_build_guide_panel()
	notice = _label(self, "", Vector2(360, 110), 18, Color("fff0b7"))

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

func _build_guide_panel() -> void:
	guide_panel = _panel(self, Rect2(260, 220, 632, 240))
	guide_panel.visible = false
	_label(guide_panel, "AURORA  /  GUIA DO VIAJANTE", Vector2(24, 18), 20, Color("efd99e"))
	_label(guide_panel, "WASD / setas: mover  ·  Espaço ou 1: atacar\nNo Android, use o direcional e o botão de ataque.\n\nDerrote 5 limos. Volte à fonte para recuperar vida.\nPara jogar acompanhado, abra REDE no canto inferior.\nOs espaços 2–5 estão reservados para futuras habilidades.", Vector2(24, 60), 16, Color("e0dfcc"))
	var close := _button(guide_panel, "×", Rect2(582, 12, 32, 32))
	close.pressed.connect(func(): guide_panel.hide())

func _build_touch_controls() -> void:
	for item in [[Vector2(70, 385), Vector2.UP, "↑"], [Vector2(14, 443), Vector2.LEFT, "←"], [Vector2(70, 443), Vector2.DOWN, "↓"], [Vector2(126, 443), Vector2.RIGHT, "→"]]:
		_panel(self, Rect2(item[0], Vector2(54, 54)), Color(0.08, 0.14, 0.12, 0.65))
		var touch := TouchScreenButton.new()
		touch.position = item[0] + Vector2(27, 27)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(54, 54)
		touch.shape = shape
		var direction: Vector2 = item[1]
		touch.pressed.connect(func(): world.touch_direction += direction)
		touch.released.connect(func(): world.touch_direction -= direction)
		add_child(touch)
		_label(self, item[2], item[0] + Vector2(18, 10), 24, Color("f9e6af"))
	# TouchScreenButton supports simultaneous movement and attack fingers.
	attack_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var attack := TouchScreenButton.new()
	attack.position = Vector2(481.5, 677.5)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(59, 61)
	attack.shape = shape
	attack.pressed.connect(func(): world.touch_attack = true)
	attack.released.connect(func(): world.touch_attack = false)
	add_child(attack)

func refresh() -> void:
	var id := multiplayer.get_unique_id()
	if not world.players.has(id):
		health.value = 0
		health_text.text = "Conectando…"
		experience.value = 0
		xp_text.text = "XP —"
		stats_label.text = "Aguardando servidor"
		return
	var p: Dictionary = world.players[id]
	health.value = p.hp
	health_text.text = "%s / 100" % ceili(p.hp)
	experience.value = int(p.xp) % 100
	xp_text.text = "XP %s" % p.xp
	quest_label.text = "Concluída!  ·  %s limos" % p.kills if p.kills >= 5 else "Derrote os limos: %s / 5" % p.kills
	stats_label.text = "WASD / SETAS\n%s jogador(es)" % world.players.size()
	cooldown.text = "%.1fs" % p.cooldown if p.cooldown > 0 else ""
	if p.kills > previous_kills:
		event_label.text = "+25 XP  ·  Limo derrotado!  ·  Missão %s/5" % mini(p.kills, 5)
		_show_notice("Missão concluída: primeiros passos!" if p.kills >= 5 else "+25 XP  ·  Limo derrotado")
	if p.hp <= 0:
		event_label.text = "Você caiu. Retorno à fonte em %s s…" % ceili(p.respawn)
	elif previous_dead:
		event_label.text = "Você retornou à fonte. Explore novamente!"
	previous_kills = p.kills
	previous_dead = p.hp <= 0
	queue_redraw()

func _process(delta: float) -> void:
	notice_elapsed = maxf(0.0, notice_elapsed - delta)
	if is_instance_valid(notice):
		notice.visible = notice_elapsed > 0

func _show_notice(text: String) -> void:
	notice.text = text
	notice_elapsed = 2.5

func _draw() -> void:
	draw_style_box(_style(Color(0.10, 0.14, 0.13, 0.95)), Rect2(970, 12, 170, 155))
	# Map markers use the actual authoritative positions, never a mock map.
	var map_rect := Rect2(982, 46, 146, 88)
	var source_scale: Vector2 = world.MAP_TEXTURE.get_size() / Vector2(1152, 636)
	var source_rect := Rect2(world.ARENA.position * source_scale, world.ARENA.size * source_scale)
	draw_texture_rect_region(world.MAP_TEXTURE, map_rect, source_rect)
	for monster in world.monsters:
		if monster.hp > 0:
			draw_rect(Rect2(_map_position(monster.pos, map_rect) - Vector2(2, 2), Vector2(4, 4)), Color("ecb66d"))
	for id in world.players:
		if world.players[id].hp <= 0:
			continue
		var pos := _map_position(world.players[id].pos, map_rect)
		var color := Color("fff5b8") if id == multiplayer.get_unique_id() else Color("8edcff")
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(4, 0), pos + Vector2(0, 4), pos + Vector2(-4, 0)]), color)

func _map_position(pos: Vector2, rect: Rect2) -> Vector2:
	var ratio: Vector2 = (pos - world.ARENA.position) / world.ARENA.size
	return rect.position + ratio.clamp(Vector2.ZERO, Vector2.ONE) * rect.size

func _style(fill: Color, border := Color("a38b58")) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 3
	return style

func _panel(parent: Node, rect: Rect2, fill := Color(0.10, 0.14, 0.13, 0.95)) -> Panel:
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
	button.add_theme_stylebox_override("normal", _style(Color("2c3633")))
	button.add_theme_stylebox_override("hover", _style(Color("4b5946"), Color("efd18c")))
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
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _style(Color("18241e"), Color("90825a")))
	bar.add_theme_stylebox_override("fill", _style(color, color.lightened(0.15)))
	add_child(bar)
	return bar
