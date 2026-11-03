extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var hud = world.hud
	assert(world._hero_region(3, 3).end == Vector2(world.HERO_SHEET.get_size()), "All 16 frame regions must fit the sprite sheet")
	assert(world.HERO_SHEET.get_image().get_pixel(0, 0).a == 0, "Hero background must be transparent")
	world._update_animation(0.016)
	world.players[1].pos += Vector2(4, 0)
	world._update_animation(0.016)
	assert(world.animations[1].row == 2, "Walking right must select east-facing frames")
	world.players[1].pos += Vector2(0, -4)
	world._update_animation(0.016)
	assert(world.animations[1].row == 3, "Walking up must select north-facing frames")
	world._update_animation(0.5)
	assert(world.animations[1].frame == 0, "Stopped hero must return to idle")
	assert(hud.health.value == 100, "HUD must show actual player health")
	world.players[1].hp = 35
	world.players[1].xp = 25
	world.players[1].kills = 1
	hud.refresh()
	assert(hud.health.value == 35 and hud.xp_text.text == "XP 25", "HUD must react to authoritative health and XP")
	assert("1 / 5" in hud.quest_label.text and "+25 XP" in hud.event_label.text, "Quest and feed must react to kills")
	world.players[1].hp = 0
	world.players[1].respawn = 3
	hud.refresh()
	assert("Você caiu" in hud.event_label.text, "Feed must show respawn countdown")
	assert(not hud.network_panel.visible and not hud.guide_panel.visible, "Menus must start closed")
	var map_rect := Rect2(0, 0, 100, 100)
	assert(hud._map_position(world.ARENA.position, map_rect) == Vector2.ZERO)
	assert(hud._map_position(world.ARENA.end, map_rect) == Vector2(100, 100))
	world._reset_world()
	hud.previous_kills = 0
	hud.previous_dead = false
	hud.notice_elapsed = 0
	hud.event_label.text = "Dica: aproxime-se de um limo e use o ataque."
	hud.refresh()
	await process_frame
	await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		var output := "/tmp/aurora-touch.png" if "--touch-ui" in OS.get_cmdline_user_args() else "/tmp/aurora-interface.png"
		assert(root.get_texture().get_image().save_png(output) == OK)
	print("UI_PASS: sprite alpha/grid, directional animation, idle, health, XP, quest, death feed, menus, minimap")
	world.queue_free()
	quit(0)
