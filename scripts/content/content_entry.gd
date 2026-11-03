@tool
extends Resource
## One original Aurora content record, independent of the presentation and transport.
@export var id: StringName
@export_enum("class","skill","item","quest","enemy") var category: String = "class"
@export var data: Dictionary = {}
