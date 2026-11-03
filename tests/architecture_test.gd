extends SceneTree
const Data = preload("res://scripts/game_data.gd")
const Realm = preload("res://scripts/realm_data.gd")
const Maps = preload("res://scripts/maps/map_registry.gd")
const Animator = preload("res://scripts/presentation/animation_controller.gd")
const Codec = preload("res://scripts/network/snapshot_codec.gd")
var world

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	assert(Data.CATALOG.validate().is_empty())
	assert(Data.CATALOG.entries.size()==47 and Data.CATALOG.records("skill").size()==15)
	assert(Animator.validate(Data.CATALOG).is_empty() and Maps.validate().is_empty())
	assert(Data.CATALOG.find(&"skill.mage.fireball").data.cost == 22)
	assert(Data.CATALOG.find(&"quest.restore").data.requires == &"quest.boss_ruins")
	# Invalid authoring must be rejected, including duplicate IDs and dangling refs.
	var bad: Resource = Data.CATALOG.duplicate(true)
	bad.entries.append(bad.entries[0])
	assert(not bad.validate().is_empty())
	bad = Data.CATALOG.duplicate(true)
	bad.find(&"skill.mage.fireball").data.cost = -1
	assert(not bad.validate().is_empty())
	bad = Data.CATALOG.duplicate(true)
	bad.find(&"quest.restore").data.requires = &"quest.restore"
	assert(not bad.validate().is_empty())
	bad = Data.CATALOG.duplicate(true)
	bad.find(&"item.dawn_sigil").data.class_id = &"class.missing"
	assert(not bad.validate().is_empty())
	# Server/client modules actually own the rules; the public Node delegates.
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	world.set_process(false)
	assert(world.combat != null and world.projectile != null and world.actors != null and world.quests != null and world.effects_system != null)
	var p: Dictionary = world.players[1]
	# Explicit logical states select the expected atlas and directional row.
	var state: Dictionary = Animator.update_hero(p,{},0.01)
	assert(state.state == &"idle")
	p.pos += Vector2(20,0)
	state = Animator.update_hero(p,state,0.04)
	assert(state.state == &"walk" and state.pose.row == 2)
	p.cast = {"time":0.15}
	p.swing = 0.48
	state = Animator.update_hero(p,state,0.01)
	assert(state.state == &"prepare" and state.pose.frame == 1)
	p.cast = {}
	p.swing = 0.30
	state = Animator.update_hero(p,state,0.01)
	assert(state.state == &"attack" and state.pose.frame == 2)
	p.swing = 0.15
	state = Animator.update_hero(p,state,0.01)
	assert(state.state == &"recover" and state.pose.frame == 3)
	p.hp = 0
	assert(Animator.update_hero(p,state,0.01).state == &"dead")
	p.hp = p.max_hp
	p.swing = 0
	p.pos = world.SPAWN
	var clip: Resource = Animator.MANIFEST.heroes[0].clip(&"walk").duplicate(true)
	clip.distance_per_frame = 0
	clip.frames = PackedInt32Array([0,1,2])
	clip.durations = PackedFloat32Array([0.1,0.2,0.3])
	assert(clip.frame_at(0.05)==0 and clip.frame_at(0.15)==1 and clip.frame_at(0.4)==2 and clip.frame_at(0.65)==0)
	# Painting native layers affects collision and server navigation without code edits.
	var region: Node2D = world.map_layers.get_child(0)
	assert(region.get_node("Terrain") is TileMapLayer and region.get_node("Foreground") is TileMapLayer)
	var cell := Vector2i(20,16)
	var point := Vector2(656,528)
	assert(not world.Map.blocked(point))
	var terrain: TileMapLayer = region.get_node("Terrain")
	terrain.set_cell(cell,0,Vector2i(2,5),0)
	world.reload_map_geometry()
	assert(world.Map.blocked(point) and world.grid.is_point_solid(Vector2i(point/16)))
	terrain.erase_cell(cell)
	var decoration: TileMapLayer = region.get_node("Decoration")
	decoration.set_cell(cell,0,Vector2i(2,5),0)
	world.reload_map_geometry()
	assert(not world.Map.blocked(point),"Decoration must not silently become solid")
	decoration.erase_cell(cell)
	var collision: TileMapLayer = region.get_node("CollisionTiles")
	collision.set_cell(cell,0,Vector2i(27,17),0)
	world.reload_map_geometry()
	assert(world.Map.blocked(point),"Collision layer must work with any paint brush")
	collision.erase_cell(cell)
	# Polygon gizmos, marker positions and linked portals have one canonical source.
	var shape: CollisionPolygon2D = region.get_node("Collision/Obstacle02/Shape")
	shape.position += Vector2(250,150)
	var chest: Marker2D = region.get_node("Objects/Chest0")
	chest.position += Vector2(0,30)
	var arrival: Marker2D = world.map_layers.get_child(1).get_node("Objects/Portal1")
	arrival.position += Vector2(20,0)
	world.reload_map_geometry()
	assert(not world.Map.blocked(Vector2(470,200)) and world.Map.blocked(Vector2(720,340)))
	assert(Realm.CHESTS[0].pos == chest.position)
	assert(Realm.PORTALS[0].to == Vector2(1320,360),"Portal links must follow their target marker")
	shape.position -= Vector2(250,150)
	chest.position -= Vector2(0,30)
	arrival.position -= Vector2(20,0)
	world.reload_map_geometry()
	assert(world.Map.blocked(Vector2(447,200),0) and world.Map.blocked(Vector2(449,200),0),"Geometry must work on both sides of a chunk boundary")
	assert(Maps.chunk_key(Vector2(447,200)) != Maps.chunk_key(Vector2(449,200)))
	var flags := Maps.navigation_chunk(Vector2i(1,0))
	assert(flags.size()==28*28 and flags.has(Maps.WALKABLE) and flags.has(Maps.BLOCKED))
	# UI layouts are actual scenes; controls remain wired after instantiation.
	assert(world.hud.class_panel.scene_file_path.ends_with("classes.tscn"))
	assert(world.hud.journal_panel.scene_file_path.ends_with("journal.tscn"))
	world.hud.class_panel.get_node("MageCard").pressed.emit()
	assert(p.class_id==1)
	world.hud.close_modals()
	world.hud.refresh()
	world.hud.guide_panel.get_node("Character").pressed.emit()
	assert(world.hud.character_panel.visible)
	world.hud.character_panel.get_node("Close").pressed.emit()
	assert(not world.hud.modal_open())
	# Original versioned packet format round-trips and rejects mismatches safely.
	var packet := Codec.encode([world.players,world.monsters,world.projectiles,world.zones,world.effects])
	assert(Codec.decode(packet).ok)
	var truncated := packet.slice(0,8)
	assert(not Codec.decode(truncated).ok)
	var wrong_version := packet.duplicate()
	wrong_version.encode_u16(4,Codec.VERSION+1)
	assert(Codec.decode(wrong_version).error == "incompatible_version")
	var wrong_size := packet.duplicate()
	wrong_size.encode_u32(8,Codec.MAX_COMPRESSED+1)
	assert(not Codec.decode(wrong_size).ok)
	var unknown_type := packet.duplicate()
	unknown_type.encode_u16(6,999)
	assert(not Codec.decode(unknown_type).ok)
	var before: Dictionary = world.players
	assert(not world.transport.receive(wrong_version) and world.players == before)
	assert(world.transport.rejected_packets==1)
	print("ARCHITECTURE_PASS: resource validation, module routing, six animation states/timing, native layered edits, chunk boundary navigation, stable object refs, declarative panel signals and versioned packet rejection")
	world.queue_free()
	quit(0)
