extends RefCounted
## Canonical map data comes from native, editable Godot scenes.
const CATALOG = preload("res://content/game_catalog.tres")
const MANIFEST = preload("res://content/maps/manifest.tres")
static var SCENES: Array[PackedScene] = MANIFEST.regions
const CELL_SIZE := 16
const CHUNK_CELLS := 28
const CHUNK_PIXELS := CELL_SIZE*CHUNK_CELLS
const WALKABLE := 1
const BLOCKED := 2
static var _regions: Dictionary = {}
static var _radius_cache: Dictionary = {}

static func ensure_loaded() -> void:
	if _regions.size()==SCENES.size():
		return
	for packed in SCENES:
		var root: Node2D = packed.instantiate()
		register_region(root)
		root.free()

static func register_region(root: Node2D) -> void:
	var info := {"id":root.region_id,"index":root.region_index,"valid_transform":is_zero_approx(root.rotation) and root.scale.is_equal_approx(Vector2.ONE),"name":root.display_name,"subtitle":root.subtitle,"rect":Rect2(root.position,root.dimensions),"walk":Rect2(root.walk_rect.position+root.position,root.walk_rect.size),"color":root.theme_color,"map":root.get_node("Background").texture.resource_path,"polygons":[],"objects":[]}
	for body in root.get_node("Collision").get_children():
		for shape in body.get_children():
			if shape is CollisionPolygon2D and not shape.disabled:
				var polygon := PackedVector2Array()
				for point in shape.polygon:
					polygon.append(root.transform*root.get_node("Collision").transform*body.transform*shape.transform*point)
				if polygon.size()>=3:
					info.polygons.append(polygon)
	for layer_name in ["Terrain","CollisionTiles"]:
		var layer: TileMapLayer = root.get_node(layer_name)
		for cell in layer.get_used_cells():
			var tile: TileData = layer.get_cell_tile_data(cell)
			if layer_name == "CollisionTiles" or (tile != null and tile.get_custom_data("blocked")):
				var size := Vector2(layer.tile_set.tile_size)
				var pos: Vector2 = layer.map_to_local(cell)-size/2
				var shape := PackedVector2Array()
				for corner in [pos,pos+Vector2(size.x,0),pos+size,pos+Vector2(0,size.y)]:
					shape.append(root.transform*layer.transform*corner)
				info.polygons.append(shape)
	for marker in root.get_node("Objects").get_children():
		if not marker is Marker2D:
			continue
		var object: Dictionary = marker.properties.duplicate(true)
		object["id"] = marker.object_id
		object["definition_id"] = marker.definition_id
		object["object_kind"] = marker.kind
		object["pos"] = root.transform*root.get_node("Objects").transform*marker.position
		object["area"] = root.region_index
		if marker.kind in ["chest","enemy"]:
			var entry: Resource = CATALOG.find(marker.definition_id)
			object["invalid_reference"] = entry == null or entry.category != ("item" if marker.kind == "chest" else "enemy")
			if marker.kind == "chest":
				object["item"] = String(marker.definition_id).trim_prefix("item.")
			else:
				object["kind"] = entry.data.index if entry != null else -1
		info.objects.append(object)
	_regions[root.region_index] = info
	_radius_cache.clear()

static func area_definitions() -> Array:
	ensure_loaded()
	var result: Array = []
	for i in range(SCENES.size()):
		var info: Dictionary = _regions[i].duplicate(true)
		info.erase("polygons")
		info.erase("objects")
		result.append(info)
	return result

static func objects(kind: String) -> Array:
	ensure_loaded()
	var result: Array = []
	for info in _regions.values():
		for object in info.objects:
			if object.object_kind == kind:
				result.append(object.duplicate(true))
	result.sort_custom(func(a,b):return a.index<b.index)
	if kind == "portal":
		var all: Dictionary = {}
		for portal in result:
			all[portal.id] = portal
		for portal in result:
			var target: Dictionary = all.get(portal.get("target_id",&""),{})
			portal["invalid_reference"] = target.is_empty()
			portal["to"] = target.pos+portal.get("arrival_offset",Vector2.ZERO) if not target.is_empty() else portal.pos
	return result

static func area_at(pos: Vector2) -> int:
	ensure_loaded()
	for index in _regions:
		if _regions[index].rect.has_point(pos):
			return index
	return -1

static func chunk_key(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x/CHUNK_PIXELS),floori(pos.y/CHUNK_PIXELS))

static func _geometry(radius: float) -> Dictionary:
	ensure_loaded()
	var key := roundi(radius*1000)
	if _radius_cache.has(key):
		return _radius_cache[key]
	var result := {"chunks":{},"polygons":[]}
	for info in _regions.values():
		for polygon in info.polygons:
			var expanded: Array = Geometry2D.offset_polygon(polygon,radius) if radius>0 else [polygon]
			for shape in expanded:
				var bounds := Rect2(shape[0],Vector2.ZERO)
				for point in shape:
					bounds = bounds.expand(point)
				var first := chunk_key(bounds.position)
				var last := chunk_key(bounds.end)
				var index: int = result.polygons.size()
				result.polygons.append(shape)
				for y in range(first.y,last.y+1):
					for x in range(first.x,last.x+1):
						var chunk := Vector2i(x,y)
						if not result.chunks.has(chunk):
							result.chunks[chunk] = []
						result.chunks[chunk].append(index)
	_radius_cache[key] = result
	return result

static func blocked(pos: Vector2,radius := 11.0) -> bool:
	var index := area_at(pos)
	if index<0 or not _regions[index].walk.grow(-radius).has_point(pos):
		return true
	var geometry := _geometry(radius)
	for shape_index in geometry.chunks.get(chunk_key(pos),[]):
		if Geometry2D.is_point_in_polygon(pos,geometry.polygons[shape_index]):
			return true
	return false

static func navigation_chunk(key: Vector2i) -> PackedByteArray:
	var flags := PackedByteArray()
	flags.resize(CHUNK_CELLS*CHUNK_CELLS)
	for y in range(CHUNK_CELLS):
		for x in range(CHUNK_CELLS):
			var pos := Vector2(key)*CHUNK_PIXELS+Vector2(x*CELL_SIZE+CELL_SIZE/2,y*CELL_SIZE+CELL_SIZE/2)
			flags[y*CHUNK_CELLS+x] = BLOCKED if blocked(pos) else WALKABLE
	return flags

static func collision_rects(area: int) -> Array:
	ensure_loaded()
	var result: Array = []
	for polygon in _regions[area].polygons:
		var rect := Rect2(polygon[0],Vector2.ZERO)
		for point in polygon:
			rect = rect.expand(point)
		result.append(rect)
	return result

static func validate() -> PackedStringArray:
	ensure_loaded()
	var errors := PackedStringArray()
	var ids := {}
	for info in _regions.values():
		if not info.valid_transform:
			errors.append(String(info.id)+": keep region root rotation zero and scale one")
		if info.walk.size.x<=0 or info.walk.size.y<=0 or not info.rect.encloses(info.walk):
			errors.append(String(info.id)+": invalid walk bounds")
		for object in info.objects:
			if ids.has(object.id):
				errors.append("Duplicate map object ID: "+String(object.id))
			ids[object.id] = true
			if object.get("invalid_reference",false):
				errors.append(String(object.id)+": invalid content reference")
			if blocked(object.pos) and object.object_kind not in ["landmark"]:
				errors.append(String(object.id)+": unreachable position")
	for portal in objects("portal"):
		if portal.invalid_reference or blocked(portal.to):
			errors.append(String(portal.id)+": invalid or blocked portal destination")
	return errors

static func background_texture(area: int) -> Texture2D:
	ensure_loaded()
	return load(_regions[area].map)

static func draw_minimap_overlays(canvas: CanvasItem,region: Node2D,rect: Rect2) -> void:
	var minimap := Transform2D(Vector2(rect.size.x/region.dimensions.x,0),Vector2(0,rect.size.y/region.dimensions.y),rect.position)
	for name in ["Terrain","Decoration","Foreground"]:
		var layer: TileMapLayer = region.get_node(name)
		if not layer.visible:
			continue
		canvas.draw_set_transform_matrix(minimap*layer.transform)
		for cell in layer.get_used_cells():
			var source: TileSetAtlasSource = layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			if source == null:
				continue
			var size := Vector2(layer.tile_set.tile_size)
			var pos: Vector2 = layer.map_to_local(cell)-size/2
			canvas.draw_texture_rect_region(source.texture,Rect2(pos,size),source.get_tile_texture_region(layer.get_cell_atlas_coords(cell)),layer.modulate)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

static func collision_polygons() -> Array:
	ensure_loaded()
	var result: Array = []
	for info in _regions.values():
		result.append_array(info.polygons)
	return result
