@tool
extends Resource
@export var state: StringName
@export var texture: Texture2D
@export var grid := Vector2i(4,4)
@export var row := 0
@export var directional := true
@export var frames := PackedInt32Array([0])
@export var durations := PackedFloat32Array([0.12])
@export var loop := true
@export var distance_per_frame := 0.0
@export var mirror_left := false

func frame_at(seconds: float,distance := 0.0) -> int:
	if frames.is_empty():
		return 0
	if distance_per_frame>0:
		return frames[int(maxf(0,distance)/distance_per_frame)%frames.size()]
	var total := 0.0
	for duration in durations:
		total += duration
	if total<=0:
		return frames[0]
	var cursor := fmod(maxf(0,seconds),total) if loop else minf(maxf(0,seconds),total-0.0001)
	for i in range(frames.size()):
		var duration: float = durations[mini(i,durations.size()-1)]
		if cursor<duration:
			return frames[i]
		cursor -= duration
	return frames[-1]
