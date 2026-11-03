extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	var p: Dictionary = world.players[1]
	world.commands[1] = {"direction": Vector2.RIGHT, "attack": false}
	world._simulate(0.1)
	assert(p.pos.x > 300, "Movement must advance the player")
	p.pos = Vector2(1087, 340)
	world._simulate(1.0)
	assert(p.pos.x <= world.ARENA.end.x - 16, "Movement must remain inside the arena")
	p.pos = world.monsters[0].pos
	world.commands[1] = {"direction": Vector2.ZERO, "attack": true}
	world._simulate(0.01)
	assert(world.monsters[0].hp == 20, "Attack must damage the monster")
	world._simulate(0.01)
	assert(world.monsters[0].hp == 20, "Attack cooldown must prevent repeated hits")
	world._simulate(0.5)
	assert(world.monsters[0].hp == 0 and p.xp == 25 and p.kills == 1, "Kill must award XP and quest credit")
	world.commands.clear()
	p.pos = world.SPAWN
	world._simulate(5.1)
	assert(world.monsters[0].hp == 40, "Monster must respawn")
	p.hp = 1
	p.pos = world.monsters[0].pos
	world.monsters[0].cooldown = 0
	world._simulate(0.01)
	assert(p.hp == 0, "Monster must be able to defeat the player")
	world._simulate(3.1)
	assert(p.hp == 100 and p.pos == world.SPAWN, "Player must respawn at the fountain")
	p.hp = 50
	world._simulate(1.0)
	assert(p.hp > 50, "Fountain must restore health")
	print("COMBAT_PASS: movement, bounds, damage, cooldown, XP, monster respawn, player death/respawn, healing")
	world.queue_free()
	quit(0)
