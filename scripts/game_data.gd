extends RefCounted
## Compatibility view of original, validated resources shared by server and client.
const CATALOG = preload("res://content/game_catalog.tres")
const Maps = preload("res://scripts/maps/map_registry.gd")
static var CLASS_NAMES: Array = CATALOG.class_values("name")
static var CLASS_COLORS: Array = CATALOG.class_values("color")
static var CLASS_HP: Array = CATALOG.class_values("hp")
static var CLASS_MANA: Array = CATALOG.class_values("mana")
static var SKILLS: Array = CATALOG.skill_matrix()
static var SKILL_SHORT_NAMES: Array = CATALOG.skill_matrix(true)
static var ENEMIES: Array = CATALOG.rows("enemy")
static var QUESTS: Array = CATALOG.rows("quest")
static var NPC_POS: Vector2 = Maps.objects("npc")[0].pos
static var LANDMARK: Vector2 = Maps.objects("landmark")[0].pos
static var HERBS: Array = _herbs()

static func _herbs() -> Array:
	var result: Array = []
	for object in Maps.objects("herb"):
		result.append(object.pos)
	return result

static func refresh_maps() -> void:
	NPC_POS = Maps.objects("npc")[0].pos
	LANDMARK = Maps.objects("landmark")[0].pos
	HERBS = _herbs()
