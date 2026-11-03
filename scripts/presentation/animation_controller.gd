extends RefCounted
const MANIFEST = preload("res://content/animations/manifest.tres")
const IDLE := &"idle"
const WALK := &"walk"
const PREPARE := &"prepare"
const ATTACK := &"attack"
const RECOVER := &"recover"
const DEAD := &"dead"

static func hero_state(actor: Dictionary,walking: bool,profile: Resource) -> StringName:
	if actor.hp<=0:
		return DEAD
	if not actor.cast.is_empty():
		return PREPARE
	if actor.swing>profile.recovery_duration:
		return ATTACK
	if actor.swing>0:
		return RECOVER
	return WALK if walking else IDLE

static func enemy_state(actor: Dictionary,profile: Resource) -> StringName:
	if actor.hp<=0:
		return DEAD
	if actor.windup>profile.enemy_impact_threshold:
		return PREPARE
	if actor.windup>0:
		return ATTACK
	if actor.moving:
		return WALK
	return RECOVER if actor.cooldown>0 else IDLE

static func sample(profile: Resource,state: StringName,row: int,elapsed: float,distance: float,facing: Vector2) -> Dictionary:
	var clip: Resource = profile.clip(state)
	var frame: int = clip.frame_at(elapsed,distance)
	var cell: Vector2 = clip.texture.get_size()/Vector2(clip.grid)
	var source_row: int = clampi(row,0,clip.grid.y-1) if clip.directional else clip.row
	return {"state":state,"texture":clip.texture,"frame":frame,"row":source_row,"region":Rect2(Vector2(frame,source_row)*cell,cell),"size":profile.display_size,"anchor":profile.foot_anchor,"flip":clip.mirror_left and facing.x<0}

static func update_hero(actor: Dictionary,previous: Dictionary,delta: float) -> Dictionary:
	var profile: Resource = MANIFEST.heroes[actor.class_id]
	var result: Dictionary = previous.duplicate() if not previous.is_empty() else {"pos":actor.pos,"row":0,"frame":0,"elapsed":0.0,"distance":0.0,"state":IDLE,"state_time":0.0}
	var movement: Vector2 = actor.pos-result.pos
	if movement.length()>0.1 and movement.length()<100:
		result.row = (1 if movement.x<0 else 2) if absf(movement.x)>absf(movement.y) else (3 if movement.y<0 else 0)
		result.distance += movement.length()
		result.elapsed = 0.12
	else:
		result.elapsed = maxf(0,result.elapsed-delta)
	var state := hero_state(actor,result.elapsed>0,profile)
	result.state_time = result.state_time+delta if result.state == state else 0.0
	result.state = state
	result.pos = actor.pos
	var time: float = result.state_time
	result.pose = sample(profile,state,result.row,time,result.distance,actor.facing)
	result.frame = result.pose.frame
	return result

static func enemy_pose(actor: Dictionary) -> Dictionary:
	var profile: Resource = MANIFEST.enemies[actor.kind]
	var state := enemy_state(actor,profile)
	return sample(profile,state,0,actor.get("state_time",0),actor.stride,actor.facing)

static func validate(catalog: Resource) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	if MANIFEST.schema_version!=1:
		errors.append("Unsupported animation schema")
	for profile in MANIFEST.heroes+MANIFEST.enemies:
		if not profile.resource_path.begins_with("res://content/animations/") or "::" in profile.resource_path:
			errors.append(String(profile.id)+": manifest must reference an editable profile file")
		if ids.has(profile.id):
			errors.append("Duplicate animation profile ID")
		ids[profile.id] = true
		errors.append_array(profile.validate())
	for category in ["class","enemy"]:
		for entry in catalog.records(category):
			if not ids.has(entry.data.get("animation_id",&"")):
				errors.append(String(entry.id)+": missing animation profile")
	return errors
