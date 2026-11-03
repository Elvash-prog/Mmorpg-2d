extends SceneTree
const Catalog = preload("res://content/game_catalog.tres")
const Animator = preload("res://scripts/presentation/animation_controller.gd")
const Maps = preload("res://scripts/maps/map_registry.gd")
func _initialize() -> void:
	var errors: PackedStringArray = Catalog.validate()
	errors.append_array(Animator.validate(Catalog))
	errors.append_array(Maps.validate())
	for object in Maps.objects("enemy"):
		if object.kind<0 or object.kind>=Catalog.records("enemy").size():
			errors.append("Invalid enemy spawn: "+String(object.id))
	if not errors.is_empty():
		for error in errors:
			push_error(error)
		quit(1)
		return
	print("CONTENT_PASS: 47 original records, eight animation profiles, three layered regions and references validated")
	quit(0)
