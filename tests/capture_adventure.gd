extends SceneTree
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
var world

func _initialize() -> void:
	call_deferred("_run")

func _capture(name: String) -> void:
	world._update_presentation(0.016)
	world._update_animation(0.016)
	world.hud.refresh()
	world.visuals.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/aurora-"+name+".png") == OK)

func _run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	# Fixed encounter setups exercise the actual simulation and renderer.
	for area in [1,2]:
		world._reset_world()
		assert(world._set_class(1,1))
		var p: Dictionary = world.players[1]
		var boss_id := 11 if area == 1 else 16
		p.pos = Vector2(2630,780) if area == 1 else Vector2(2760,2050)
		p.target = boss_id
		world.desired_target = boss_id
		assert(world._begin_skill(1,1))
		world._simulate(0.16)
		world._simulate(0.08)
		await _capture("forest" if area == 1 else "ruins")
		if area == 2:
			world._damage_monster(1,boss_id,750)
			world._simulate(0.12)
			await _capture("boss-pillars")
	world._reset_world()
	var p: Dictionary = world.players[1]
	assert(world._set_class(1,1))
	for i in range(Realm.CHESTS.size()):
		p.pos = Realm.CHESTS[i].pos
		world._interact(1)
	p.pos = world.SPAWN
	assert(Expansion.equip(world,1,"armor","travel_coat"))
	assert(Expansion.equip(world,1,"boots","trail_boots"))
	assert(Expansion.equip(world,1,"amulet","amber_charm"))
	world.hud.close_modals()
	world.hud.selected_item = "runic_coat"
	world.hud.toggle_character()
	await _capture("equipment")
	world.hud.close_modals()
	world.hud.open_story()
	await _capture("story")
	world.hud.close_modals()
	world.hud._toggle(world.hud.guide_panel)
	await _capture("menu")
	print("ADVENTURE_CAPTURE_PASS: forest, citadel, boss pillars, equipment comparison, story and menu")
	world.queue_free()
	quit(0)
