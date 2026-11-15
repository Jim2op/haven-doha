extends MeshInstance3D

const RING_SHADER := preload("res://vfx/ring.gdshader")
const CHARGE_TINT := Color(0.72, 0.57, 0.25)
const READY_TINT := Color(1.0, 0.9, 0.6)
const RADIUS := 0.62
const READY_TIME := 0.22
const CHIME_RATE := 22050
const CHIME_LENGTH := 0.32
const CHIME_VOLUME_DB := -16.0

var _mat: ShaderMaterial
var _timer: Timer
var _tween: Tween
var _chime: AudioStreamPlayer


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	mesh = plane
	scale = Vector3.ONE * RADIUS
	_mat = ShaderMaterial.new()
	_mat.shader = RING_SHADER
	_mat.render_priority = 1
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chime = AudioStreamPlayer.new()
	_chime.stream = _make_chime()
	_chime.volume_db = CHIME_VOLUME_DB
	add_child(_chime)
	visible = false
	set_process(false)


func track(timer: Timer) -> void:
	_timer = timer
	if _tween and _tween.is_valid():
		_tween.kill()
	_mat.set_shader_parameter("color", CHARGE_TINT)
	_mat.set_shader_parameter("radius", 0.82)
	_mat.set_shader_parameter("thickness", 0.06)
	_mat.set_shader_parameter("alpha", 0.55)
	_mat.set_shader_parameter("fill", 0.0)
	visible = true
	set_process(true)


func ready_pulse() -> void:
	set_process(false)
	if _tween and _tween.is_valid():
		_tween.kill()
	_mat.set_shader_parameter("color", READY_TINT)
	_mat.set_shader_parameter("fill", 1.0)
	_chime.pitch_scale = randf_range(0.97, 1.03)
	_chime.play()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_param.bind("radius"), 0.82, 0.98, READY_TIME)
	_tween.tween_method(_set_param.bind("thickness"), 0.12, 0.02, READY_TIME)
	_tween.tween_method(_set_param.bind("alpha"), 1.2, 0.0, READY_TIME)
	_tween.chain().tween_callback(hide)


func cancel() -> void:
	set_process(false)
	if _tween and _tween.is_valid():
		_tween.kill()
	visible = false


func _process(_delta: float) -> void:
	if _timer == null or _timer.wait_time <= 0.0:
		return
	_mat.set_shader_parameter("fill", 1.0 - _timer.time_left / _timer.wait_time)


func _set_param(v: float, param: String) -> void:
	_mat.set_shader_parameter(param, v)


static func _make_chime() -> AudioStreamWAV:
	var count := int(CHIME_RATE * CHIME_LENGTH)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / CHIME_RATE
		var attack := minf(t / 0.006, 1.0)
		var env := attack * exp(-t * 11.0)
		var v := sin(TAU * 1318.5 * t) * 0.55 + sin(TAU * 1975.5 * t) * 0.3 * exp(-t * 6.0) + sin(TAU * 2637.0 * t) * 0.15 * exp(-t * 18.0)
		data.encode_s16(i * 2, int(clampf(v * env * 0.6, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = CHIME_RATE
	wav.stereo = false
	wav.data = data
	return wav
