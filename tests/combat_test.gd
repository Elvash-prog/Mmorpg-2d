extends SceneTree
const Data = preload("res://scripts/game_data.gd")
const Map = preload("res://scripts/map_rules.gd")
var world
var checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _fresh(class_id := 0) -> Dictionary:
	world._reset_world()
	world.players[1] = world._new_player(class_id)
	var p: Dictionary = world.players[1]
	p.pos = Vector2(660, 320)
	p.target = 0
	for enemy in world.monsters:
		enemy.hp = 0
		enemy.timer = 999
	var target: Dictionary = world.monsters[0]
	target.pos = Vector2(700, 320)
	target.home = target.pos
	target.hp = 1000
	target.max_hp = 1000
	target.root = 999
	world.commands.clear()
	return p

func _advance(seconds: float) -> void:
	for i in range(ceili(seconds / 0.04)):
		world._simulate(0.04)

func _run() -> void:
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	# Collision, bridge traversal, sliding, fast dashes, line of sight.
	assert(Map.blocked(Vector2(65, 240)) and Map.blocked(Vector2(460, 200)))
	assert(not Map.blocked(Vector2(75, 320)), "Bridge must remain walkable")
	assert(Map.move_actor(Vector2(150, 250), Vector2(-200, 0)).x >= 126, "Water must block movement")
	assert(Map.move_actor(Vector2(150, 320), Vector2(-120, 0)).x < 40, "Bridge must allow river crossing")
	assert(Map.move_actor(Vector2(370, 210), Vector2(3000, 0)).x < 395, "Dash must not tunnel through cottage")
	assert(not Map.blocked(Map.move_actor(Vector2(370, 210), Vector2(150, 100))), "Diagonal movement must slide safely")
	assert(not Map.line_clear(Vector2(370, 200), Vector2(620, 200)))
	assert(Map.line_clear(Vector2(620, 320), Vector2(800, 320)))
	checks += 8
	# Every one of the fifteen abilities must cause its documented outcome.
	for class_id in range(3):
		for slot in range(5):
			var p := _fresh(class_id)
			var skill: Dictionary = Data.SKILLS[class_id][slot]
			if skill.kind in ["bolt", "fire", "arrow", "double", "charge", "evade", "storm", "rain", "trap"]:
				p.pos = Vector2(540, 320)
			if skill.kind == "heal":
				p.hp = 35
			if skill.kind in ["fire", "whirl"]:
				world.monsters[1].pos = Vector2(730, 320)
				world.monsters[1].hp = 1000
				world.monsters[1].root = 999
			assert(world._begin_skill(1, slot), "Ability must be castable: %s" % skill.name)
			assert(p.cds[slot] > 0 and p.mana == p.max_mana - skill.cost, "Cooldown and energy must be reserved on cast")
			var mana_before: float = p.mana
			assert(not world._begin_skill(1, slot) and p.mana == mana_before, "Repeated cast must be rejected")
			_advance(0.2)
			assert(not world.effects.is_empty(), "Ability must produce a visible effect")
			match skill.kind:
				"shield":
					assert(p.shield == skill.power)
					var hp: float = p.hp
					world._hurt_player(1, 30)
					assert(p.hp == hp and p.shield == skill.power - 30, "Shield must absorb damage")
					_advance(5.1)
					assert(p.shield == 0, "Shield must expire")
				"heal":
					assert(p.hp >= 35 + skill.power, "Heal must restore actual health")
				"evade":
					assert(p.pos.x < 450 and not Map.blocked(p.pos), "Evasion must move without crossing obstacles")
					var hp: float = p.hp
					world._hurt_player(1, 50)
					assert(p.hp == hp, "Evasion must prevent damage during its window")
				"storm", "rain":
					_advance(3.0)
					assert(world.monsters[0].hp == 1000 - skill.power * (4 if skill.kind == "storm" else 3), "Area must pulse the documented number of times")
				"trap":
					assert(world.monsters[0].hp == 1000 - skill.power and world.monsters[0].root > 0, "Trap must damage and root")
				"frost":
					assert(world.monsters[0].hp == 1000 - skill.power and world.monsters[0].slow > 0, "Frost must damage and slow")
				"double":
					_advance(0.8)
					assert(world.monsters[0].hp == 1000 - skill.power * 2, "Double shot must land twice")
				"bolt", "arrow", "fire":
					assert(not world.projectiles.is_empty() or world.monsters[0].hp < 1000)
					_advance(0.8)
					assert(world.monsters[0].hp == 1000 - skill.power, "Projectile must hit once")
					if skill.kind == "fire":
						assert(world.monsters[1].hp < 1000, "Fire must splash nearby targets")
				"charge":
					assert(p.pos.x > 540 and world.monsters[0].hp < 1000 and not Map.blocked(p.pos))
				_:
					assert(world.monsters[0].hp == 1000 - skill.power)
					if skill.kind == "whirl":
						assert(world.monsters[1].hp < 1000, "Whirlwind must hit multiple enemies")
			checks += 5
	# No energy or cooldown spent for invalid target or blocked line of sight.
	var p := _fresh(1)
	p.pos = Vector2(370, 210)
	world.monsters[0].pos = Vector2(620, 210)
	assert(not world._begin_skill(1, 1) and p.cds[1] == 0 and p.mana == p.max_mana)
	world._spawn_projectile(1, world.monsters[0].pos, Data.SKILLS[1][0])
	world._tick_projectiles(1.0)
	assert(world.projectiles.is_empty() and world.monsters[0].hp == 1000, "Projectile must stop at cottage wall")
	p = _fresh(0)
	p.pos = Vector2(540, 320)
	assert(not world._begin_skill(1, 0), "Melee must reject distant target")
	p.mana = 0
	assert(not world._begin_skill(1, 3), "Energy cost must be enforced")
	checks += 4
	# Reliable skill requests keep their selected target despite stale movement packets.
	p = _fresh()
	world.monsters[1].hp = 1000
	world.monsters[1].root = 999
	world.monsters[1].pos = Vector2(940, 320)
	world.commands[1] = {"direction":Vector2.ZERO, "attack":false, "target":0}
	world._queue_skill(1, 0, 1)
	world._simulate(0.04)
	assert(p.cast.is_empty() and p.cds[0] == 0, "Queued skill must use its own selected target and reject out-of-range requests")
	# A special skill pressed during the short basic wind-up is queued, not lost.
	world.commands.clear()
	p.target = 0
	assert(world._begin_skill(1, 0))
	world._queue_skill(1, 3, -1)
	world._simulate(0.16)
	assert(p.request == 3)
	world._simulate(0.04)
	world._simulate(0.16)
	assert(p.shield > 0, "Queued special must fire after the previous cast")
	checks += 2
	# Enemy attack has a warning window and can be dodged; it damages if not dodged.
	p = _fresh()
	p.pos = Vector2(675, 320)
	var enemy: Dictionary = world.monsters[0]
	enemy.root = 0
	world._tick_monster(enemy, 0.01)
	assert(enemy.windup > 0 and p.hp == p.max_hp)
	p.pos = Vector2(780, 320)
	world._tick_monster(enemy, 0.5)
	assert(p.hp == p.max_hp, "Leaving the telegraph must avoid damage")
	p.pos = Vector2(675, 320)
	enemy.cooldown = 0
	world._tick_monster(enemy, 0.01)
	world._tick_monster(enemy, 0.5)
	assert(p.hp < p.max_hp, "Enemy strike must damage players who remain inside")
	checks += 3
	# Pathfinding routes enemies around a blocked cottage.
	enemy.pos = Vector2(370, 200)
	enemy.root = 0
	enemy.slow = 0
	enemy.path_timer = 0
	for i in range(160):
		world._move_monster(enemy, Vector2(620, 200), 0.04, 100)
		assert(not Map.blocked(enemy.pos), "Enemy movement must obey scenario collisions")
	assert(enemy.pos.distance_to(Vector2(620, 200)) < 25, "Enemy must navigate around cottage")
	checks += 2
	# Kill credit is typed, and a dead monster cannot grant duplicate credit.
	p = _fresh()
	world.monsters[0].hp = 1
	world._damage_monster(1, 0, 20)
	world._damage_monster(1, 0, 20)
	assert(p.kills == 1 and p.progress.slime == 1 and p.xp == 25)
	p.pos = world.SPAWN
	_advance(8.2)
	assert(world.monsters[0].hp == world.monsters[0].max_hp, "Enemy must respawn")
	# Herb collection and reward claims are per player and cannot be duplicated.
	p = _fresh()
	p.pos = Data.HERBS[0]
	world._interact(1)
	world._interact(1)
	assert(p.progress.herbs == 1)
	for i in [1, 2]:
		p.pos = Data.HERBS[i]
		world._interact(1)
	assert(p.progress.herbs == 3)
	p.pos = Data.NPC_POS
	world._interact(1)
	assert(p.gold == 40 and p.xp == 75 and p.claimed.has(3))
	world._interact(1)
	assert(p.gold == 40 and p.xp == 75, "Quest reward must only be claimed once")
	for quest in Data.QUESTS.slice(0,5):
		p.progress[quest.key] = quest.goal
	world._interact(1)
	assert(p.claimed.size() == 5 and p.gold == 220 and p.xp == 445)
	checks += 7
	# Death/respawn retains quest progress; class switches require the safe fountain.
	world._hurt_player(1, 999)
	assert(p.hp == 0)
	_advance(3.2)
	assert(p.hp == p.max_hp and p.pos == world.SPAWN and p.claimed.size() == 5)
	p.combat = 0
	assert(world._set_class(1, 1) and p.class_id == 1 and p.max_hp == 90 and p.claimed.size() == 5)
	p.pos = Vector2(650, 320)
	assert(not world._set_class(1, 2) and p.class_id == 1)
	p.pos = world.SPAWN
	p.combat = 3
	assert(not world._set_class(1, 2))
	assert(not world._set_class(1, 99))
	checks += 6
	print("COMBAT_PASS: %s checks; 15 abilities, collisions, bridge, wall LOS, swept projectiles, enemy dodge windows, pathfinding, quests, rewards, respawn and class guards" % checks)
	world.queue_free()
	quit(0)
