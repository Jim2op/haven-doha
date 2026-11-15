extends Node3D

var busy := false
var time_left := 0.0

var _emitters: Array[CPUParticles3D] = []
var _base_amounts: Array[int] = []
var _duration := 0.0


func _ready() -> void:
	for c in get_children():
		if c is CPUParticles3D:
			var e := c as CPUParticles3D
			e.emitting = false
			e.one_shot = true
			e.local_coords = false
			e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_emitters.append(e)
			_base_amounts.append(e.amount)
			_duration = maxf(_duration, e.lifetime / maxf(e.speed_scale, 0.01))
	_duration += 0.05
	visible = false
	set_process(false)


func set_density(density: float) -> void:
	for i in _emitters.size():
		var base := _base_amounts[i]
		var amount := base if base <= 1 else maxi(1, roundi(base * density))
		if _emitters[i].amount != amount:
			_emitters[i].amount = amount


func play(at: Vector3, facing: Vector3, tint: Color) -> void:
	var flat := Vector3(facing.x, 0.0, facing.z)
	global_position = at
	if flat.length_squared() > 0.0001:
		global_basis = Basis.looking_at(flat.normalized(), Vector3.UP)
	visible = true
	busy = true
	time_left = _duration
	for e in _emitters:
		e.color = tint
		e.restart()
	set_process(true)


func _process(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		stop()


func stop() -> void:
	busy = false
	time_left = 0.0
	visible = false
	for e in _emitters:
		e.emitting = false
	set_process(false)
