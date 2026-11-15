extends Node

const LEVEL := preload("res://environment/forest_biome/forest_biome.tscn")
const WARMUP := 3.0
const PHASE := 5.0
const SPARK_INTERVAL := 0.05
const DEATH_INTERVAL := 0.25
const HURT_INTERVAL := 0.4
const SLASH_INTERVAL := 0.3

var _level: Node
var _player: Node3D
var _enemies: Array = []
var _phases: Array = []
var _phase := -1
var _t := 0.0
var _samples: PackedFloat32Array = []
var _draws: PackedFloat32Array = []
var _timers := {}
var _last_us := 0
var _results: Array = []
var _probe_index := -1
var _probe_max := 0.0

const PROBE_GAP := 0.6
const PROBES := ["hit_spark", "death_burst", "flash", "slash", "hurt"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_level = LEVEL.instantiate()
	add_child(_level)
	_player = _level.get_node("Player")
	_player.MaxHealth = 1e12
	_player.Health = 1e12
	for n in _level.get_children():
		if n.is_in_group("Enemies") and n != _player:
			_enemies.append(n)
	for q in [Vfx.Quality.LOW, Vfx.Quality.MEDIUM, Vfx.Quality.HIGH]:
		_phases.append({"quality": q, "stress": false})
		_phases.append({"quality": q, "stress": true})
	print("renderer=", RenderingServer.get_current_rendering_method(), " driver=", RenderingServer.get_current_rendering_driver_name(), " gpu=", RenderingServer.get_video_adapter_name())
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_t += delta
	if _phase < 0:
		_probe_first_use(frame_ms)
		if _t >= WARMUP + PROBE_GAP * (PROBES.size() + 1):
			_next_phase()
		return
	_samples.append(frame_ms)
	_draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _phases[_phase]["stress"]:
		_stress(delta)
	if _t >= PHASE:
		_report()
		_next_phase()


func _stress(delta: float) -> void:
	var p := _player.global_position
	if _tick("spark", SPARK_INTERVAL, delta):
		var at := p + Vector3(randf_range(-3, 3), randf_range(0.0, 1.2), randf_range(-1.5, 1.5))
		Vfx.hit_spark(at, at - p)
		var e = _live_enemy()
		if e:
			Vfx.flash(e)
	if _tick("death", DEATH_INTERVAL, delta):
		Vfx.death_burst(p + Vector3(randf_range(-3, 3), 0.5, randf_range(-1.5, 1.5)))
	if _tick("hurt", HURT_INTERVAL, delta):
		Vfx.hurt(_player.model, p)
	if _tick("slash", SLASH_INTERVAL, delta):
		_player._slash.play(randf() * TAU)
		Vfx.shake(0.2)


func _probe_first_use(frame_ms: float) -> void:
	if _t < WARMUP:
		return
	var idx := int((_t - WARMUP) / PROBE_GAP)
	if idx != _probe_index:
		if _probe_index >= 0 and _probe_index < PROBES.size():
			var line := "first_use %-12s max_frame=%6.2fms" % [PROBES[_probe_index], _probe_max]
			_results.append(line)
			print(line)
		_probe_index = idx
		_probe_max = 0.0
		if idx < PROBES.size():
			_fire_probe(PROBES[idx])
		return
	_probe_max = maxf(_probe_max, frame_ms)


func _fire_probe(kind: String) -> void:
	var p := _player.global_position
	match kind:
		"hit_spark":
			Vfx.hit_spark(p + Vector3(1, 0.5, 0), Vector3.RIGHT)
		"death_burst":
			Vfx.death_burst(p + Vector3(-1, 0.5, 0))
		"flash":
			Vfx.flash(_live_enemy())
		"slash":
			_player._slash.play(0.0)
		"hurt":
			Vfx.hurt(_player.model, p)


func _tick(key: String, interval: float, delta: float) -> bool:
	_timers[key] = _timers.get(key, 0.0) + delta
	if _timers[key] >= interval:
		_timers[key] -= interval
		return true
	return false


func _live_enemy() -> Node3D:
	for e in _enemies:
		if is_instance_valid(e) and not e.is_dead:
			return e
	return null


func _next_phase() -> void:
	_phase += 1
	_t = 0.0
	_samples = PackedFloat32Array()
	_draws = PackedFloat32Array()
	if _phase >= _phases.size():
		print("RESULT_TABLE")
		for r in _results:
			print(r)
		get_tree().quit()
		return
	Vfx.set_quality(_phases[_phase]["quality"])


func _report() -> void:
	var s := _samples.duplicate()
	s.sort()
	var n := s.size()
	var sum := 0.0
	for v in s:
		sum += v
	var over := 0
	for v in s:
		if v > 16.67:
			over += 1
	var d := 0.0
	for v in _draws:
		d += v
	var ph: Dictionary = _phases[_phase]
	var line := "%-6s %-8s frames=%5d avg=%6.2fms p95=%6.2fms p99=%6.2fms max=%6.2fms over16.7=%d draws=%4d bursts=%d" % [
		["LOW", "MEDIUM", "HIGH"][ph["quality"]], "stress" if ph["stress"] else "baseline",
		n, sum / n, s[int(n * 0.95)], s[int(n * 0.99)], s[n - 1], over, int(d / maxf(_draws.size(), 1)), Vfx.active_bursts()]
	_results.append(line)
	print(line)
