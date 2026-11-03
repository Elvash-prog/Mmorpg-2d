@tool
extends Node2D
## Edit this region's children directly in Godot: tile layers, polygons and markers.
@export var region_id: StringName
@export var region_index := 0
@export var display_name := ""
@export_multiline var subtitle := ""
@export var dimensions := Vector2(1152,636):
	set(value):
		dimensions = value
		_sync_background()
@export var walk_rect := Rect2(16,112,1120,490)
@export var theme_color := Color.WHITE

func _ready() -> void:
	_sync_background()

func _sync_background() -> void:
	var background := get_node_or_null("Background") as Sprite2D
	if background != null and background.texture != null:
		background.scale = dimensions/background.texture.get_size()
