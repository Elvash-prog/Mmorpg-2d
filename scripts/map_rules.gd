extends RefCounted
## Hand-aligned foot collision masks over the illustrated background.
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

static func blocked(pos: Vector2, radius := 11.0) -> bool:
	if not BOUNDS.grow(-radius).has_point(pos):
		return true
	for rect in BLOCKERS:
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
