extends RefCounted
## Hand-aligned foot collision masks over the illustrated background.
const Realm = preload("res://scripts/realm_data.gd")
const BOUNDS := Rect2(16, 112, 1120, 490)
const BLOCKERS := [
	Rect2(32, 112, 83, 181), # Stream north of bridge.
	Rect2(33, 350, 86, 252), # Stream south of bridge.
	Rect2(395, 155, 176, 91), # Cottage walls and porch.
	Rect2(360, 118, 35, 49), # Tree beside cottage.
	Rect2(142, 219, 29, 28), # Western boulder.
	Rect2(201, 128, 31, 20), # Rocks beside path.
	Rect2(1040, 112, 96, 90), # East treeline and boulders.
	Rect2(1070, 208, 66, 124),
	Rect2(1060, 351, 76, 113),
	Rect2(1050, 485, 86, 117),
	Rect2(385, 574, 95, 28), # Southern trees.
	Rect2(493, 580, 60, 22),
	Rect2(712, 574, 42, 28)
]

const EXTRA_BLOCKERS := [
	Rect2(1850,130,210,200), Rect2(1950,850,160,180),
	Rect2(3200,140,160,170), Rect2(1400,1060,180,140),
	Rect2(1800,1450,210,170), Rect2(1990,2140,170,200),
	Rect2(3220,1430,140,180), Rect2(1440,2290,150,150)
]

static func blocked(pos: Vector2, radius := 11.0) -> bool:
	var area := Realm.area_at(pos)
	if area < 0 or not Realm.AREAS[area].walk.grow(-radius).has_point(pos):
		return true
	var masks: Array = BLOCKERS if area == 0 else EXTRA_BLOCKERS
	for rect in masks:
		if rect.grow(radius).has_point(pos):
			return true
	return false

static func move_actor(pos: Vector2, displacement: Vector2, radius := 11.0) -> Vector2:
	# Substeps prevent tunnelling even for dashes or slow server frames.
	var steps := maxi(1, ceili(displacement.length() / 4.0))
	var step := displacement / steps
	for i in range(steps):
		var next := pos + Vector2(step.x, 0)
		if not blocked(next, radius):
			pos.x = next.x
		next = pos + Vector2(0, step.y)
		if not blocked(next, radius):
			pos.y = next.y
	return pos

static func line_clear(from: Vector2, to: Vector2, radius := 0.0) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for i in range(steps + 1):
		if blocked(from.lerp(to, float(i) / steps), radius):
			return false
	return true
