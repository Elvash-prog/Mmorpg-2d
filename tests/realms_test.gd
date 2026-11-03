extends SceneTree
const Realm = preload("res://scripts/realm_data.gd")
const Expansion = preload("res://scripts/realm_system.gd")
const Data = preload("res://scripts/game_data.gd")
var world

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	var p: Dictionary = world.players[1]
	assert(Realm.AREAS.size() == 3 and world.monsters.size() == 17)
	for area in Realm.AREAS:
		assert(world.grid.is_in_boundsv(Vector2i(area.walk.get_center()/16)))
	for portal in Realm.PORTALS:
		assert(not world.Map.blocked(portal.pos) and not world.Map.blocked(portal.to),"Portal endpoints must be walkable")
		p.pos = portal.pos
		p.velocity = Vector2(100,100)
		world._interact(1)
		assert(p.pos == portal.to and p.velocity == Vector2.ZERO and p.target == -1)
	for npc in Realm.NPCS:
		assert(not world.Map.blocked(npc.pos))
	for chest in Realm.CHESTS:
		assert(not world.Map.blocked(chest.pos),"Chest must be reachable")
	for beacon in Realm.BEACONS:
		assert(not world.Map.blocked(beacon.pos),"Story beacon must be reachable")
	# Chests, inventory ownership, class restrictions and real stat changes.
	p.pos = Realm.CHESTS[0].pos
	world._interact(1)
	assert(p.inventory.has("travel_coat") and p.gold == 15)
	world._interact(1)
	assert(p.gold == 15 and p.opened.size() == 1)
	assert(not Expansion.equip(world,1,"armor","dawn_crown"),"Cannot equip unowned item")
	assert(not Expansion.equip(world,1,"weapon","training_staff"),"Cannot equip another class weapon")
	assert(not Expansion.equip(world,1,"boots","travel_coat"),"Wrong slots must be rejected")
	var initial_hp: float = p.hp
	assert(Expansion.equip(world,1,"armor","travel_coat"))
	assert(p.max_hp == 152 and p.armor == 2 and p.hp == initial_hp,"Equipment must not heal on swap")
	world._hurt_player(1,20)
	assert(is_equal_approx(p.hp,initial_hp-18.8),"Armor must reduce damage")
	assert(not Expansion.equip(world,1,"armor",""),"Cannot change gear in combat")
	p.combat = 0
	assert(Expansion.equip(world,1,"armor",""))
	assert(p.max_hp == 140 and p.armor == 0)
	Expansion.give_item(world,p,"trail_boots")
	assert(Expansion.equip(world,1,"boots","trail_boots") and p.speed == 179)
	p.pos = world.SPAWN
	assert(world._set_class(1,1) and p.equipped.weapon == "training_staff" and p.speed == 179)
	# Story objectives require earlier deliveries; memories are interactive.
	p.pos = Realm.BEACONS[0].pos
	world._interact(1)
	assert(p.progress.forest_beacon == 1 and p.dialogue_chapter == 1 and p.dialogue_seq > 0)
	p.pos = Realm.NPCS[1].pos
	world._interact(1)
	assert(not p.claimed.has(5),"Story reward must honor prerequisite")
	p.claimed.append(4)
	world._interact(1)
	assert(p.claimed.has(5),"Completed story objective can be delivered at regional NPC")
	# Both bosses live in their own regions and use different hazard patterns.
	var forest: Dictionary = world.monsters[11]
	var archon: Dictionary = world.monsters[16]
	assert(forest.kind == 3 and archon.kind == 4)
	p.pos = forest.home + Vector2(-130,0)
	forest.cooldown = 0
	Expansion.tick_boss(world,forest,0.01)
	assert(world.zones.any(func(z):return z.kind == "thorns"))
	world.zones.clear()
	forest.windup = 0
	forest.cooldown = 0
	Expansion.tick_boss(world,forest,0.01)
	assert(world.zones.any(func(z):return z.kind == "spores"))
	forest.hp = forest.max_hp*0.49
	forest.windup = 0
	var count: int = world.monsters.size()
	Expansion.tick_boss(world,forest,0.01)
	assert(forest.phase == 2 and world.monsters.size() == count+2)
	Expansion.tick_boss(world,forest,0.01)
	assert(world.monsters.size() == count+2,"Boss reinforcements must spawn only once")
	world.zones.clear()
	p.pos = archon.home + Vector2(-120,0)
	archon.cooldown = 0
	Expansion.tick_boss(world,archon,0.01)
	var ring: Dictionary = world.zones[0]
	assert(ring.kind == "ring")
	p.hp = p.max_hp
	p.pos = ring.pos
	ring.arm = 0
	Expansion.tick_hazard(world,ring,0.01)
	assert(p.hp == p.max_hp,"Ring center must actually be safe")
	ring.pulses = 1
	ring.tick = 0
	p.pos = ring.pos + Vector2(140,0)
	Expansion.tick_hazard(world,ring,0.01)
	assert(p.hp < p.max_hp,"Donut band must damage players")
	world.zones.clear()
	archon.windup = 0
	archon.cooldown = 0
	archon.hp = archon.max_hp*0.49
	Expansion.tick_boss(world,archon,0.01)
	assert(archon.phase == 2 and Expansion.boss_shield(world,archon))
	assert(world.zones.filter(func(z):return z.kind == "meteor").size() == 3)
	var before: float = archon.hp
	p.hp = p.max_hp
	p.power = 0
	p.crit = 0
	world._damage_monster(1,16,100)
	assert(is_equal_approx(archon.hp,before-20),"Pylons must reduce incoming boss damage by 80 percent")
	for zone in world.zones:
		if zone.kind == "pylon":
			p.pos = zone.pos
			world._interact(1)
	assert(not Expansion.boss_shield(world,archon),"Interacting with all pylons removes boss shield")
	before = archon.hp
	world._damage_monster(1,16,100)
	assert(is_equal_approx(archon.hp,before-100))
	# Participating co-op players share credit and unique loot.
	world.players[2] = world._new_player()
	world.players[2].pos = archon.pos + Vector2(30,0)
	p.pos = archon.pos + Vector2(-30,0)
	p.hp = p.max_hp
	archon.hp = 30
	world._damage_monster(2,16,10)
	world._damage_monster(1,16,25)
	assert(p.progress.boss_ruins == 1 and world.players[2].progress.boss_ruins == 1)
	assert(p.inventory.has("dawn_crown") and world.players[2].inventory.has("dawn_crown"))
	assert(world.zones.all(func(z):return z.get("source",-1) != archon.id or z.life <= 0),"Boss death must clear its hazards")
	# Complete both boss rewards and deliver the chapter chain in its defined order.
	p.pos = forest.pos + Vector2(-30,0)
	world._damage_monster(1,11,forest.hp+1)
	assert(p.progress.boss_forest == 1 and p.inventory.has("verdant_heart"))
	for minion in world.monsters:
		if minion.get("summoner",-1) == forest.id:
			assert(minion.hp == 0,"Boss reinforcements must disappear on boss defeat")
	# Repeated encounters reuse the two summon slots instead of growing forever.
	forest.hp = forest.max_hp*0.49
	forest.phase = 1
	forest.windup = 0
	forest.cooldown = 0
	count = world.monsters.size()
	Expansion.tick_boss(world,forest,0.01)
	assert(world.monsters.size() == count,"Repeated boss phases must reuse summon slots")
	world._damage_monster(1,11,forest.hp+1)
	p.pos = Realm.BEACONS[1].pos
	world._interact(1)
	p.pos = Realm.NPCS[2].pos
	world._interact(1)
	assert(p.claimed.has(6) and p.claimed.has(7) and p.claimed.has(8),"Story chapters must progress through regional deliveries")
	# Restoration is a playable finale and grants a unique relic once.
	p.progress.boss_forest = 1
	p.pos = world.SPAWN
	world._interact(1)
	assert(p.progress.restore == 1 and p.inventory.has("dawn_sigil") and p.dialogue_chapter == 4)
	var inv_size: int = p.inventory.size()
	world._interact(1)
	assert(p.inventory.size() == inv_size)
	p.pos = Realm.NPCS[0].pos
	world._interact(1)
	assert(p.claimed.has(9),"Finale must be deliverable after the full chapter chain")
	var gold: int = p.gold
	world._interact(1)
	assert(p.gold == gold,"Final story reward must be unique")
	# Local smoothing and camera follow stay within the current region.
	p.pos = Vector2(2500,800)
	world._update_presentation(0.016)
	assert(world.camera.position.x > 1152 and world.camera.position.y >= 360)
	var old: Vector2 = world.player_display_pos(1)
	p.pos += Vector2(20,0)
	world._update_presentation(0.016)
	assert(world.player_display_pos(1).x > old.x and world.player_display_pos(1).x < p.pos.x)
	# Movement accelerates and decelerates; monsters patrol instead of standing frozen.
	world._reset_world()
	p = world.players[1]
	p.pos = Vector2(660,320)
	world.commands[1] = {"direction":Vector2.RIGHT,"attack":false}
	world._simulate(0.02)
	assert(p.velocity.x > 0 and p.velocity.x < p.speed)
	world.commands[1] = {"direction":Vector2.ZERO,"attack":false}
	world._simulate(0.1)
	assert(p.velocity == Vector2.ZERO)
	p.pos = world.SPAWN
	var patrol: Dictionary = world.monsters[0]
	for i in range(150):
		world._tick_monster(patrol,0.04)
	assert(patrol.stride > 10 and patrol.pos.distance_to(patrol.home) < 100)
	Expansion.give_item(world,p,"dawn_sigil")
	# Equipment comparison and all ten narrative cards are real UI content.
	world.hud.close_modals()
	world.hud.selected_item = "dawn_sigil"
	world.hud.refresh()
	assert(world.hud.quest_rows.size() == 10)
	assert("Selo" in world.hud.item_details.text and "Crítico" in world.hud.item_details.text)
	world.hud.toggle_character()
	assert(world.hud.character_panel.visible)
	print("REALMS_PASS: three regions, portals, reachable interactions, equipment ownership/stats, story gates, distinct boss patterns/phases, pylons, co-op loot, finale and camera smoothing")
	world.queue_free()
	quit(0)
