extends RefCounted

const MAX_DISTANCE := 35.0
const UNIT_SIZE := 8.0


static func make_player(parent: Node3D, stream: AudioStream, volume_db := 0.0, loop := false) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	var s: AudioStream = stream
	if loop and stream is AudioStreamMP3:
		s = stream.duplicate() as AudioStream
		s.set("loop", true)
	p.stream = s
	p.volume_db = volume_db
	p.max_distance = MAX_DISTANCE
	p.unit_size = UNIT_SIZE
	p.max_polyphony = 1
	parent.add_child(p)
	return p


static func play(p: AudioStreamPlayer3D, stream: AudioStream = null, pitch_jitter := 0.08, base_pitch := 1.0) -> void:
	if stream:
		p.stream = stream
	p.pitch_scale = base_pitch + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


static func play_at(from: Node3D, stream: AudioStream, volume_db := 0.0, pitch_jitter := 0.08, base_pitch := 1.0) -> void:
	var scene := from.get_tree().current_scene
	if stream == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.max_distance = MAX_DISTANCE
	p.unit_size = UNIT_SIZE
	p.pitch_scale = base_pitch + randf_range(-pitch_jitter, pitch_jitter)
	scene.add_child(p)
	p.global_position = from.global_position
	p.finished.connect(p.queue_free)
	p.play()
