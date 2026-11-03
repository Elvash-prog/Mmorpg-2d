@tool
extends Marker2D
## Original object configuration, with a stable ID, edited using the position gizmo.
@export var object_id: StringName
@export_enum("portal","npc","beacon","chest","herb","landmark","spawn","enemy") var kind := "chest"
@export var definition_id: StringName
@export var properties: Dictionary = {}
