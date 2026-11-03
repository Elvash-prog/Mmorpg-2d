extends SceneTree
const Data = preload("res://scripts/game_data.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var hud = world.hud
	assert(world.HERO_SHEET.get_image().get_pixel(0, 0).a == 0)
	assert(hud.ACTIONS.get_image().get_pixel(0, 0).a == 0)
	assert(world.visuals.ENEMIES.get_image().get_pixel(0, 0).a == 0)
	world._update_animation(0.016)
	world.players[1].pos += Vector2(4, 0)
	world._update_animation(0.016)
	assert(world.animations[1].row == 2)
	world.players[1].pos += Vector2(0, -4)
	world._update_animation(0.016)
	assert(world.animations[1].row == 3)
	world._update_animation(0.5)
	assert(world.animations[1].frame == 0)
	world.players[1].pos = world.SPAWN
	for class_id in range(3):
		assert(world._set_class(1, class_id))
		hud.refresh()
		assert(hud.skill_buttons.size() == 5 and hud.quest_rows.size() == Data.QUESTS.size())
		for i in range(5):
			assert(not hud.skill_buttons[i].disabled and Data.SKILLS[class_id][i].name in hud.skill_buttons[i].tooltip_text)
		assert(hud.class_label.text == Data.CLASS_NAMES[class_id].to_upper())
		for button in hud.skill_buttons:
			assert(button.size.x <= 82, "Skill names must not overlap neighboring slots")
	var p: Dictionary = world.players[1]
	p.hp = 35
	p.xp = 25
	p.mana = 10
	hud.refresh()
	assert(is_equal_approx(hud.health.value, 35.0 / p.max_hp * 100.0))
	assert("25" in hud.xp_text.text and "10" in hud.energy_text.text)
	assert(not hud.modal_open())
	hud.toggle_journal()
	assert(hud.modal_open() and hud.journal_panel.visible)
	hud.close_modals()
	assert(not hud.modal_open() and world.touch_direction == Vector2.ZERO and not world.touch_attack)
	world.desired_target = 0
	hud.refresh()
	assert("Limo" in hud.target_label.text)
	var map_rect := Rect2(0, 0, 100, 100)
	assert(hud._map_position(Vector2.ZERO, map_rect) == Vector2.ZERO)
	assert(hud._map_position(Vector2(1152,636), map_rect) == Vector2(100, 100))
	world._reset_world()
	hud.previous_message = ""
	hud.previous_dead = false
	hud.refresh()
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := "/tmp/aurora-touch.png" if "--touch-ui" in OS.get_cmdline_user_args() else "/tmp/aurora-interface.png"
		assert(root.get_texture().get_image().save_png(output) == OK)
		for class_id in range(3):
			world._reset_world()
			assert(world._set_class(1, class_id))
			world.players[1].pos = Vector2(635, 325)
			world.players[1].target = 0
			world.desired_target = 0
			assert(world._begin_skill(1, 1 if class_id < 2 else 2))
			world._simulate(0.16)
			world._simulate(0.08)
			world._update_animation(0.016)
			hud.refresh()
			world.visuals.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("/tmp/aurora-class-%s.png" % class_id) == OK)
		world._reset_world()
		world.visuals.queue_redraw()
		hud.refresh()
		hud.toggle_journal()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/tmp/aurora-journal.png") == OK)
		hud.close_modals()
		hud._toggle(hud.class_panel)
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("/tmp/aurora-classes.png") == OK)
		hud.close_modals()
	print("UI_PASS: transparency, animation, three classes with five usable skills, energy, health, quest journal, target info and minimap")
	world.queue_free()
	quit(0)
