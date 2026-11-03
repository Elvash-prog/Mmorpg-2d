@tool
extends Resource
@export var id: StringName
@export var display_size := Vector2(76,76)
@export var foot_anchor := Vector2(0.5,0.79)
@export var attack_duration := 0.48
@export var preparation_duration := 0.15
@export var recovery_duration := 0.21
@export var enemy_impact_threshold := 0.2
@export var clips: Array[Resource] = []

func clip(state: StringName) -> Resource:
	for candidate in clips:
		if candidate.state == state:
			return candidate
	return clips[0] if not clips.is_empty() else null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var states := {}
	for entry in clips:
		if entry == null or states.has(entry.state):
			errors.append(String(id)+": null or duplicate animation state")
			continue
		states[entry.state] = true
		if entry.texture == null or entry.frames.is_empty() or entry.grid.x<=0 or entry.grid.y<=0 or entry.durations.size()!=entry.frames.size():
			errors.append(String(id)+": invalid texture, grid or timing")
		for frame in entry.frames:
			if frame<0 or frame>=entry.grid.x:
				errors.append(String(id)+": frame outside atlas")
		for duration in entry.durations:
			if not is_finite(duration) or duration<=0:
				errors.append(String(id)+": non-positive frame duration")
		if entry.row<0 or entry.row>=entry.grid.y:
			errors.append(String(id)+": row outside atlas")
	for required in [&"idle",&"walk",&"prepare",&"attack",&"recover",&"dead"]:
		if not states.has(required):
			errors.append(String(id)+": missing state "+String(required))
	return errors
