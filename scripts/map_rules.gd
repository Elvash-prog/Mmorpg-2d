extends RefCounted
## Shared collision queries: the geometry is authored in content/maps/*.tscn.
const Registry = preload("res://scripts/maps/map_registry.gd")
static var BOUNDS: Rect2 = Registry.area_definitions()[0].walk
static var BLOCKERS: Array = Registry.collision_rects(0)
static var EXTRA_BLOCKERS: Array = Registry.collision_rects(1)+Registry.collision_rects(2)

static func blocked(pos: Vector2,radius := 11.0) -> bool:
	return Registry.blocked(pos,radius)

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
